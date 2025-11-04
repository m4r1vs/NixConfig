{
  lib,
  osConfig,
  ...
}:
with lib;
  optionalAttrs (osConfig.configured ? desktop) (
    let
      desktop = osConfig.configured.desktop;
    in {
      config = mkIf desktop.enable (
        if (desktop.x11)
        then {
          programs.configured = {
            i3.enable = true;
          };
        }
        else {
          programs.configured = {
            hyprland.enable = true;
            hyprlock.enable = true;
          };
        }
      );
    }
  )
