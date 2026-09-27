{
  host,
  config,
  lib,
  pkgs,
  scripts,
  ...
}:
with lib; let
  cfg = config.services.configured.auto-power-management;
  inherit (host) hasPowerProfiles;
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
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
        # Skipped entirely on machines without an AC adapter (desktops)
        ConditionPathExistsGlob = "/sys/class/power_supply/A[CD]*";
      };
      Service = {
        ExecStart = pkgs.writeShellScript "power-profile-auto-switch" ''
          AC=""
          for p in /sys/class/power_supply/{AC,ADP,ACAD}*; do
            if [ -r "$p/online" ]; then
              AC="$p/online"
              break
            fi
          done
          [ -n "$AC" ] || exit 0

          last=""
          apply() {
            local status
            read -r status < "$AC"
            [ "$status" = "$last" ] && return
            last=$status
            if [ "$status" = "1" ]; then
              ${scripts.powermode} performance
            else
              ${scripts.powermode} light
            fi
          }

          apply
          # React to power_supply uevents instead of polling sysfs every 5s.
          # Battery ticks also arrive here, but apply() only reads a file then.
          while read -r _; do
            apply
          done < <(${pkgs.systemd}/bin/udevadm monitor --udev --subsystem-match=power_supply)
          exit 1 # monitor died, let systemd restart us
        '';
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
