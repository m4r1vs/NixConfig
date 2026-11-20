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
    boot.kernelParams =
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

    /*
    power-profiles-daemon only looks UPower up on the bus and never
    activates it, and NixOS starts upower on D-Bus activation only
    */
    systemd.services.upower.wantedBy = ["graphical.target"];
  };
}
