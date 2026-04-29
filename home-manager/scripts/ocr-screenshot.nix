{
  pkgs,
  scripts,
  config,
  ...
}: {
  ocr-screenshot = pkgs.writeShellScript "ocr-screenshot" ''
    TMP_IMG="/tmp/ocr_screenshot.png"

    if [ "$1" = "sleep-because-rofi" ]; then
      sleep 0.5
    fi

    ${
      if config.configured.hyprland.enable
      then ''
        HYPR_STDOUT="$(mktemp)"
        ${pkgs.hyprshot}/bin/hyprshot -m region -o /tmp -f ocr_screenshot.png --silent --freeze 2> "$HYPR_STDOUT"

        if cat "$HYPR_STDOUT" | grep -q "cancelled"; then
          ${scripts.nixos-notify} -u low -e -h string:synchronous:ocr-cancelled "OCR Cancelled"
          rm -f "$HYPR_STDOUT"
          exit 0
        fi
        rm -f "$HYPR_STDOUT"
        COPY_CMD="${pkgs.wl-clipboard}/bin/wl-copy"
      ''
      else if config.configured.i3.enable
      then ''
        if ! ${pkgs.maim}/bin/maim -s "$TMP_IMG"; then
           ${scripts.nixos-notify} -u low -e -h string:synchronous:ocr-cancelled "OCR Cancelled"
           exit 0
        fi
        COPY_CMD="${pkgs.xclip}/bin/xclip -selection clipboard"
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
        rm -f "$TMP_IMG"
        exit 1
      fi

      echo -n "$TEXT" | eval "$COPY_CMD"

      # Prepare a short preview
      PREVIEW=$(echo "$TEXT" | head -n 3)
      ${scripts.nixos-notify} -u low -e -t 3000 " Copied:" "$PREVIEW"

      rm -f "$TMP_IMG"
    fi
  '';
}
