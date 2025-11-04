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
          SPACING="       "
          SOURCE_ICON=" 󰖟 "
      elif [[ "$PLAYER" == *"spotify"* ]]; then
          SOURCE_ICON="  "
      elif [[ "$PLAYER" == *"kdeconnect"* ]]; then
          SOURCE_ICON="  "
      elif [[ "$PLAYER" == *"mpv"* ]]; then
          SOURCE_ICON="  "
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
      	url=$(get_metadata "mpris:artUrl")
      	if [ -z "$url" ]; then
      		echo ""
      	else
      		if [[ "$url" == file://* ]]; then
      			url=''${url#file://}
      		elif [[ "$url" == http* ]]; then
      			url_hash=$(echo -n "$url" | sha256sum | cut -d ' ' -f 1)

      			tmp_art_path="/tmp/hyprlock_art_''${url_hash}.jpeg"

      			if [ ! -f "$tmp_art_path" ]; then
      				${pkgs.wget}/bin/wget -q -O "$tmp_art_path" "$url"
      				if [ $? -ne 0 ]; then
      					rm -f "$tmp_art_path"
      					url=""
      				else
      					url="$tmp_art_path"
      				fi
      			else
      				url="$tmp_art_path"
      			fi
      		else
      			url=""
      		fi
      		echo "$url"
      	fi
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
      	echo "$SOURCE_ICON"
      	;;
      *)
      	echo "Invalid option: $1"
      	echo "Usage: $0 --title | --url | --artist | --length | --album | --source"
      	exit 1
      	;;
      esac
    '';
}
