{
  lib,
  config,
  scripts,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.hypridle;
  DIM_SCREEN_SECS = 5 * 60; # Dim Screen after 5 Minutes
  LOCK_SCREEN_SECS = 10 * 60; # Lock after 10
  SCREEN_OFF_SECS = 14 * 60; # Screen off after 14
  # Wrapped so hyprlang doesn't parse the Lua arguments
  dpmsOn = pkgs.writeShellScript "hypridle-dpms-on" "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
  dpmsOff = pkgs.writeShellScript "hypridle-dpms-off" "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'";
in {
  options.services.configured.hypridle = {
    enable = mkEnableOption "Idle Daemon (start lockscreen automatically, etc..)";
  };
  config = mkIf cfg.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock"; # Do not lock if already locked
          before_sleep_cmd = "pidof hyprlock || hyprlock"; # Do not lock if already locked
          on_lock_cmd = "pidof hyprlock || hyprlock"; # Do not lock if already locked
          # Turn on display (if turned off)
          after_sleep_cmd = "${dpmsOn}";
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
          ignore_wayland_inhibit = false;
          inhibit_sleep = 3; # Do not sleep when Hyprlock wasn't launched
        };

        listener =
          [
            {
              timeout = DIM_SCREEN_SECS;
              on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 20%";
              on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
            }
            {
              timeout = LOCK_SCREEN_SECS - 60;
              on-timeout = "${scripts.nixos-notify} -e -t 50000 -h string:synchronous:hypridle \"Locking the Screen in a Minute\"";
              on-resume = "${scripts.nixos-notify} -u low -e -t 10 -h string:synchronous:hypridle \"Locking the Screen in a Minute\"";
            }
            {
              timeout = SCREEN_OFF_SECS;
              on-timeout = "${dpmsOff}";
              on-resume = "${dpmsOn}";
            }
          ]
          ++ (
            builtins.concatLists (
              builtins.genList (
                i: let
                  seconds = i + 1;
                in [
                  {
                    timeout = LOCK_SCREEN_SECS - 12 + seconds;
                    on-timeout = "${scripts.nixos-notify} -e -u low -h string:synchronous:hypridle \"Locking the Screen..\" \"in ${toString (11 - seconds)} Second${
                      if (seconds < 10)
                      then "s"
                      else ""
                    }\"";
                  }
                ]
              )
              10
            )
          )
          ++ [
            {
              timeout = LOCK_SCREEN_SECS;
              on-timeout = "loginctl lock-session";
            }
          ];
      };
    };
  };
}
