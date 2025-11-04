{pkgs, ...}: {
  volume-change-notify =
    pkgs.writeShellScript "volume-change-notify"
    ''
      volume_output=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_SINK@)
      volume=$(echo "$volume_output" | sed 's/ \[MUTED\]//' | awk -F ': ' '{ print $2 }')
      muted=$(echo "$volume_output" | grep -o "[MUTED]")

      ${pkgs.pipewire}/bin/pw-mon --hide-params --hide-props | while IFS= read -r line; do
        if [[ "$line" == changed* ]]; then
          new_volume_output=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_SINK@)
          new_volume=$(echo "$new_volume_output" | sed 's/ \[MUTED\]//' | awk -F ": " '{ print $2 }')
          new_muted=$(echo "$new_volume_output" | grep -o "[MUTED]")

          if [[ "$new_volume" != "$volume" || "$new_muted" != "$muted" ]]; then
            volume=$new_volume
            muted=$new_muted
            device_name="$(${pkgs.wireplumber}/bin/wpctl inspect @DEFAULT_SINK@ | grep "node.description" | awk -F'"' '{ for (i=2; i<=NF; i+=2) printf "%s\n", $i }')"
            if [[ -n "$muted" ]]; then
              ${pkgs.libnotify}/bin/notify-send -e -t 1600 -h int:value:0 -h string:synchronous:volume-change-notify "$device_name" "Muted  "
            else
              volume_percentage=$(echo "$volume * 100" | ${pkgs.bc}/bin/bc | awk -F '.' '{ print $1 }')
              ${pkgs.libnotify}/bin/notify-send -e -t 1600 -h int:value:$volume_percentage -h string:synchronous:volume-change-notify "$device_name" "$volume_percentage%"
            fi
          fi
        fi
      done
    '';
}
