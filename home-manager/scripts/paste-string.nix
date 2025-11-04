{pkgs, ...}: {
  paste-string =
    pkgs.writeShellScript "paste-string"
    ''
      if ! ${pkgs.hyprland}/bin/hyprctl -j activewindow | ${pkgs.jq}/bin/jq -r '.initialClass' | grep -q "ghostty"; then
        ${pkgs.hyprland}/bin/hyprctl -q dispatch exec '${pkgs.wtype}/bin/wtype -M ctrl V -m ctrl'
      else
        ${pkgs.hyprland}/bin/hyprctl -q dispatch exec '${pkgs.wtype}/bin/wtype -M ctrl -M shift V -m ctrl -m shift'
      fi
    '';
}
