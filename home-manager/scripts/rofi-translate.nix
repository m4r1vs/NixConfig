{
  pkgs,
  scripts,
  config,
  ...
}: {
  rofi-translate = pkgs.writeShellScript "rofi-translate" ''
    export PATH=''${pkgs.lib.makeBinPath [ pkgs.translate-shell pkgs.rofi pkgs.coreutils pkgs.gnugrep pkgs.gawk ]}:$PATH

    ${
      if config.configured.hyprland.enable
      then ''
        PASTE_CMD="${pkgs.wl-clipboard}/bin/wl-paste -n"
        COPY_CMD="${pkgs.wl-clipboard}/bin/wl-copy"
      ''
      else if config.configured.i3.enable
      then ''
        PASTE_CMD="${pkgs.xclip}/bin/xclip -selection clipboard -o"
        COPY_CMD="${pkgs.xclip}/bin/xclip -selection clipboard -i"
      ''
      else ''
        PASTE_CMD="echo"
        COPY_CMD="cat"
      ''
    }

    # Try to safely get clipboard content, limiting the size and removing newlines for a one-line preview
    clipboard_raw=$(eval "$PASTE_CMD" 2>/dev/null)
    clipboard_preview=$(echo "$clipboard_raw" | tr '\n' ' ' | cut -c 1-50)

    if [ -n "$clipboard_preview" ]; then
      options="󰆏 Translate Clipboard: $clipboard_preview\n󰈆 Exit"
    else
      options="󰈆 Exit"
    fi

    # Using -p "Translate" and allowing custom typing
    chosen=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Translate" -theme-str 'entry {placeholder:"󰗊 Translate text (en) or lang:text (other language)";} window {width: 600px;}')

    if [ -z "$chosen" ] || [ "$chosen" = "󰈆 Exit" ]; then
      exit 0
    fi

    if [[ "$chosen" == " "* ]]; then
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

      echo -n "$translation" | eval "$COPY_CMD"
      ${scripts.nixos-notify} -u low -e -t 2000 -h string:synchronous:translation " Copied Translation:" "$translation"
    fi
  '';
}
