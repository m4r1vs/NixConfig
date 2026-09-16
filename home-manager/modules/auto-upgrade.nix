{
  lib,
  systemArgs,
  scripts,
  ...
}: let
  isLinux = systemArgs.system != "aarch64-darwin";
in {
  config = lib.mkIf isLinux {
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
