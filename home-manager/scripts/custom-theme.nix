{
  pkgs,
  scripts,
  ...
}: {
  custom-theme = pkgs.writeShellScript "custom-theme" ''
    if [[ "$1" == "dark" ]]; then
      ${pkgs.coreutils}/bin/ln -f ~/.theme/polybar/dark.ini ~/.theme/polybar/current.ini
      ${pkgs.coreutils}/bin/ln -f ~/.theme/rofi/dark.rasi ~/.theme/rofi/current.rasi
    elif [[ "$1" == "light" ]]; then
      ${pkgs.coreutils}/bin/ln -f ~/.theme/polybar/light.ini ~/.theme/polybar/current.ini
      ${pkgs.coreutils}/bin/ln -f ~/.theme/rofi/light.rasi ~/.theme/rofi/current.rasi
    else
      ${scripts.nixos-notify} -e "custom-theme.nix: Please provide 'light' or 'dark' as an argument."
    fi
    ${pkgs.polybar}/bin/polybar-msg cmd restart
  '';
}
