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
  makeSound =
    pkgs.writeShellScript "make-sound"
    # bash
    ''
      ${getExe pkgs.mpv} --no-video --volume=70 ${osConfig.configured.system-sounds.notification.soundFile}
    '';
  inherit (systemArgs) theme;
in {
  options.services.configured.swaync = {
    enable = mkEnableOption "Sway Notification-Center";

    holdForHeyComputer = mkOption {
      type = types.bool;
      default = config.programs.configured.hey-computer.enable or false;
      description = ''
        Enable the SwayNC hold-and-enrich pipeline (`hc-hold-enabled`) so
        normal-urgency notifications are briefly checked by `hey-computer`
        before rendering.
      '';
    };

    holdMaxSeconds = mkOption {
      type = types.int;
      default = 60;
      description = ''
        Maximum number of seconds SwayNC holds a notification waiting for
        `hey-computer` before failing open to the raw notification.
      '';
    };

    holdApps = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Case-insensitive regexes matched against `app_name` or `desktop_entry`
        to hold. Empty holds all non-excluded normal-urgency notifications,
        relying on fast deterministic filters in SwayNC and `hey-computer`.
      '';
    };

    holdExcludeApps = mkOption {
      type = types.listOf types.str;
      default = ["^${systemArgs.hostname}$"];
      description = ''
        Case-insensitive regexes matched against `app_name` or `desktop_entry`
        to exclude from holding (defaults to excluding host-origin
        `nixos-notify` alerts such as screenshots and Wi-Fi warnings).
      '';
    };
  };
  config = mkIf cfg.enable {
    home.file.".theme/swaync/style-light.css".text =
      # css
      ''
        @define-color background-clr rgba(${theme.backgroundColorLightRGB}, 0.70);
        @define-color foreground-clr #000000;

        @import url("${config.home.homeDirectory}/.theme/swaync/colors.css");
        @import url("${builtins.path {path = ./base.css;}}");
      '';
    home.file.".theme/swaync/style-dark.css".text =
      # css
      ''
        @define-color background-clr rgba(${theme.backgroundColorRGB}, 0.70);
        @define-color foreground-clr #ffffff;

        @import url("${config.home.homeDirectory}/.theme/swaync/colors.css");
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
        hc-hold-enabled = cfg.holdForHeyComputer;
        hc-hold-max-seconds = cfg.holdMaxSeconds;
        hc-hold-apps = cfg.holdApps;
        hc-hold-exclude-apps = cfg.holdExcludeApps;
        script-continue-on-match = true;
        script-fail-notify = false;
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
            exec = makeSound;
            urgency = "Normal";
            skip-on-dnd = true;
          };
          sounds_critical = {
            exec = makeSound;
            urgency = "Critical";
            skip-on-dnd = true;
          };
        };
      };
    };
  };
}
