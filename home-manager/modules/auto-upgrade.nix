{
  lib,
  config,
  host,
  scripts,
  ...
}: let
  cfg = config.services.configured.auto-upgrade;
in {
  options.services.configured.auto-upgrade = {
    enable = lib.mkEnableOption "Daily flake update and dry-build with a notification";
  };
  config = lib.mkIf (cfg.enable && host.isLinux) {
    systemd.user.services.auto-upgrade = {
      Unit = {
        Description = "Automated NixOS Flake Update and Dry-Run";
      };
      Service = {
        ExecStart = "${scripts.auto-upgrade}";
        Type = "oneshot";
      };
    };

    systemd.user.timers.auto-upgrade = {
      Unit = {
        Description = "Timer for Automated Flake Update";
      };
      Timer = {
        # Run daily (or customize the frequency as desired, e.g., "hourly")
        OnCalendar = "daily";
        Persistent = true;
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
