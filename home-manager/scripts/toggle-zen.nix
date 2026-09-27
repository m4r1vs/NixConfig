{pkgs, ...}: {
  toggle-zen =
    pkgs.writeShellScript "toggle-zen"
    ''
      STATE="''${XDG_RUNTIME_DIR:-/tmp}/zen-mode-active"
      if [ -e "$STATE" ]; then
        ${pkgs.waybar}/bin/waybar &
        rm -f "$STATE"
        ${pkgs.swaynotificationcenter}/bin/swaync-client --dnd-off
      else
        touch "$STATE"
        ${pkgs.procps}/bin/pkill -f "${pkgs.waybar}/bin/waybar"
        ${pkgs.swaynotificationcenter}/bin/swaync-client --dnd-on
      fi
    '';
}
