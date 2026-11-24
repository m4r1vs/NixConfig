{
  pkgs,
  helpers,
  ...
}: {
  brightness-change-notify = helpers.mkScript {
    name = "brightness-change-notify";
    runtimeInputs = [
      pkgs.inotify-tools
      pkgs.libnotify
    ];
    text =
      # bash
      ''
        BACKLIGHT_DIR=""
        for dev in /sys/class/backlight/*; do
          if [ -r "$dev/brightness" ] && [ -r "$dev/max_brightness" ]; then
            BACKLIGHT_DIR="$dev"
            break
          fi
        done

        if [ -z "$BACKLIGHT_DIR" ]; then
          echo "No readable backlight device found in /sys/class/backlight/" >&2
          exit 0
        fi

        BRIGHTNESS_FILE="$BACKLIGHT_DIR/brightness"
        MAX_BRIGHTNESS_FILE="$BACKLIGHT_DIR/max_brightness"

        get_brightness_percent() {
          local current max
          read -r current < "$BRIGHTNESS_FILE" || return 1
          read -r max < "$MAX_BRIGHTNESS_FILE" || return 1

          if ! [[ "$current" =~ ^[0-9]+$ ]] || ! [[ "$max" =~ ^[0-9]+$ ]] || [ "$max" -eq 0 ]; then
            echo "Error reading brightness values" >&2
            return 1
          fi
          echo $((100 * current / max))
        }

        send_notification() {
          local percent="$1"
          local nerd_icon
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
            -u low \
            -h "int:value:$percent" \
            -h string:synchronous:brightness-change-notify \
            -t 1600 \
            "Backlight $nerd_icon" "''${percent}%" || true
        }

        # One long-running watcher, so no change is missed between restarts
        while read -r _; do
          if current_percent=$(get_brightness_percent); then
            send_notification "$current_percent"
          fi
        done < <(inotifywait -m -q -e modify "$BRIGHTNESS_FILE")

        echo "inotifywait stopped monitoring $BRIGHTNESS_FILE. Exiting." >&2
        exit 1
      '';
  };
}
