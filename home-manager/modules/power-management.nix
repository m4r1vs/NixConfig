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

          BAT=""
          for p in /sys/class/power_supply/BAT*; do
            if [ -r "$p/capacity" ]; then
              BAT="$p/capacity"
              break
            fi
          done

          last=""
          apply() {
            local status desired cap
            read -r status < "$AC"
            if [ "$status" = "1" ]; then
              # Balanced keeps amd-pstate-epp dynamic instead of locking the performance governor
              desired="auto"
            elif [ "$last" = "very-light" ]; then
              # Stay in very-light while unplugged to avoid 29% <-> 30% bounce
              desired="very-light"
            elif [ -n "$BAT" ] && read -r cap < "$BAT" && [[ "$cap" =~ ^[0-9]+$ ]] && [ "$cap" -lt 30 ]; then
              desired="very-light"
            else
              desired="light"
            fi
            [ "$desired" = "$last" ] && return
            last=$desired
            ${scripts.powermode} "$desired"
          }

          apply
          # React to power_supply uevents instead of polling sysfs every 5s.
          # Battery ticks also arrive here; the 60s timeout is a fallback for
          # drivers that skip intermediate capacity uevents.
          while true; do
            if read -r -t 60 _; then
              apply
            else
              rc=$?
              if [ "$rc" -gt 128 ]; then
                apply
              else
                break
              fi
            fi
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
