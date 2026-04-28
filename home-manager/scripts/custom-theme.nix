{
  pkgs,
  scripts,
  ...
}: {
  custom-theme =
    pkgs.writeShellScript "custom-theme"
    # bash
    ''
      NOTIFY_STRING=""
      if [[ "$1" == "dark" ]]; then
        ${pkgs.coreutils}/bin/ln -f ~/.theme/polybar/dark.ini ~/.theme/polybar/current.ini
        ${pkgs.coreutils}/bin/ln -f ~/.theme/rofi/dark.rasi ~/.theme/rofi/current.rasi
        ${pkgs.coreutils}/bin/ln -f ~/.theme/swaync/style-dark.css ~/.config/swaync/style.css
        NOTIFY_STRING="I'm switching to dark mode 󰏒 "
      elif [[ "$1" == "light" ]]; then
        ${pkgs.coreutils}/bin/ln -f ~/.theme/polybar/light.ini ~/.theme/polybar/current.ini
        ${pkgs.coreutils}/bin/ln -f ~/.theme/rofi/light.rasi ~/.theme/rofi/current.rasi
        ${pkgs.coreutils}/bin/ln -f ~/.theme/swaync/style-light.css ~/.config/swaync/style.css
        NOTIFY_STRING="Let there be light 󰓠 "
      else
        ${scripts.nixos-notify} -e "custom-theme.nix: Please provide 'light' or 'dark' as an argument."
      fi
      ${pkgs.polybar}/bin/polybar-msg cmd restart
      ${pkgs.swaynotificationcenter}/bin/swaync-client -rs
      ${scripts.nixos-notify} -u low -e -t 4000 -h string:synchronous:startup-script "$NOTIFY_STRING"
    '';
}
