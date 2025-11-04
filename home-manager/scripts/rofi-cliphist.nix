{
  pkgs,
  scripts,
  ...
}: {
  rofi-cliphist =
    pkgs.writeShellScript "rofi-cliphist"
    ''
      pastebin_process() {
        if [ true != "''${delMode}" ]; then
          mapfile -t lines
          total_lines=''${#lines[@]}
          if [[ "''${lines[0]}" = ":d:e:l:e:t:e:"* ]]; then
            "''${0}" --delete
          elif [[ "''${lines[0]}" = ":w:i:p:e:"* ]]; then
            "''${0}" --wipe
          elif [[ "''${lines[0]}" = ":b:a:r:"* ]] || [[ "''${lines[0]}" = *":c:o:p:y:"* ]]; then
            "''${0}" --copy
          elif [[ "''${lines[0]}" = ":f:a:v:"* ]]; then
            "''${0}" --favorites
          elif [[ "''${lines[0]}" = ":o:p:t:"* ]]; then
            "''${0}"
          else
            for ((i = 0; i < total_lines; i++)); do
              line="''${lines[$i]}"
              decoded_line="$(echo -e "$line\t" | ${pkgs.cliphist}/bin/cliphist decode)"
              if [ $i -lt $((total_lines - 1)) ]; then
                printf -v output '%s%s\n' "$output" "$decoded_line"
              else
                printf -v output '%s%s' "$output" "$decoded_line"
              fi
            done
            echo -n "$output"
          fi
        else
          while IFS= read -r line; do
            if [[ "''${line}" = ":w:i:p:e:"* ]]; then
              "''${0}" --wipe
              break
            elif [[ "''${line}" = ":b:a:r:"* ]]; then
              "''${0}" --delete
              break
            else
              if [ -n "$line" ]; then
                ${pkgs.cliphist}/bin/cliphist delete <<<"''${line}"
                ${scripts.nixos-notify} -e "Deleted" "''${line}"
              fi
            fi
          done
          exit 0
        fi
      }

      checkContent() {
        read -r line
        if [[ ''${line} == *"[[ binary data"* ]]; then
            ${pkgs.cliphist}/bin/cliphist decode <<<"$line" | ${pkgs.wl-clipboard}/bin/wl-copy
            imdx=$(awk -F '\t' '{print $1}' <<<$line)
            temprev="/tmp/pastebin-preview_''${imdx}"
            ${pkgs.wl-clipboard}/bin/wl-paste >"''${temprev}"
            ${scripts.nixos-notify} -e -a "Pastebin:" "File Copied" -i "''${temprev}" -t 2000
            return 1
        fi
      }


      tmp_dir="/tmp/cliphist"
      mkdir -p "$tmp_dir"

      read -r -d ''' prog <<EOF
      /^[0-9]+\s<meta http-equiv=/ { next }
      match(\$0, /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/, grp) {
          system("echo " grp[1] "\\\\\t | ${pkgs.cliphist}/bin/cliphist decode >$tmp_dir/"grp[1]"."grp[3])
          print \$0"\0icon\x1f$tmp_dir/"grp[1]"."grp[3]
          next
      }
      1
      EOF

      selected_item=$((
        ${pkgs.cliphist}/bin/cliphist list | gawk "$prog"
      ) | ${pkgs.rofi}/bin/rofi -dmenu -show-icons -multi-select -i -display-columns 2 -theme-str "entry{placeholder:\"Search your Clipboard...\";}element{children:[element-text,element-icon];}inputbar{padding: 0 0 0 0;}" -ballot-selected-str " " -ballot-unselected-str " ")
      ([ -n "''${selected_item}" ] && echo -e "''${selected_item}" | checkContent) || exit 0

      if [ $? -eq 1 ]; then
        ${scripts.paste-string}
        exit 0
      fi

      pastebin_process <<<"''${selected_item}" | ${pkgs.wl-clipboard}/bin/wl-copy
      ${scripts.paste-string}
      echo -e "''${selected_item}\t" | ${pkgs.cliphist}/bin/cliphist delete
    '';
}
