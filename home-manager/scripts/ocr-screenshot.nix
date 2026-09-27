{
  pkgs,
  scripts,
  helpers,
  config,
  ...
}: {
  ocr-screenshot = pkgs.writeShellScript "ocr-screenshot" ''
    WORK=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/ocr.XXXXXX")
    trap 'rm -rf "$WORK"' EXIT
    TMP_IMG="$WORK/ocr.png"

    if [ "$1" = "sleep-because-rofi" ]; then
      sleep 0.5
    fi

    ${
      if config.configured.hyprland.enable
      then ''
        HYPR_STDOUT="$WORK/hyprshot.err"
        ${pkgs.hyprshot}/bin/hyprshot -m region -o "$WORK" -f ocr.png --silent --freeze 2> "$HYPR_STDOUT"

        if grep -q "cancelled" "$HYPR_STDOUT"; then
          ${scripts.nixos-notify} -u low -e -h string:synchronous:ocr-cancelled "OCR Cancelled"
          exit 0
        fi
      ''
      else if config.configured.i3.enable
      then ''
        if ! ${pkgs.maim}/bin/maim -s "$TMP_IMG"; then
           ${scripts.nixos-notify} -u low -e -h string:synchronous:ocr-cancelled "OCR Cancelled"
           exit 0
        fi
      ''
      else ''
        echo "Unsupported Desktop Environment"
        exit 1
      ''
    }

    if [ -f "$TMP_IMG" ]; then
      TEXT=$(${pkgs.tesseract}/bin/tesseract "$TMP_IMG" stdout -l eng+deu 2>/dev/null)

      if [ -z "$TEXT" ]; then
        ${scripts.nixos-notify} -u low -t 3000 "OCR Failed" "No text detected in selection."
        exit 1
      fi

      echo -n "$TEXT" | ${helpers.clipboard.copy}
      ${helpers.playSound "clipboard"}

      # Prepare a short preview
      PREVIEW=$(echo "$TEXT" | head -n 3)
      ${scripts.nixos-notify} -u low -e -t 3000 " Copied:" "$PREVIEW"
    fi
  '';
}
