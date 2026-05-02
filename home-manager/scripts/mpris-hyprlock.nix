{pkgs, ...}: {
  mpris-hyprlock =
    pkgs.writeShellScript "mpris-hyprlock"
    ''

      players=$(${pkgs.playerctl}/bin/playerctl -l)

      if [ -z "$players" ]; then
        exit 1
      fi

      PLAYER=""
      SPACING=""
      SOURCE_ICON="   "

      for player in $players; do
        status=$(${pkgs.playerctl}/bin/playerctl -p "$player" status 2>/dev/null)
        if [ "$status" = "Playing" ]; then
          PLAYER="$player"
          break
        fi
      done

      if [[ -z "$PLAYER" ]]; then
        for player in $players; do
          status=$(${pkgs.playerctl}/bin/playerctl -p "$player" status 2>/dev/null)
          if [ "$status" = "Paused" ]; then
            PLAYER="$player"
            break
          fi
        done
      fi

      if [[ -z "$PLAYER" ]]; then
      	PLAYER="$(${pkgs.playerctl}/bin/playerctl metadata | head -n 1 | awk -F' ' '{print $1}')"
      fi

      get_metadata() {
      	${pkgs.playerctl}/bin/playerctl --player=$PLAYER metadata --format "{{ $1 }}" 2>/dev/null
      }

      get_status_icon() {
        OUTPUT=$(${pkgs.playerctl}/bin/playerctl --player=$PLAYER status | grep -q "Playing")
        if [[ $? -eq 0 ]]; then
          echo "  "
        else
          echo "  "
        fi
      }

      get_status_text() {
        OUTPUT=$(${pkgs.playerctl}/bin/playerctl --player=$PLAYER status | grep -q "Playing")
        if [[ $? -eq 0 ]]; then
          echo ""
        else
          echo "(paused)"
        fi
      }

      if [[ "$PLAYER" == *"brave"* ]]; then
          SOURCE_ICON=" 󰖟 "
      elif [[ "$PLAYER" == *"spotify"* ]]; then
          SOURCE_ICON="  "
      elif [[ "$PLAYER" == *"kdeconnect"* ]]; then
          SOURCE_ICON="  "
      elif [[ "$PLAYER" == *"mpv"* ]]; then
          SOURCE_ICON="  "
      elif [[ "$PLAYER" == *"de"* ]]; then
          SOURCE_ICON="  "
      else
          SOURCE_ICON="  "
      fi

      url=$(get_metadata "mpris:artUrl")
      ART_PATH=""
      if [ -n "$url" ]; then
        if [[ "$url" == file://* ]]; then
          ART_PATH=''${url#file://}
        elif [[ "$url" == http* ]]; then
          url_hash=$(echo -n "$url" | sha256sum | cut -d ' ' -f 1)
          ART_PATH="/tmp/hyprlock_art_''${url_hash}.jpeg"
          if [ ! -f "$ART_PATH" ]; then
            ${pkgs.wget}/bin/wget -q -O "$ART_PATH" "$url"
            if [ $? -ne 0 ]; then
              rm -f "$ART_PATH"
              ART_PATH=""
            fi
          fi
        fi
      fi

      if [[ -n "$ART_PATH" && -f "$ART_PATH" ]]; then
        dimensions=$(${pkgs.imagemagick}/bin/identify -format "%w %h" "$ART_PATH" 2>/dev/null)
        if [[ -n "$dimensions" ]]; then
          width=$(echo "$dimensions" | cut -d ' ' -f 1)
          height=$(echo "$dimensions" | cut -d ' ' -f 2)
          is_widescreen=$(echo "scale=2; $width / $height > 1.4" | ${pkgs.bc}/bin/bc)
          if [[ "$is_widescreen" -eq 1 ]]; then
            SPACING="                     "
          fi
        fi
      fi

      # Parse the argument
      case "$1" in
      --title)
      	title=$(get_metadata "xesam:title")
      	album=$(get_metadata "xesam:album")
      	if [ -z "$album" ]; then
      		echo "$SPACING$title"
      	else
      		echo "$SPACING$title - $album"
      	fi
      	;;
      --arturl)
        echo "$ART_PATH"
      	;;
      --artist)
      	artist=$(get_metadata "xesam:artist")
      	if [ -z "$artist" ]; then
      		echo ""
      	else
      		echo "$SPACING$artist"
      	fi
      	;;
      --length)
      	length=$(get_metadata "mpris:length")
      	if [ -z "$length" ]; then
      		echo ""
      	else
      		echo "$SPACING$(echo "scale=2; $length / 1000000 / 60" | ${pkgs.bc}/bin/bc) min. $(get_status_text)"
      	fi
      	;;
      --status)
        echo "$(get_status_icon)"
      	;;
      --album)
      	album=$(get_metadata "xesam:album")
      	if [[ -n $album ]]; then
      		echo "$album"
      	else
      		echo ""
      	fi
      	;;
      --source)
        title=$(get_metadata "xesam:title")
        if [ -z "$title" ]; then
          echo ""
        else
          echo "$SOURCE_ICON"
        fi
      	;;
      *)
      	echo "Invalid option: $1"
      	echo "Usage: $0 --title | --url | --artist | --length | --album | --source"
      	exit 1
      	;;
      esac
    '';
}
