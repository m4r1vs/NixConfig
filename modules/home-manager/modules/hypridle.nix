{
  lib,
  config,
  scripts,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.hypridle;
in {
  options.services.configured.hypridle = {
    enable = mkEnableOption "Idle Daemon (start lockscreen automatically, etc..)";
  };
  config = mkIf cfg.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "pidof hyprlock || hyprlock";
          on_lock_cmd = "pidof hyprlock || hyprlock";
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
          inhibit_sleep = 1;
        };

        listener = [
          {
            timeout = 360;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
          }
          {
            timeout = 500;
            on-timeout = "${scripts.nixos-notify} -e -t 50000 \"Locking the Screen in a Minute, Chief\"";
          }
          {
            timeout = 550;
            on-timeout = "${scripts.nixos-notify} -e -t 10000 \"10 Seconds left.\"";
          }
          {
            timeout = 560;
            on-timeout = "loginctl lock-session";
          }
        ];
      };
    };
  };
}
