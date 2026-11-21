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
    enable = lib.mkEnableOption "Scheduled flake update and automatic boot rebuild with notifications";
    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      example = "weekly";
      description = "How often to look for updates, as a systemd calendar expression. A run that was missed while the machine was off is made up for.";
    };
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
        ConditionACPower = true;
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
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
