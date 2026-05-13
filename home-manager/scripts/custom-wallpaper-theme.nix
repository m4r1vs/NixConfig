{
  pkgs,
  lib,
  config,
  ...
}: let
  isWayland = config.configured ? hyprland && config.configured.hyprland.enable;
in {
  custom-wallpaper-theme =
    pkgs.writeShellScript "custom-wallpaper-theme"
    ''
      case "$1" in
        New_York_from_Staten_Island.jpg)
          PRIMARY_COLOR_HEX="#E8A88C"
          SECONDARY_COLOR_HEX="#9F8FB5"
          ;;
        Staten_Island_Ferry.jpg)
          PRIMARY_COLOR_HEX="#639190"
          SECONDARY_COLOR_HEX="#DB8C4B"
          ;;
        Hamburger_Fernsehturm.jpg)
          PRIMARY_COLOR_HEX="#A699D0"
          SECONDARY_COLOR_HEX="#FE3700"
          ;;
        Artemis_II_Moon_and_Star.jpg)
          PRIMARY_COLOR_HEX="#598F8F"
          SECONDARY_COLOR_HEX="#A7C2D1"
          ;;
        Artemis_II_Earth_From_Capsule.jpg)
          PRIMARY_COLOR_HEX="#7f9fc9"
          SECONDARY_COLOR_HEX="#e3be71"
          ;;
        Koivu.jpg)
          PRIMARY_COLOR_HEX="#6281AD"
          SECONDARY_COLOR_HEX="#DAC05F"
          ;;
        Usva.jpg)
          PRIMARY_COLOR_HEX="#938622"
          SECONDARY_COLOR_HEX="#BCCCE6"
          ;;
        Bangkok.jpg)
          PRIMARY_COLOR_HEX="#D36568"
          SECONDARY_COLOR_HEX="#DCB56A"
          ;;
        Greenland_from_Plane.jpg)
          PRIMARY_COLOR_HEX="#4e788a";
          SECONDARY_COLOR_HEX="#747982";
          ;;
        Lisboa_Bridge.jpg)
          PRIMARY_COLOR_HEX="#C75940";
          SECONDARY_COLOR_HEX="#DEA58F";
          ;;
        New_York_Garden.jpg)
          PRIMARY_COLOR_HEX="#619362";
          SECONDARY_COLOR_HEX="#518f9c";
          ;;
        New_York_Chinatown.jpg)
          PRIMARY_COLOR_HEX="#BA7720";
          SECONDARY_COLOR_HEX="#CC5868";
          ;;
        Puula.jpg)
          PRIMARY_COLOR_HEX="#7490A5";
          SECONDARY_COLOR_HEX="#FCD58D";
          ;;
        New_York_Subway.jpg)
          PRIMARY_COLOR_HEX="#AB4E40";
          SECONDARY_COLOR_HEX="#A3B3C0";
          ;;
        Scooter_in_Chiang_Mai.jpg)
          PRIMARY_COLOR_HEX="#CE485D";
          SECONDARY_COLOR_HEX="#647555";
          ;;
        Travemünder_Vögel.jpg)
          PRIMARY_COLOR_HEX="#FEE801";
          SECONDARY_COLOR_HEX="#E36C00";
          ;;
        Valkoiset_Puut.jpg)
          PRIMARY_COLOR_HEX="#B2C9E5";
          SECONDARY_COLOR_HEX="#95AECD";
          ;;
        Statue_and_Gull.jpg)
          PRIMARY_COLOR_HEX="#DB9C00";
          SECONDARY_COLOR_HEX="#597492";
          ;;
        Dandelion.jpg)
          PRIMARY_COLOR_HEX="#C38C05";
          SECONDARY_COLOR_HEX="#6B7533";
          ;;
        Alsterschwan.jpg)
          PRIMARY_COLOR_HEX="#7D7D00";
          SECONDARY_COLOR_HEX="#987243";
          ;;
        Auringonlasku_Mökillä.jpg)
          PRIMARY_COLOR_HEX="#E35203";
          SECONDARY_COLOR_HEX="#FF9605";
          ;;
        Ghibli_Puddle_on_Train_Tracks.jpg)
          PRIMARY_COLOR_HEX="#376C96";
          SECONDARY_COLOR_HEX="#E4C200";
          ;;
        Graffiti_Bird.jpg)
          PRIMARY_COLOR_HEX="#027180";
          SECONDARY_COLOR_HEX="#A56326";
          ;;
        Hamburger_Hafen.jpg)
          PRIMARY_COLOR_HEX="#ECA245";
          SECONDARY_COLOR_HEX="#67666C";
          ;;
        Scooter_in_Bangkok.jpg)
          PRIMARY_COLOR_HEX="#69A89D";
          SECONDARY_COLOR_HEX="#0997C9";
          ;;
        Sunset_Tree.jpg)
          PRIMARY_COLOR_HEX="#D65D19";
          SECONDARY_COLOR_HEX="#53674D";
          ;;
        Washington_Square_Skater.jpg)
          PRIMARY_COLOR_HEX="#D8D8D8";
          SECONDARY_COLOR_HEX="#7E7E7E";
          ;;
        Weißdorn_Blüte.jpg)
          PRIMARY_COLOR_HEX="#547602";
          SECONDARY_COLOR_HEX="#DFC540";
          ;;
        Boat_and_Windfarm.jpg)
          PRIMARY_COLOR_HEX="#C39E71";
          SECONDARY_COLOR_HEX="#8591A0";
          ;;
        Coney_Island_Apartments.jpg)
          PRIMARY_COLOR_HEX="#4E8E9A";
          SECONDARY_COLOR_HEX="#FE8F1E";
          ;;
        Dreamy_Sailing.jpg)
          PRIMARY_COLOR_HEX="#B98E7E";
          SECONDARY_COLOR_HEX="#937678";
          ;;
        Frozen_Stream_Macro.jpg)
          PRIMARY_COLOR_HEX="#99ADCD";
          SECONDARY_COLOR_HEX="#87A7CC";
          ;;
        Neon_Pepsi_from_Uber.jpg)
          PRIMARY_COLOR_HEX="#4A8AE4";
          SECONDARY_COLOR_HEX="#A7371B";
          ;;
        New_York_Homes_Birdseyeview.jpg)
          PRIMARY_COLOR_HEX="#CE5D97";
          SECONDARY_COLOR_HEX="#A02F6F";
          ;;
        *)
          PRIMARY_COLOR_HEX="#81913F"
          SECONDARY_COLOR_HEX="#DB8C4B"
          ;;
      esac

      PRIMARY_COLOR_RGB="$(echo $PRIMARY_COLOR_HEX | ${lib.getExe pkgs.pastel} format rgb)"
      PRIMARY_COLOR_RGB=''${PRIMARY_COLOR_RGB#rgb(}
      PRIMARY_COLOR_RGB=''${PRIMARY_COLOR_RGB%)}

      SECONDARY_COLOR_RGB="$(echo $SECONDARY_COLOR_HEX | ${lib.getExe pkgs.pastel} format rgb)"
      SECONDARY_COLOR_RGB=''${SECONDARY_COLOR_RGB#rgb(}
      SECONDARY_COLOR_RGB=''${SECONDARY_COLOR_RGB%)}

      mkdir -p "$HOME/.theme"
      ${lib.getExe pkgs.jq} -n \
        --arg primary_hex "$PRIMARY_COLOR_HEX" \
        --arg secondary_hex "$SECONDARY_COLOR_HEX" \
        --arg primary_rgb "$PRIMARY_COLOR_RGB" \
        --arg secondary_rgb "$SECONDARY_COLOR_RGB" \
        '{primary_hex: $primary_hex, secondary_hex: $secondary_hex, primary_rgb: $primary_rgb, secondary_rgb: $secondary_rgb}' \
        > "$HOME/.theme/palette.json"

      mkdir -p "$HOME/.theme/rofi"
      echo "*{primary: rgba($PRIMARY_COLOR_RGB, 0.78);secondary: rgba($SECONDARY_COLOR_RGB, 0.78);}" > "$HOME/.theme/rofi/colors.rasi"

      mkdir -p "$HOME/.theme/tmux"
      echo -e "set -g @minimal-tmux-bg \"$PRIMARY_COLOR_HEX\"\n set -g @secondary-color \"$SECONDARY_COLOR_HEX\"" > "$HOME/.theme/tmux/colors.conf"

      export TMUX_TMPDIR="/run/user/$(id -u)"
      if ${lib.getExe pkgs.tmux} info &> /dev/null; then
        ${lib.getExe pkgs.tmux} source-file "$HOME/.config/tmux/tmux.conf"
        ${lib.getExe pkgs.tmux} refresh-client -S
      fi

      OBSIDIAN_APPEARANCE_JSON="$HOME/Documents/Marius' Remote Vault/.obsidian/appearance.json"
      if [ -f "$OBSIDIAN_APPEARANCE_JSON" ]; then
        ${lib.getExe pkgs.jq} --arg accent "$PRIMARY_COLOR_HEX" '.accentColor = $accent' "$OBSIDIAN_APPEARANCE_JSON" > "$OBSIDIAN_APPEARANCE_JSON.tmp" && mv "$OBSIDIAN_APPEARANCE_JSON.tmp" "$OBSIDIAN_APPEARANCE_JSON"
      fi

      OBSIDIAN_THEME_CSS="$HOME/Documents/Marius' Remote Vault/.obsidian/snippets/theme.css"
      if [ -f "$OBSIDIAN_THEME_CSS" ]; then
        echo "body {--inline-title-color: rgba($SECONDARY_COLOR_RGB,1);--h1-color: rgba($SECONDARY_COLOR_RGB,1);--h2-color:rgba($SECONDARY_COLOR_RGB,0.85);--h2-color:rgba($SECONDARY_COLOR_RGB,0.78);--h3-color:rgba($SECONDARY_COLOR_RGB,0.74);--h4-color:rgba($SECONDARY_COLOR_RGB,0.69);--h5-color:rgba($SECONDARY_COLOR_RGB,0.55);}" > "$OBSIDIAN_THEME_CSS"
      fi

      ${lib.optionalString isWayland
        /*
        bash
        */
        ''
          mkdir -p "$HOME/.theme/waybar"
          echo "@define-color primary-color $PRIMARY_COLOR_HEX;@define-color secondary-color $SECONDARY_COLOR_HEX;" > "$HOME/.theme/waybar/colors.css"
          pkill -SIGUSR2 waybar

          mkdir -p "$HOME/.theme/swaync"
          echo "@define-color primary-clr $PRIMARY_COLOR_HEX;@define-color secondary-clr $SECONDARY_COLOR_HEX;" > "$HOME/.theme/swaync/colors.css"
          ${pkgs.swaynotificationcenter}/bin/swaync-client -rs
        ''}
    '';
}
