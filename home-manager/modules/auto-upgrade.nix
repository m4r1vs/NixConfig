{
  lib,
  config,
  osConfig,
  host,
  scripts,
  ...
}: let
  cfg = config.services.configured.auto-upgrade;
in {
  options.services.configured.auto-upgrade = {
    enable = lib.mkEnableOption "Daily flake update and automatic boot rebuild with notifications";
  };
  config = lib.mkIf (cfg.enable && host.isLinux) {
    assertions = [
      {
        assertion = osConfig.services.configured.auto-upgrade.enable;
        message = "Home Manager auto-upgrade requires NixOS services.configured.auto-upgrade.enable = true.";
      }
    ];

    systemd.user.services.auto-upgrade = {
      Unit = {
        Description = "Automated NixOS Flake Update and Boot Rebuild";
        After = ["graphical-session.target"];
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
