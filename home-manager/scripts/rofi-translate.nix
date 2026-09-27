{
  pkgs,
  scripts,
  helpers,
  lib,
  ...
}: {
  rofi-translate = pkgs.writeShellScript "rofi-translate" ''
    export PATH=${lib.makeBinPath (with pkgs; [translate-shell rofi coreutils gnugrep gawk])}:$PATH

    CLIP_LABEL="󰆏 Translate Clipboard: "

    # Try to safely get clipboard content, limiting the size and removing newlines for a one-line preview
    clipboard_raw=$(${helpers.clipboard.paste} 2>/dev/null)
    clipboard_preview=$(echo "$clipboard_raw" | tr '\n' ' ' | cut -c 1-50)

    if [ -n "$clipboard_preview" ]; then
      options="$CLIP_LABEL$clipboard_preview\n󰈆 Exit"
    else
      options="󰈆 Exit"
    fi

    # Using -p "Translate" and allowing custom typing
    chosen=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Translate" -theme-str 'entry {placeholder:"󰗊 Translate text (en) or lang:text (other language)";} window {width: 600px;}')

    if [ -z "$chosen" ] || [ "$chosen" = "󰈆 Exit" ]; then
      exit 0
    fi

    if [[ "$chosen" == "$CLIP_LABEL"* ]]; then
      text_to_translate="$clipboard_raw"
    else
      text_to_translate="$chosen"
    fi

    if [ -n "$text_to_translate" ]; then
      ${scripts.nixos-notify} -u low -e -t 100000 -h string:synchronous:translation "Translating..." "Please wait..."

      # Check if user provided target language like "de:hello world"
      if [[ "$text_to_translate" =~ ^([a-zA-Z]{2,3}):(.*)$ ]]; then
        target_lang="''${BASH_REMATCH[1]}"
        text="''${BASH_REMATCH[2]}"
        translation=$(${pkgs.translate-shell}/bin/trans -b -t "$target_lang" "$text" 2>/dev/null)
      else
        translation=$(${pkgs.translate-shell}/bin/trans -b "$text_to_translate" 2>/dev/null)
      fi

      if [ -z "$translation" ]; then
        ${scripts.nixos-notify} -u low -e -t 3000 -h string:synchronous:translation "Translation Failed :/" "Could not translate text."
        exit 1
      fi

      echo -n "$translation" | ${helpers.clipboard.copy}
      ${helpers.playSound "clipboard"}
      ${scripts.nixos-notify} -u low -e -t 2000 -h string:synchronous:translation " Copied Translation:" "$translation"
    fi
  '';
}
