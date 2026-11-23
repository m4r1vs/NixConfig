/*
"Ask about this" Rofi workflow for hey-computer (`SUPER + SHIFT + a`, `rofi-launch ask-about`).
Captures the primary selection, clipboard, or an OCR'd screen region, lets the
user pick a lead-in or type a custom question, and pipes the combined request
into `hey-computer ask --new`.
*/
{
  pkgs,
  lib,
  config,
  systemArgs,
  scripts,
  helpers,
  ...
}: let
  heyComputer = lib.getExe config.home-manager.users.${systemArgs.username}.programs.hey-computer.package;
in {
  rofi-ask-about = helpers.mkScript {
    name = "rofi-ask-about";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.hyprshot
      pkgs.jq
      pkgs.procps
      pkgs.rofi
      pkgs.tesseract
      pkgs.wl-clipboard
    ];
    text =
      # bash
      ''
        preview_of() {
          printf '%s' "$1" | tr '\r\n\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//' | cut -c 1-72
        }

        ocr_region() {
          local work img err_file text
          work=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/hey-ocr.XXXXXX")
          # shellcheck disable=SC2064
          trap "rm -rf '$work'" RETURN
          img="$work/ocr.png"
          err_file="$work/hyprshot.err"

          hyprshot -m region -o "$work" -f ocr.png --silent --freeze 2>"$err_file" || true
          if grep -q "cancelled" "$err_file" || [ ! -f "$img" ]; then
            ${scripts.nixos-notify} -u low -e -h string:synchronous:hey-ask-ocr "Ask about this" "OCR cancelled"
            return 1
          fi

          text=$(tesseract "$img" stdout -l eng+deu 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
          if [ -z "$text" ]; then
            ${scripts.nixos-notify} -u low -t 3000 -h string:synchronous:hey-ask-ocr "Ask about this" "No text detected in selected region."
            return 1
          fi
          printf '%s' "$text"
        }

        primary=$(wl-paste --primary --no-newline 2>/dev/null || true)
        clipboard=$(wl-paste --no-newline 2>/dev/null || true)

        mode="''${1:-auto}"
        source_label=""
        context=""

        case "$mode" in
        selection)
          source_label="Selection"
          context="$primary"
          ;;
        clipboard)
          source_label="Clipboard"
          context="$clipboard"
          ;;
        ocr)
          source_label="OCR"
          context=$(ocr_region) || exit 0
          ;;
        *)
          if [ -n "$primary" ]; then
            source_label="Selection"
            context="$primary"
          elif [ -n "$clipboard" ]; then
            source_label="Clipboard"
            context="$clipboard"
          else
            source_label="OCR"
            context=$(ocr_region) || exit 0
          fi
          ;;
        esac

        if [ -z "$context" ]; then
          ${scripts.nixos-notify} -u low -t 3000 "Ask about this" "No text in selection or clipboard."
          exit 0
        fi

        SWITCH_CLIP="󰆏 Switch to clipboard: "
        SWITCH_SEL="󰒅 Switch to selection: "
        OPT_OCR="󰩬 OCR screen region..."

        while true; do
          char_count=$(printf '%s' "$context" | wc -m)
          preview=$(preview_of "$context")
          escaped_preview=$(printf '%s' "$preview" | jq -Rr @html)
          mesg="<b>$source_label</b> ($char_count chars): $escaped_preview"

          options=$(printf '%s\n' \
            "Explain this:" \
            "Explain this error:" \
            "Summarise:" \
            "Translate to English:" \
            "Translate to German:" \
            "Rewrite / polish:")

          if [ "$source_label" != "Clipboard" ] && [ -n "$clipboard" ] && [ "$clipboard" != "$context" ]; then
            options=$(printf '%s\n%s%s' "$options" "$SWITCH_CLIP" "$(preview_of "$clipboard")")
          fi
          if [ "$source_label" != "Selection" ] && [ -n "$primary" ] && [ "$primary" != "$context" ]; then
            options=$(printf '%s\n%s%s' "$options" "$SWITCH_SEL" "$(preview_of "$primary")")
          fi
          options=$(printf '%s\n%s' "$options" "$OPT_OCR")

          chosen=$(printf '%s\n' "$options" | rofi -dmenu -i -p "Ask about" \
            -mesg "$mesg" \
            -theme-str 'entry { placeholder: "Pick an action or type a question..."; } element-icon { enabled: false; } icon-current-entry { enabled: false; } inputbar { padding: 0 0 0 42; } message { padding: 8 16; background-color: transparent; } textbox { background-color: transparent; text-color: #b5afa7; } window { padding: 26% 24%; }') || exit 0

          chosen=$(printf '%s' "$chosen" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
          [ -n "$chosen" ] || exit 0

          if [[ "$chosen" == "$SWITCH_CLIP"* ]]; then
            source_label="Clipboard"
            context="$clipboard"
            continue
          elif [[ "$chosen" == "$SWITCH_SEL"* ]]; then
            source_label="Selection"
            context="$primary"
            continue
          elif [ "$chosen" = "$OPT_OCR" ]; then
            sleep 0.25
            context=$(ocr_region) || exit 0
            source_label="OCR"
            continue
          fi

          break
        done

        # Cap payload below hey-computer's 256 KiB JSON socket line limit
        bounded=$(printf '%s' "$context" | head -c 200000)

        printf '%s\n\n%s' "$chosen" "$bounded" | ${heyComputer} ask --new
        pkill -RTMIN+12 -x '\.?waybar(-wrapped)?' || true
      '';
  };
}
