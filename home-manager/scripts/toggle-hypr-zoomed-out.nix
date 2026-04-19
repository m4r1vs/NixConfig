{pkgs, ...}: {
  toggle-hypr-zoomed-out =
    pkgs.writeShellScript "toggl-hypr-zoomed-out"
    ''
      if [ -e /tmp/hypr-zoomed_out ]; then
        ${pkgs.hyprland}/bin/hyprctl keyword general:gaps_out 8
        ${pkgs.hyprland}/bin/hyprctl keyword animation "workspaces, 1, 1.5, smooth, slide"
        rm /tmp/hypr-zoomed_out
      else
        ${pkgs.hyprland}/bin/hyprctl keyword general:gaps_out 140,700,120,200
        ${pkgs.hyprland}/bin/hyprctl keyword animation "workspaces, 1, 2, smooth, slidefade 15%"
        touch /tmp/hypr-zoomed_out
      fi
    '';
}
