{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  connect-galaxy-buds = helpers.mkScript {
    name = "connect-galaxy-buds";
    runtimeInputs = [
      pkgs.bluez
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.pipewire
      pkgs.util-linux
      pkgs.wireplumber
    ];
    text =
      # bash
      ''
        default_mac="8C:A3:EC:E5:8C:99"
        icon="${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/devices/audio-headset.svg"
        action="''${1:-connect}"

        notify() {
          local urgency="$1"
          local timeout_ms="$2"
          local summary="$3"
          local body="$4"
          ${scripts.nixos-notify} -u "$urgency" -e -t "$timeout_ms" -i "$icon" -h string:synchronous:connect-galaxy-buds "$summary" "$body"
        }

        find_mac() {
          local devices
          devices=$(bluetoothctl devices 2>/dev/null || true)
          if printf '%s\n' "$devices" | grep -qi "^Device ''${default_mac} "; then
            printf '%s\n' "$default_mac"
          else
            printf '%s\n' "$devices" | awk 'tolower($0) ~ /buds/ { print $2; exit }'
          fi
        }

        wait_device() {
          local mac="$1"
          local id=""
          for _ in $(seq 1 32); do
            pw_json=$(pw-dump 2>/dev/null || echo '[]')
            id=$(printf '%s' "$pw_json" | jq -r --arg mac "$mac" '
              [ .[]
                | select(.type == "PipeWire:Interface:Device"
                         and ((.info.props["api.bluez5.address"] // "") | ascii_downcase) == ($mac | ascii_downcase)
                         and ((.info.params.EnumProfile // []) | length) > 0)
              ][0].id // empty
            ')
            if [ -n "$id" ]; then
              printf '%s\n' "$id"
              return 0
            fi
            sleep 0.25
          done
          return 1
        }

        set_defaults_and_notify() {
          local mac="$1"
          local dev_name="$2"
          local device_id="$3"
          local wanted_profile="$4"
          local summary="$5"
          local sink_id=""
          local source_id=""
          local active_profile=""

          for _ in $(seq 1 25); do
            pw_json=$(pw-dump 2>/dev/null || echo '[]')
            active_profile=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
              [ .[] | select(.id == $id) ][0].info.params.Profile[0].name // ""
            ')
            sink_id=$(printf '%s' "$pw_json" | jq -r --arg id "$device_id" '
              [ .[]
                | select(.type == "PipeWire:Interface:Node"
                         and ((.info.props["device.id"] // "") | tostring) == $id
                         and .info.props["media.class"] == "Audio/Sink")
              ][0].id // empty
            ')
            source_id=$(printf '%s' "$pw_json" | jq -r --arg id "$device_id" '
              [ .[]
                | select(.type == "PipeWire:Interface:Node"
                         and ((.info.props["device.id"] // "") | tostring) == $id
                         and .info.props["media.class"] == "Audio/Source")
              ][0].id // empty
            ')
            if [ -n "$sink_id" ] && [ -n "$source_id" ] \
              && { [ -z "$wanted_profile" ] || [ "$active_profile" = "$wanted_profile" ]; }; then
              break
            fi
            sleep 0.2
          done

          local switched=""
          if [ -n "$sink_id" ]; then
            wpctl set-default "$sink_id"
            switched="Output"
          fi
          if [ -n "$source_id" ]; then
            wpctl set-default "$source_id"
            if [ -n "$switched" ]; then
              switched="Output & input"
            else
              switched="Input"
            fi
          fi

          local profile_desc codec battery details
          profile_desc=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
            [ .[] | select(.id == $id) ][0].info.params.Profile[0].description // ""
          ')
          codec=$(printf '%s' "$profile_desc" | sed -n 's/.*codec \([^)]*\)).*/\1/p')
          battery=$(bluetoothctl info "$mac" 2>/dev/null | sed -n 's/.*Battery Percentage:.*(\([0-9]*\)).*/\1/p' | head -n 1)

          details="''${switched:-Connected}"
          if [ -n "$codec" ]; then
            details="$details • $codec"
          fi
          if [ -n "$battery" ]; then
            details="$details • ''${battery}%"
          fi

          notify low 4000 "$summary" "$details"
        }

        case "$action" in
          disconnect)
            mac=$(find_mac)
            if [ -z "$mac" ]; then
              notify normal 4000 "Galaxy Buds not found" "No paired Galaxy Buds device found"
              exit 1
            fi
            dev_info=$(bluetoothctl info "$mac" 2>/dev/null || true)
            dev_name=$(printf '%s\n' "$dev_info" | awk -F': ' '/^[[:space:]]*Alias:/ { print $2; exit }')
            dev_name="''${dev_name:-Galaxy Buds}"
            if printf '%s\n' "$dev_info" | grep -q 'Connected: yes'; then
              bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
              notify low 3500 "$dev_name disconnected" "Bluetooth connection closed"
            else
              notify low 3000 "$dev_name already disconnected" ""
            fi
            ;;

          profile)
            wanted_profile="''${2:-}"
            if [ -z "$wanted_profile" ]; then
              echo "Usage: $0 profile <profile-name>" >&2
              exit 1
            fi
            mac=$(find_mac)
            if [ -z "$mac" ]; then
              notify normal 4000 "Galaxy Buds not found" "Pair your Galaxy Buds via Bluetooth first"
              exit 1
            fi
            dev_info=$(bluetoothctl info "$mac" 2>/dev/null || true)
            dev_name=$(printf '%s\n' "$dev_info" | awk -F': ' '/^[[:space:]]*Alias:/ { print $2; exit }')
            dev_name="''${dev_name:-Galaxy Buds}"

            pw_json="[]"
            if ! device_id=$(wait_device "$mac"); then
              notify normal 5000 "$dev_name not connected" "Connect the earbuds before switching codecs"
              exit 1
            fi
            pw_json=$(pw-dump 2>/dev/null || echo '[]')
            target_idx=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" --arg want "$wanted_profile" '
              [ .[] | select(.id == $id) ][0].info.params.EnumProfile
              | map(select(.name == $want and .available != "no"))[0].index // empty
            ')
            if [ -z "$target_idx" ]; then
              notify normal 5000 "$dev_name" "Profile $wanted_profile is not currently available"
              exit 1
            fi
            wpctl set-profile "$device_id" "$target_idx" || true
            set_defaults_and_notify "$mac" "$dev_name" "$device_id" "$wanted_profile" "$dev_name codec switched"
            ;;

          connect)
            # Ensure Bluetooth radio is unblocked and powered on
            if rfkill list bluetooth 2>/dev/null | grep -qi 'Soft blocked: yes'; then
              rfkill unblock bluetooth || true
              sleep 1
            fi
            if ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
              bluetoothctl power on >/dev/null 2>&1 || true
              sleep 1
            fi

            mac=$(find_mac)
            if [ -z "$mac" ]; then
              notify normal 6000 "Galaxy Buds not found" "Pair your Galaxy Buds via Bluetooth first"
              exit 1
            fi

            dev_info=$(bluetoothctl info "$mac" 2>/dev/null || true)
            dev_name=$(printf '%s\n' "$dev_info" | awk -F': ' '/^[[:space:]]*Alias:/ { print $2; exit }')
            dev_name="''${dev_name:-Galaxy Buds}"

            # Trust so buds-initiated reconnects / quick switches are never blocked
            if printf '%s\n' "$dev_info" | grep -q 'Trusted: no'; then
              bluetoothctl trust "$mac" >/dev/null 2>&1 || true
            fi

            # Connect if not already connected (retry once for phone->PC quick-switch handoff)
            if ! printf '%s\n' "$dev_info" | grep -q 'Connected: yes'; then
              notify low 4000 "Connecting $dev_name…" "Pulling audio connection to this computer"
              connected=false
              for attempt in 1 2; do
                if timeout 12 bluetoothctl connect "$mac" >/dev/null 2>&1 \
                  || bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
                  connected=true
                  break
                fi
                if [ "$attempt" -eq 1 ]; then
                  sleep 1
                fi
              done
              if [ "$connected" != "true" ]; then
                notify normal 6000 "Failed to connect $dev_name" "Make sure the earbuds are out of the case and in range"
                exit 1
              fi
            fi

            pw_json="[]"
            if ! device_id=$(wait_device "$mac"); then
              notify normal 6000 "$dev_name connected" "Bluetooth connected, but no PipeWire audio device appeared"
              exit 1
            fi
            pw_json=$(pw-dump 2>/dev/null || echo '[]')

            # Prefer LE Audio (BAP LC3) if available, otherwise SBC-XQ over Classic A2DP.
            # Leave an already-active call/duplex profile undisturbed.
            cur_profile=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
              [ .[] | select(.id == $id) ][0].info.params.Profile[0].name // ""
            ')
            wanted_profile="$cur_profile"
            case "$cur_profile" in
              headset-head-unit*|bap-duplex)
                ;;
              *)
                best_profile=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
                  [ .[] | select(.id == $id) ][0].info.params.EnumProfile as $eps
                  | ["bap-sink", "bap-duplex", "a2dp-sink-sbc_xq", "a2dp-sink", "a2dp-sink-sbc"]
                  | map(. as $want | ($eps // []) | map(select(.name == $want and .available != "no")) | .[0])
                  | map(select(. != null))
                  | .[0] // empty
                  | "\(.index)\t\(.name)"
                ')
                if [ -n "$best_profile" ]; then
                  IFS=$'\t' read -r target_idx target_name <<< "$best_profile"
                  wanted_profile="$target_name"
                  if [ "$target_name" != "$cur_profile" ]; then
                    wpctl set-profile "$device_id" "$target_idx" || true
                  fi
                fi
                ;;
            esac

            set_defaults_and_notify "$mac" "$dev_name" "$device_id" "$wanted_profile" "$dev_name connected"
            ;;

          *)
            echo "Usage: $0 {connect|disconnect|profile <name>}" >&2
            exit 1
            ;;
        esac
      '';
  };
}
