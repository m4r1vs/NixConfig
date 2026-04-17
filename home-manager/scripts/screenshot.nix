{
  pkgs,
  scripts,
  config,
  lib,
  ...
}: {
  screenshot =
    pkgs.writeShellScript "screenshot"
    ''
      HYPR_STDOUT="$(mktemp)"
      ${pkgs.hyprshot}/bin/hyprshot -m region -o "/tmp" --freeze -f "tmp_screenshot.png" --silent 2> "$HYPR_STDOUT"

      if cat $HYPR_STDOUT | grep -q "cancelled"; then
        ${scripts.nixos-notify} -e -h string:synchronous:screenshot-cancelled "Screenshot Cancelled"
        exit 0
      fi

      ${lib.optionalString (config.configured.system-sounds.enable && config.configured.system-sounds.screenshot.enable) ''
        ${pkgs.mpv}/bin/mpv --no-video --volume=80 ${config.configured.system-sounds.screenshot.soundFile} &
      ''}

      FINAL_DESTINATION="/tmp"
      OUTPUT="/tmp/tmp_screenshot.png"

      if [[ "$1" == *"edit"* ]]; then
        OUTPUT="$HOME/Pictures/Screenshots/screenshot_$(date +%Y-%m-%d-%H-%M-%S).png"

        ${pkgs.swappy}/bin/swappy -f "/tmp/tmp_screenshot.png" -o "$OUTPUT"
        if [ ! -f "$OUTPUT" ]; then
          mv /tmp/tmp_screenshot.png "$OUTPUT"
        fi
        FINAL_DESTINATION="~/Pictures/Screenshots"
      fi

      RESPONSE="$(${scripts.nixos-notify} -h string:synchronous:screenshot-taken -i "$OUTPUT" --action="gimp=Open in Gimp" --action="path=Copy Path" "Copied and saved to $FINAL_DESTINATION")"

      if [[ "$RESPONSE" == *"gimp"* ]]; then
          ${pkgs.gimp}/bin/gimp "$OUTPUT" &
      fi

      if [[ "$RESPONSE" == *"path"* ]]; then
        echo "$OUTPUT" | ${pkgs.wl-clipboard}/bin/wl-copy
      fi
    '';
}
