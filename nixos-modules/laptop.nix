/*
What a battery-powered machine wants whatever its vendor: power profiles that
react to the battery, less idle drain, compressed swap and, if wanted, a charge
limit. The quirks of one model stay in its host.
*/
{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.laptop;
  limit = toString cfg.chargeLimit;

  cpufreqHelper = pkgs.writeShellApplication {
    name = "powermode-cpufreq";
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: powermode-cpufreq {cap|restore}" >&2
        exit 1
      fi

      mode="$1"
      case "$mode" in
        cap|restore) ;;
        *)
          echo "Usage: powermode-cpufreq {cap|restore}" >&2
          exit 1
          ;;
      esac

      cap_khz=${toString cfg.veryLightMaxFreqKHz}

      for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -w "$p/scaling_max_freq" ] || continue
        [ -r "$p/cpuinfo_max_freq" ] || continue
        [ -r "$p/cpuinfo_min_freq" ] || continue

        hw_max=$(< "$p/cpuinfo_max_freq")
        hw_min=$(< "$p/cpuinfo_min_freq")

        if [ "$mode" = "cap" ]; then
          target=$cap_khz
          if [ "$target" -gt "$hw_max" ]; then
            target=$hw_max
          fi
          if [ "$target" -lt "$hw_min" ]; then
            target=$hw_min
          fi
        else
          target=$hw_max
        fi

        printf '%s\n' "$target" > "$p/scaling_max_freq"
      done
    '';
  };
in {
  options.configured.laptop = {
    enable = mkEnableOption "Settings for battery-powered machines";
    chargeLimit = mkOption {
      type = types.nullOr (types.ints.between 50 100);
      default = null;
      example = 80;
      description = ''
        Stop charging at this percentage to slow battery wear. Works where the
        battery driver has charge_control_end_threshold (ThinkPads do); null
        keeps what the firmware has stored.
      '';
    };
    veryLightMaxFreqKHz = mkOption {
      type = types.ints.positive;
      default = 1400000;
      example = 1600000;
      description = ''
        CPU frequency ceiling (in kHz) applied across all cpufreq policies in
        very-light power mode, clamped to each policy's hardware min/max bounds.
      '';
    };
    cpufreqHelper = mkOption {
      type = types.package;
      readOnly = true;
      default = cpufreqHelper;
      description = "Locked-down root helper that caps or restores per-policy scaling_max_freq for very-light power mode.";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelParams =
        [
          # Stop periodic NMI watchdog interrupts and free a PMU counter on all threads
          "nmi_watchdog=0"
        ]
        ++ optionals (config.swapDevices != []) [
          # Compress swapped pages in RAM before they reach the disk
          "zswap.enabled=1"
          "zswap.compressor=zstd"
          "zswap.max_pool_percent=20"
          "zswap.shrinker_enabled=0"
        ];
      kernel.sysctl =
        {
          # Coalesce periodic dirty writebacks (default 500 = 5s) so NVMe stays in deep APST sleep longer
          "vm.dirty_writeback_centisecs" = 1500;
        }
        // optionalAttrs (config.swapDevices != []) {
          # No multi-page swap readahead: zswap hands pages back from RAM, so neighbours are not worth it
          "vm.page-cluster" = 0;
        };
    };

    # Enforce Memory Saver and Battery Saver below threshold in Brave on laptops
    environment.etc."brave/policies/managed/power.json".text = builtins.toJSON {
      HighEfficiencyModeEnabled = true;
      BatterySaverModeAvailability = 1;
    };

    security.sudo.extraRules = [
      {
        users = [systemArgs.username];
        commands = [
          {
            command = "${cfg.cpufreqHelper}/bin/powermode-cpufreq";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    services = {
      /*
      Dynamic CPU/Power modes
      */
      power-profiles-daemon.enable = true;

      /*
      Battery state for power-profiles-daemon (battery-aware EPP, panel power savings)
      */
      upower.enable = true;

      udev.extraRules = mkIf (cfg.chargeLimit != null) ''
        # Charge limit. Written only when it differs: the firmware keeps the value
        ACTION!="remove", SUBSYSTEM=="power_supply", ATTR{type}=="Battery", ATTR{charge_control_end_threshold}!="${limit}", ATTR{charge_control_end_threshold}="${limit}"
      '';
    };

    systemd.services = {
      /*
      power-profiles-daemon only looks UPower up on the bus and never
      activates it, and NixOS starts upower on D-Bus activation only
      */
      upower.wantedBy = ["graphical.target"];

      /*
      Panel power savings (AMD ABM: lower backlight, compensated by contrast) on
      battery is an opt-in power-profiles-daemon action kept in its state file;
      without an amdgpu panel it does nothing. Each call makes the daemon
      restart its drivers, so stay active instead of running again on every
      rebuild
      */
      ppd-panel-power-savings = {
        description = "Enable power-profiles-daemon panel power savings";
        wantedBy = ["graphical.target"];
        wants = ["power-profiles-daemon.service"];
        after = ["power-profiles-daemon.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.services.power-profiles-daemon.package}/bin/powerprofilesctl configure-action amdgpu_panel_power --enable";
        };
      };

      # Keep heavy periodic maintenance off battery power
      nix-optimise = mkIf config.nix.optimise.automatic {
        unitConfig.ConditionACPower = true;
      };
      nh-clean = mkIf config.programs.nh.clean.enable {
        unitConfig.ConditionACPower = true;
      };
      fwupd-refresh = mkIf config.services.fwupd.enable {
        unitConfig.ConditionACPower = true;
      };
      "btrfs-scrub--" = mkIf (config.services.btrfs.autoScrub.enable && builtins.elem "/" config.services.btrfs.autoScrub.fileSystems) {
        unitConfig.ConditionACPower = true;
      };
    };
  };
}
