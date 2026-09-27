{
  lib,
  host,
  ...
}:
with lib; {
  config = mkMerge [
    (mkIf (host.windowManager == "i3") {
      programs.configured = {
        i3.enable = true;
      };
    })
    (mkIf (host.windowManager == "hyprland") {
      programs.configured = {
        hyprland.enable = true;
        hyprlock.enable = true;
        waybar.enable = true;
      };
      services = {
        awww.enable = true;
      };
    })
  ];
}
