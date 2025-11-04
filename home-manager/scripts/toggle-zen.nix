{pkgs, ...}: {
  toggle-zen =
    pkgs.writeShellScript "toggle-zen"
    ''
      if [ -e /tmp/zen-mode-active ]; then
        ${pkgs.waybar}/bin/waybar &
        rm /tmp/zen-mode-active
        ${pkgs.swaynotificationcenter}/bin/swaync-client --dnd-off
      else
        touch /tmp/zen-mode-active
        pkill -f "${pkgs.waybar}/bin/waybar"
        ${pkgs.swaynotificationcenter}/bin/swaync-client --dnd-on
      fi
    '';
}
