{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.configured.picom;
in {
  options.services.configured.picom = {
    enable = mkEnableOption "Enable the Picom compositor for X11";
  };
  config = mkIf cfg.enable {
    services.picom = {
      backend = "glx";
      enable = true;
      fadeDelta = 3;
      fade = true;
      inactiveOpacity = 0.87;
      shadowOffsets = [(-10) (-7)];
      shadowOpacity = 0.68;
      shadow = true;
      vSync = true;

      settings = {
        animation-clamping = true;
        animation-dampening = 20;
        animation-delta = 10;
        animation-for-open-window = "zoom";
        animation-for-transient-window = "slide-down";
        animation-for-unmap-window = "slide-left";
        animation-stiffness = 110;
        animations = true;
        animation-window-mass = 0.5;
        blur = {
          method = "dual_kawase";
          strength = 10;
        };
        blur-background-exclude = [
          "window_type = 'dock'"
          "window_type = 'menu'"
          "window_type = 'dropdown_menu'"
          "window_type = 'popup_menu'"
          "window_type = 'tooltip'"
          "class_g = 'Dunst'"
        ];
        corner-radius = 5;
        detect-client-opacity = true;
        detect-rounded-corners = true;
        detect-transient = true;
        transition-length = 250;
        transition-pow-h = 0.1;
        transition-pow-w = 0.1;
        transition-pow-x = 0.1;
        transition-pow-y = 0.1;
        rounded-corners-exclude = [
          "class_g = 'Dunst'"
        ];
        shadow-exclude = [
          "window_type = 'dock'"
          "window_type = 'menu'"
          "window_type = 'dropdown_menu'"
          "window_type = 'popup_menu'"
          "window_type = 'tooltip'"
        ];
        shadow-radius = 10;
        size-transition = true;
      };
    };
  };
}
