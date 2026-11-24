{
  pkgs,
  helpers,
  ...
}: {
  volume-change-notify = helpers.mkScript {
    name = "volume-change-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.libnotify
      pkgs.pulseaudio
      pkgs.wireplumber
    ];
    text =
      # bash
      ''
        export LC_ALL=C

        # Reconnect if pipewire-pulse isn't ready yet or restarts mid-session.
        while true; do
          volume_output=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null || true)

          # Subscribe to sink/server events via PipeWire's PulseAudio layer instead
          # of pw-mon, which fires on every unrelated PipeWire node/stream change.
          while IFS= read -r line; do
            case "$line" in
              "Event 'change' on sink #"*|"Event 'change' on server"*)
                new_volume_output=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null || true)
                if [ -n "$new_volume_output" ] && [ "$new_volume_output" != "$volume_output" ]; then
                  volume_output="$new_volume_output"
                  # Drain wpctl output instead of exiting early in awk so pipefail never trips on SIGPIPE.
                  device_name=$(wpctl inspect @DEFAULT_SINK@ 2>/dev/null | awk -F'"' '/node\.description/ && !found { print $2; found = 1 }' || true)
                  device_name="''${device_name:-Audio}"
                  if [[ "$volume_output" == *"[MUTED]"* ]]; then
                    notify-send -u low -e -t 1600 -h int:value:0 -h string:synchronous:volume-change-notify "$device_name" "Muted  " || true
                  elif [[ "$volume_output" =~ ^Volume:\ ([0-9]+)\.([0-9]{2}) ]]; then
                    vol_pct=$((10#''${BASH_REMATCH[1]}''${BASH_REMATCH[2]}))
                    notify-send -u low -e -t 1600 -h "int:value:$vol_pct" -h string:synchronous:volume-change-notify "$device_name" "''${vol_pct}%" || true
                  fi
                fi
                ;;
            esac
          done < <(pactl subscribe)

          sleep 1
        done
      '';
  };
}
