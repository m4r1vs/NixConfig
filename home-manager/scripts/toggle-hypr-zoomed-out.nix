{pkgs, ...}: {
  toggle-hypr-zoomed-out =
    pkgs.writeShellScript "toggle-hypr-zoomed-out"
    ''
      STATE="''${XDG_RUNTIME_DIR:-/tmp}/hypr-zoomed-out"
      if [ -e "$STATE" ]; then
        ${pkgs.hyprland}/bin/hyprctl eval 'hl.config({ general = { gaps_out = 8 } })'
        ${pkgs.hyprland}/bin/hyprctl eval 'hl.animation({ leaf = "workspaces", enabled = true, speed = 1.5, bezier = "smooth", style = "slide" })'
        rm -f "$STATE"
      else
        ${pkgs.hyprland}/bin/hyprctl eval 'hl.config({ general = { gaps_out = { top = 140, right = 700, bottom = 120, left = 200 } } })'
        ${pkgs.hyprland}/bin/hyprctl eval 'hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "smooth", style = "slidefade 15%" })'
        touch "$STATE"
      fi
    '';
}
