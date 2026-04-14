{
  config,
  lib,
  pkgs,
  osConfig,
  scripts,
  ...
}:
with lib; let
  cfg = config.services.configured.auto-power-management;
  hasPowerProfiles = osConfig.services.power-profiles-daemon.enable or false;
in {
  options.services.configured.auto-power-management = {
    enable = mkEnableOption "Automatically switch power profile based on AC status";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enable -> hasPowerProfiles;
        message = "Power profile auto-switching requires services.power-profiles-daemon.enable to be true in NixOS.";
      }
    ];

    systemd.user.services.power-profile-auto-switch = {
      Unit = {
        Description = "Auto switch power profiles based on AC status";
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = pkgs.writeShellScript "power-profile-auto-switch" ''
          # Find the AC power supply
          AC_PATH=""
          for p in /sys/class/power_supply/AC* /sys/class/power_supply/ADP* /sys/class/power_supply/ACAD*; do
            if [ -d "$p" ]; then
              AC_PATH="$p/online"
              break
            fi
          done

          if [ -z "$AC_PATH" ]; then
            echo "No AC power supply found. This is likely not a laptop or the hardware is unsupported."
            exit 0 # Exit gracefully instead of restart loop if not a laptop
          fi

          last_status=""

          while true; do
            current_status=$(cat "$AC_PATH")
            if [ "$current_status" != "$last_status" ]; then
              if [ "$current_status" = "1" ]; then
                ${scripts.powermode} performance
              else
                ${scripts.powermode} light
              fi
              last_status=$current_status
            fi
            sleep 5
          done
        '';
        Restart = "always";
        RestartSec = 10;
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
