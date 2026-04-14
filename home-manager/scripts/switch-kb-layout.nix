{
  pkgs,
  scripts,
  config,
  ...
}: let
  isWayland = !config.configured.desktop.x11;
in {
  switch-kb-layout = pkgs.writeShellScript "switch-kb-layout" ''

    ${
      if isWayland
      then
        /*
        bash
        */
        ''
          before=$(${pkgs.hyprland}/bin/hyprctl -j devices | ${pkgs.jq}/bin/jq -r '.keyboards[] | select(.main == true) | .active_keymap')
          ${pkgs.hyprland}/bin/hyprctl switchxkblayout all next
          # Wait up to 0.5s for the layout to change
          for i in {1..10}; do
            layMain=$(${pkgs.hyprland}/bin/hyprctl -j devices | ${pkgs.jq}/bin/jq -r '.keyboards[] | select(.main == true) | .active_keymap')
            if [ "$layMain" != "$before" ]; then
              break
            fi
            sleep 0.05
          done
        ''
      else
        /*
        bash
        */
        ''
          currentLayout=$(${pkgs.xorg.setxkbmap}/bin/setxkbmap -query | awk '/layout:/ {print $2}')
          if [[ $currentLayout == "us" ]]; then
            ${pkgs.xorg.setxkbmap}/bin/setxkbmap de
            layMain="de"
          else
            ${pkgs.xorg.setxkbmap}/bin/setxkbmap us
            layMain="us"
          fi
        ''
    }

    ${scripts.nixos-notify} -e -h string:synchronous:switch-kb-layout -t 1000 -i "${pkgs.papirus-icon-theme}/share/icons/Papirus/128x128/devices/input-keyboard.svg" "Switched Keyboard Layout to:" "$layMain"
  '';
}
