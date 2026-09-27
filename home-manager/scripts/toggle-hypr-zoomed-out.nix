{pkgs, ...}: {
  toggle-hypr-zoomed-out =
    pkgs.writeShellScript "toggle-hypr-zoomed-out"
    ''
      STATE="''${XDG_RUNTIME_DIR:-/tmp}/hypr-zoomed-out"
      if [ -e "$STATE" ]; then
        ${pkgs.hyprland}/bin/hyprctl keyword general:gaps_out 8
        ${pkgs.hyprland}/bin/hyprctl keyword animation "workspaces, 1, 1.5, smooth, slide"
        rm -f "$STATE"
      else
        ${pkgs.hyprland}/bin/hyprctl keyword general:gaps_out 140,700,120,200
        ${pkgs.hyprland}/bin/hyprctl keyword animation "workspaces, 1, 2, smooth, slidefade 15%"
        touch "$STATE"
      fi
    '';
}
