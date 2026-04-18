{
  lib,
  config,
  scripts,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.hypridle;
  noctalia-shell-bin = lib.getExe inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  options.services.configured.hypridle = {
    enable = mkEnableOption "Idle Daemon (start lockscreen automatically, etc..)";
  };
  config = mkIf cfg.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "${noctalia-shell-bin} ipc call lockScreen lock"; # Do not lock if already locked
          before_sleep_cmd = "${noctalia-shell-bin} ipc call lockScreen lock"; # Do not lock if already locked
          on_lock_cmd = "${noctalia-shell-bin} ipc call lockScreen lock"; # Do not lock if already locked
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
          inhibit_sleep = 2;
        };

        listener = [
          {
            # Dim screen after 8.3 minutes
            timeout = 500;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
          }
          {
            timeout = 510;
            on-timeout = "${scripts.nixos-notify} -e -t 50000 \"Locking the Screen in a Minute, Chief\"";
          }
          {
            timeout = 560;
            on-timeout = "${scripts.nixos-notify} -e -t 10000 \"10 Seconds left.\"";
          }
          {
            # Lock Screen after 9.5 minutes
            timeout = 570;
            on-timeout = "loginctl lock-session";
          }
        ];
      };
    };
  };
}
