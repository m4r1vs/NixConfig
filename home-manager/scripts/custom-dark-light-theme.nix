{
  pkgs,
  lib,
  host,
  scripts,
  systemArgs,
  ...
}: let
  inherit (systemArgs) theme;
  darkBgHex = lib.removePrefix "#" theme.backgroundColor;
  lightBgHex = lib.removePrefix "#" theme.backgroundColorLight;
  isWayland = host.windowManager == "hyprland";
in {
  custom-dark-light-theme =
    pkgs.writeShellScript "custom-dark-light-theme"
    # bash
    ''
      NOTIFY_STRING=""
      mkdir -p "$HOME/.theme"
      if [[ "$1" == "dark" ]]; then
        printf 'dark\n' > "$HOME/.theme/mode"
        ${pkgs.coreutils}/bin/ln -f ~/.theme/polybar/dark.ini ~/.theme/polybar/current.ini
        ${pkgs.coreutils}/bin/ln -f ~/.theme/rofi/dark.rasi ~/.theme/rofi/current.rasi
        ${pkgs.coreutils}/bin/ln -f ~/.theme/swaync/style-dark.css ~/.config/swaync/style.css
        HYPRTASKING_BG="0x94${darkBgHex}"
        HYPR_ACTIVE_BORDER="rgba(ffffffcc)"
        HYPR_INACTIVE_BORDER="rgba(ffffff24)"
        NOTIFY_STRING="I'm switching to dark mode 󰏒 "
      elif [[ "$1" == "light" ]]; then
        printf 'light\n' > "$HOME/.theme/mode"
        ${pkgs.coreutils}/bin/ln -f ~/.theme/polybar/light.ini ~/.theme/polybar/current.ini
        ${pkgs.coreutils}/bin/ln -f ~/.theme/rofi/light.rasi ~/.theme/rofi/current.rasi
        ${pkgs.coreutils}/bin/ln -f ~/.theme/swaync/style-light.css ~/.config/swaync/style.css
        HYPRTASKING_BG="0xa8${lightBgHex}"
        HYPR_ACTIVE_BORDER="rgba(${darkBgHex}99)"
        HYPR_INACTIVE_BORDER="rgba(${darkBgHex}22)"
        NOTIFY_STRING="Let there be light 󰓠 "
      else
        ${scripts.nixos-notify} -e "scripts/custom-dark-light-theme" "Please provide 'light' or 'dark' as an argument."
      fi
      ${lib.optionalString isWayland ''
        if [[ -n "''${HYPRTASKING_BG-}" ]]; then
          ${pkgs.hyprland}/bin/hyprctl eval "hl.config({ general = { col = { active_border = \"$HYPR_ACTIVE_BORDER\", inactive_border = \"$HYPR_INACTIVE_BORDER\" } } }); if hl.get_config(\"plugin.hyprtasking.bg_color\") ~= nil then hl.config({ plugin = { hyprtasking = { bg_color = $HYPRTASKING_BG } } }) end" >/dev/null 2>&1 || true
        fi
      ''}
      ${pkgs.polybar}/bin/polybar-msg cmd restart
      ${pkgs.swaynotificationcenter}/bin/swaync-client -rs
      ${scripts.nixos-notify} -u low -e -t 4000 -h string:synchronous:startup-script "$NOTIFY_STRING"
    '';
}
