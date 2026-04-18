{
  lib,
  osConfig,
  ...
}:
with lib;
  optionalAttrs (osConfig.configured ? desktop) {
    config = mkIf osConfig.configured.desktop.enable (
      if (osConfig.configured.i3.enable)
      then {
        programs.configured = {
          i3.enable = true;
        };
      }
      else if (osConfig.configured.hyprland.enable)
      then {
        programs.configured = {
          hyprland.enable = true;
          hyprlock.enable = false;
          noctalia-shell.enable = true;
        };
        services = {
          swww.enable = false;
          configured = {
            cliphist.enable = true;
            hypridle.enable = false;
            swaync.enable = false;
          };
        };
      }
      else {}
    );
  }
