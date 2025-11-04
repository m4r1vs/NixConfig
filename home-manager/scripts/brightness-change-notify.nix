{pkgs, ...}: {
  brightness-change-notify =
    pkgs.writeShellScript "brightness-change-notify"
    ''

      BACKLIGHT_DEVICE=$(ls /sys/class/backlight/ | head -n 1)
      if [ -z "$BACKLIGHT_DEVICE" ]; then
        echo "Error: No backlight device found in /sys/class/backlight/" >&2
        exit 1
      fi

      BRIGHTNESS_FILE="/sys/class/backlight/$BACKLIGHT_DEVICE/brightness"
      MAX_BRIGHTNESS_FILE="/sys/class/backlight/$BACKLIGHT_DEVICE/max_brightness"

      if [ ! -r "$BRIGHTNESS_FILE" ] || [ ! -r "$MAX_BRIGHTNESS_FILE" ]; then
        echo "Error: Cannot read brightness files:" >&2
        echo "  $BRIGHTNESS_FILE" >&2
        echo "  $MAX_BRIGHTNESS_FILE" >&2
        echo "Check permissions or if the path is correct for device '$BACKLIGHT_DEVICE'." >&2
        exit 1
      fi

      get_brightness_percent() {
        local current max percent
        current=$(cat "$BRIGHTNESS_FILE")
        max=$(cat "$MAX_BRIGHTNESS_FILE")

        if [ -z "$current" ] || [ -z "$max" ] || [ "$max" -eq 0 ]; then
          echo "Error reading brightness values" >&2
          exit 1
          percent=0
        else
          percent=$(( 100 * current / max ))
        fi
        echo "$percent"
      }

      send_notification() {
        local percent="$1"
        if [ "$percent" -eq 0 ]; then
          nerd_icon="󰃚"
        elif [ "$percent" -le 15 ]; then
          nerd_icon="󰃛"
        elif [ "$percent" -le 30 ]; then
          nerd_icon="󰃜"
        elif [ "$percent" -le 50 ]; then
          nerd_icon="󰃝"
        elif [ "$percent" -le 70 ]; then
          nerd_icon="󰃞"
        elif [ "$percent" -le 90 ]; then
          nerd_icon="󰃟"
        else
          nerd_icon="󰃠"
        fi
        notify-send -e \
                    -h "int:value:$percent" \
                    -h string:synchronous:brightness-change-notify \
                    -t 1600 \
                    "Backlight $nerd_icon" "$percent%"
      }

      while ${pkgs.inotify-tools}/bin/inotifywait -q -e modify "$BRIGHTNESS_FILE"; do
        current_percent=$(get_brightness_percent)
        send_notification "$current_percent"
      done

      echo "inotifywait stopped monitoring $BRIGHTNESS_FILE. Exiting." >&2
      exit 1;
    '';
}
