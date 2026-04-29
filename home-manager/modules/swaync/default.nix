{
  osConfig,
  config,
  lib,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.services.configured.swaync;
  theme = systemArgs.theme;
in {
  options.services.configured.swaync = {
    enable = mkEnableOption "Sway Notification-Center";
  };
  config = mkIf cfg.enable {
    home.file.".theme/swaync/style-light.css".text =
      # css
      ''
        @define-color background-clr rgba(${theme.backgroundColorLightRGB}, 0.76);
        @define-color foreground-clr #000000;
        @define-color primary-clr ${theme.primaryColor.hex};
        @define-color secondary-clr ${theme.secondaryColor.hex};

        @import url("${builtins.path {path = ./base.css;}}");
      '';
    home.file.".theme/swaync/style-dark.css".text =
      # css
      ''
        @define-color background-clr rgba(${theme.backgroundColorRGB}, 0.76);
        @define-color foreground-clr #ffffff;
        @define-color primary-clr ${theme.primaryColor.hex};
        @define-color secondary-clr ${theme.secondaryColor.hex};

        @import url("${builtins.path {path = ./base.css;}}");
      '';

    services.swaync = {
      enable = true;
      package = pkgs.swaynotificationcenter;
      settings = {
        positionX = "right";
        control-center-positionX = "right";
        positionY = "top";
        layer = "overlay";
        text-empty = " 󰾢 ";
        control-center-layer = "top";
        layer-shell = true;
        cssPriority = "user";
        control-center-margin-top = 0;
        control-center-margin-bottom = 0;
        control-center-margin-right = 0;
        control-center-margin-left = 0;
        notification-2fa-action = true;
        notification-inline-replies = true;
        notification-icon-size = 64;
        notification-body-image-height = 100;
        notification-body-image-width = 200;
        widgets = [
          "title"
          "dnd"
          "notifications"
        ];
        widget-config = {
          title = {
            text = " Notifications";
            clear-all-button = true;
            button-text = " 󰎟 ";
          };
          dnd = {
            text = "󰖔 Do Not Disturb";
          };
        };
        scripts = mkIf (osConfig.configured.system-sounds.enable && osConfig.configured.system-sounds.notification.enable) {
          sounds_normal = {
            exec =
              pkgs.writeShellScript "make-sound"
              # bash
              ''
                ${getExe pkgs.mpv} --no-video --volume=70 ${osConfig.configured.system-sounds.notification.soundFile}
              '';
            urgency = "Normal";
          };
          sounds_critical = {
            exec =
              pkgs.writeShellScript "make-sound"
              # bash
              ''
                ${getExe pkgs.mpv} --no-video --volume=70 ${osConfig.configured.system-sounds.notification.soundFile}
              '';
            urgency = "Critical";
          };
        };
      };
    };
  };
}
