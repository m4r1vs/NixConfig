/*
What a battery-powered machine wants whatever its vendor: power profiles that
react to the battery, less idle drain, compressed swap and, if wanted, a charge
limit. The quirks of one model stay in its host.
*/
{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.configured.laptop;
  limit = toString cfg.chargeLimit;
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
      kernel.sysctl = {
        # Coalesce periodic dirty writebacks (default 500 = 5s) so NVMe stays in deep APST sleep longer
        "vm.dirty_writeback_centisecs" = 1500;
      };
    };

    # Enforce Memory Saver and Battery Saver below threshold in Brave on laptops
    environment.etc."brave/policies/managed/power.json".text = builtins.toJSON {
      HighEfficiencyModeEnabled = true;
      BatterySaverModeAvailability = 1;
    };

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
