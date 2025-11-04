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
          ${pkgs.hyprland}/bin/hyprctl switchxkblayout all next && sleep 0.05
          layMain=$(${pkgs.hyprland}/bin/hyprctl -j devices | jq '.keyboards' | jq '.[] | select (.main == true)' | awk -F '"' '{if ($2=="active_keymap") print $4}')
        ''
      else
        /*
        bash
        */
        ''
          layMain=$(${pkgs.xorg.setxkbmap}/bin/setxkbmap -query | awk '/layout:/ {print $2}')
          if [[ $layMain == "us" ]]; then
            ${pkgs.xorg.setxkbmap}/bin/setxkbmap de
          else
            ${pkgs.xorg.setxkbmap}/bin/setxkbmap us
          fi
        ''
    }

    ${scripts.nixos-notify} -e -h string:synchronous:switch-kb-layout -t 1000 -i "${pkgs.papirus-icon-theme}/share/icons/Papirus/128x128/devices/input-keyboard.svg" "Switched Keyboard Layout to:" "$layMain"
  '';
}
