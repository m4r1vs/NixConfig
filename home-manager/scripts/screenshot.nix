{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  screenshot =
    pkgs.writeShellScript "screenshot"
    ''
      # Kept after the script exits (GIMP / "Copy Path" actions), so no cleanup trap
      SHOT_DIR="''${XDG_RUNTIME_DIR:-/tmp}/screenshots"
      mkdir -p -m 700 "$SHOT_DIR"
      SHOT_NAME="screenshot_$(date +%Y-%m-%d-%H-%M-%S).png"
      OUTPUT="$SHOT_DIR/$SHOT_NAME"

      HYPR_STDOUT="$(mktemp)"
      trap 'rm -f "$HYPR_STDOUT"' EXIT
      ${pkgs.hyprshot}/bin/hyprshot -m region -o "$SHOT_DIR" --freeze -f "$SHOT_NAME" --silent 2> "$HYPR_STDOUT"

      if grep -q "cancelled" "$HYPR_STDOUT"; then
        ${scripts.nixos-notify} -u low -e -h string:synchronous:screenshot-cancelled "Screenshot Cancelled"
        exit 0
      fi

      ${helpers.playSound "screenshot"}

      FINAL_DESTINATION="$SHOT_DIR"

      if [[ "''${1-}" == *"edit"* ]]; then
        mkdir -p "$HOME/Pictures/Screenshots"
        EDITED="$HOME/Pictures/Screenshots/$SHOT_NAME"

        ${pkgs.swappy}/bin/swappy -f "$OUTPUT" -o "$EDITED"
        if [ ! -f "$EDITED" ]; then
          mv "$OUTPUT" "$EDITED"
        fi
        OUTPUT="$EDITED"
        FINAL_DESTINATION="~/Pictures/Screenshots"
      fi

      RESPONSE="$(${scripts.nixos-notify} -u low -h string:synchronous:screenshot-taken -i "$OUTPUT" --action="gimp=Open in Gimp" --action="path=Copy Path" "Copied and saved to $FINAL_DESTINATION")"

      if [[ "$RESPONSE" == *"gimp"* ]]; then
          ${pkgs.gimp}/bin/gimp "$OUTPUT" &
      fi

      if [[ "$RESPONSE" == *"path"* ]]; then
        echo "$OUTPUT" | ${helpers.clipboard.copy}
        ${helpers.playSound "clipboard"}
      fi
    '';
}
