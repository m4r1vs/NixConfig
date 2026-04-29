{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.system-sounds;
in {
  options.configured.system-sounds = {
    enable = mkEnableOption "Enable system sounds (startup, shutdown, screenshot)";
    startup = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable startup sound";
      };
      soundFile = mkOption {
        type = types.path;
        default = ../assets/sounds/windows_98_startup.mp3;
        description = "Sound file for startup";
      };
    };
    shutdown = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable shutdown sound";
      };
      soundFile = mkOption {
        type = types.path;
        default = ../assets/sounds/windows_98_shutdown.mp3;
        description = "Sound file for shutdown";
      };
    };
    notification = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable notification sound";
      };
      soundFile = mkOption {
        type = types.path;
        default = ../assets/sounds/notification.wav;
        description = "Sound file for notification";
      };
    };
    clipboard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable clipboard sound";
      };
      soundFile = mkOption {
        type = types.path;
        default = ../assets/sounds/clipboard.mp3;
        description = "Sound file for clipboard";
      };
    };
    screenshot = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable screenshot sound";
      };
      soundFile = mkOption {
        type = types.path;
        default = ../assets/sounds/screenshot.mp3;
        description = "Sound file for screenshot";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.startup-sound = mkIf cfg.startup.enable {
      description = "Play Startup Sound";
      after = ["pipewire.service" "wireplumber.service"];
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.mpv}/bin/mpv --no-video --no-config --volume=80 --no-terminal ${cfg.startup.soundFile}";
      };
    };
  };
}
