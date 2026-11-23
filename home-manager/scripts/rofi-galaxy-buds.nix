{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  rofi-galaxy-buds = helpers.mkScript {
    name = "rofi-galaxy-buds";
    runtimeInputs = [
      pkgs.bluez
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.pipewire
      pkgs.rofi
      pkgs.systemd
      pkgs.wireplumber
    ];
    text =
      # bash
      ''
        default_mac="8C:A3:EC:E5:8C:99"
        gbc="${pkgs.galaxy-buds-client}/bin/GalaxyBudsClient"
        icon="${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/devices/audio-headset.svg"

        notify() {
          local urgency="$1"
          local timeout_ms="$2"
          local summary="$3"
          local body="$4"
          ${scripts.nixos-notify} -u "$urgency" -e -t "$timeout_ms" -i "$icon" -h string:synchronous:connect-galaxy-buds "$summary" "$body"
        }

        icon_for_action() {
          local id="$1"
          case "$id" in
            *Anc*|*NoiseControl*|*Nc*) printf '󰂰' ;;
            *Ambient*) printf '󰕾' ;;
            *Equalizer*|*Eq*) printf '󰺢' ;;
            *Touch*|*Lock*) printf '󰌾' ;;
            *Conversation*|*Voice*) printf '󰍬' ;;
            *Find*) printf '󰍉' ;;
            *Pair*) printf '󰂯' ;;
            *Battery*|*Popup*) printf '󰁹' ;;
            *Play*|*Pause*|*Media*) printf '󰐎' ;;
            *) printf '󰋋' ;;
          esac
        }

        humanize_action() {
          printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g'
        }

        # Locate Buds MAC & Bluetooth status
        devices=$(bluetoothctl devices 2>/dev/null || true)
        mac=""
        if printf '%s\n' "$devices" | grep -qi "^Device ''${default_mac} "; then
          mac="$default_mac"
        else
          mac=$(printf '%s\n' "$devices" | awk 'tolower($0) ~ /buds/ { print $2; exit }')
        fi

        dev_name="Galaxy Buds"
        connected=false
        bt_battery=""
        if [ -n "$mac" ]; then
          dev_info=$(bluetoothctl info "$mac" 2>/dev/null || true)
          alias_name=$(printf '%s\n' "$dev_info" | awk -F': ' '/^[[:space:]]*Alias:/ { print $2; exit }')
          dev_name="''${alias_name:-$dev_name}"
          if printf '%s\n' "$dev_info" | grep -q 'Connected: yes'; then
            connected=true
          fi
          bt_battery=$(printf '%s\n' "$dev_info" | sed -n 's/.*Battery Percentage:.*(\([0-9]*\)).*/\1/p' | head -n 1)
        fi

        # PipeWire status (active codec + whether Buds are already default audio)
        pw_json="[]"
        device_id=""
        cur_profile=""
        cur_codec=""
        is_default_audio=false
        if [ "$connected" = "true" ] && [ -n "$mac" ]; then
          pw_json=$(pw-dump 2>/dev/null || echo '[]')
          device_id=$(printf '%s' "$pw_json" | jq -r --arg mac "$mac" '
            [ .[]
              | select(.type == "PipeWire:Interface:Device"
                       and ((.info.props["api.bluez5.address"] // "") | ascii_downcase) == ($mac | ascii_downcase))
            ][0].id // empty
          ')
          if [ -n "$device_id" ]; then
            cur_profile=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
              [ .[] | select(.id == $id) ][0].info.params.Profile[0].name // ""
            ')
            profile_desc=$(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
              [ .[] | select(.id == $id) ][0].info.params.Profile[0].description // ""
            ')
            cur_codec=$(printf '%s' "$profile_desc" | sed -n 's/.*codec \([^)]*\)).*/\1/p')

            sink_name=$(printf '%s' "$pw_json" | jq -r --arg id "$device_id" '
              [ .[]
                | select(.type == "PipeWire:Interface:Node"
                         and ((.info.props["device.id"] // "") | tostring) == $id
                         and .info.props["media.class"] == "Audio/Sink")
              ][0].info.props["node.name"] // empty
            ')
            default_sink=$(pw-metadata -n default 0 default.audio.sink 2>/dev/null | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
            if [ -n "$sink_name" ] && [ "$sink_name" = "$default_sink" ]; then
              is_default_audio=true
            fi
          fi
        fi

        # Check GalaxyBudsClient D-Bus IPC (fast ~2ms check before invoking .NET CLI)
        gbc_running=false
        gbc_connected=false
        gbc_battery=""
        gbc_actions=""
        if busctl --user status me.timschneeberger.GalaxyBudsClient >/dev/null 2>&1; then
          gbc_running=true
          gbc_dev_json=$(timeout 2 "$gbc" device --get-all --json 2>/dev/null || true)
          if [ -n "$gbc_dev_json" ] && printf '%s' "$gbc_dev_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
            gbc_connected=true
            gbc_battery=$(printf '%s' "$gbc_dev_json" | jq -r '
              def fmt(k; p): if (.[k] | type) == "number" and .[k] > 0 and .[k] <= 100 then "\(p) \(.[k])%" else empty end;
              [ fmt("BatteryLeft"; "L"), fmt("BatteryRight"; "R"), fmt("BatteryCase"; "Case") ]
              | join(" ")
            ')
          fi
          if [ "$connected" = "true" ] || [ "$gbc_connected" = "true" ]; then
            gbc_actions=$(timeout 2 "$gbc" action --list 2>/dev/null || true)
          fi
        fi

        # Build status header for Rofi placeholder
        status_parts=("$dev_name")
        if [ "$connected" = "true" ]; then
          if [ -n "$gbc_battery" ]; then
            status_parts+=("$gbc_battery")
          elif [ -n "$bt_battery" ]; then
            status_parts+=("''${bt_battery}%")
          fi
          if [ -n "$cur_codec" ]; then
            status_parts+=("$cur_codec")
          fi
        else
          status_parts+=("Disconnected")
        fi
        status_label=$(IFS='·'; printf '%s' "''${status_parts[*]}" | sed 's/·/ · /g; s/"//g')

        # Build menu rows: Connect/Disconnect is ALWAYS first for instant quick-connect
        entries=()
        declare -A action_map=()
        opt_connect="󰂱  Connect"
        opt_connect_switch="󰂱  Connect & Switch Audio"
        opt_disconnect="󰂲  Disconnect"
        opt_battery_popup="󰁹  Show Battery Popup"
        opt_codec_menu="󰓃  Switch Audio Codec''${cur_codec:+ (''${cur_codec})}"
        opt_open_gui="󰒓  Open GalaxyBudsClient"
        opt_start_tray="󰐊  Start GalaxyBudsClient (Tray)"

        if [ "$connected" = "false" ]; then
          entries+=("$opt_connect")
        elif [ "$is_default_audio" = "false" ]; then
          entries+=("$opt_connect_switch")
          entries+=("$opt_disconnect")
        else
          entries+=("$opt_disconnect")
        fi

        # Append live GalaxyBudsClient actions when running and connected
        has_battery_popup=false
        if [ "$gbc_running" = "true" ] && [ -n "$gbc_actions" ]; then
          while IFS= read -r line; do
            # Trim leading/trailing whitespace
            trimmed=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
            [ -z "$trimmed" ] && continue
            # Skip banners, headers, and error/log lines
            case "$trimmed" in
              GalaxyBudsClient*|Copyright*|error:*|\[*|Available*|Usage:*|-*) continue ;;
            esac

            action_id=""
            action_desc=""
            if [[ "$trimmed" =~ ^([A-Za-z][A-Za-z0-9_]+)[[:space:]]*[:|-][[:space:]]*(.+)$ ]]; then
              action_id="''${BASH_REMATCH[1]}"
              action_desc="''${BASH_REMATCH[2]}"
            elif [[ "$trimmed" =~ ^([A-Za-z][A-Za-z0-9_]+)[[:space:]]{2,}(.+)$ ]]; then
              action_id="''${BASH_REMATCH[1]}"
              action_desc="''${BASH_REMATCH[2]}"
            elif [[ "$trimmed" =~ ^([A-Za-z][A-Za-z0-9_]+)$ ]]; then
              action_id="''${BASH_REMATCH[1]}"
              action_desc=$(humanize_action "$action_id")
            else
              continue
            fi

            # Skip actions already handled directly by our menu
            case "$action_id" in
              None|Connect|Disconnect|ToggleManagerVisibility|ToggleVisibility)
                continue
                ;;
              ShowBatteryPopup|DisplayBatteryPopup)
                has_battery_popup=true
                ;;
            esac

            glyph=$(icon_for_action "$action_id")
            label="''${glyph}  ''${action_desc}"
            if [ -z "''${action_map[$label]+x}" ]; then
              action_map["$label"]="$action_id"
              entries+=("$label")
            fi
          done <<< "$gbc_actions"
        fi

        if [ "$gbc_running" = "true" ] && [ "$gbc_connected" = "true" ] && [ "$has_battery_popup" = "false" ]; then
          entries+=("$opt_battery_popup")
        fi

        if [ "$connected" = "true" ] && [ -n "$device_id" ]; then
          entries+=("$opt_codec_menu")
        fi

        entries+=("$opt_open_gui")
        if [ "$gbc_running" = "false" ]; then
          entries+=("$opt_start_tray")
        fi

        chosen=$(printf '%s\n' "''${entries[@]}" | rofi -dmenu -i -p "Galaxy Buds" \
          -theme-str "entry {placeholder:\"''${status_label}\";}window{padding: 32% 36%;}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 22;}") || exit 0

        [ -z "$chosen" ] && exit 0

        case "$chosen" in
          "$opt_connect"|"$opt_connect_switch")
            exec ${scripts.connect-galaxy-buds} connect
            ;;
          "$opt_disconnect")
            exec ${scripts.connect-galaxy-buds} disconnect
            ;;
          "$opt_battery_popup")
            "$gbc" app --show-battery-popup >/dev/null 2>&1 || true
            ;;
          "$opt_codec_menu")
            declare -A profile_map=()
            profile_entries=()
            while IFS=$'\t' read -r pname pdesc; do
              [ -z "$pname" ] && continue
              [ "$pname" = "off" ] && continue
              if [ "$pname" = "$cur_profile" ]; then
                plabel="󰄳  ''${pdesc} (Active)"
              else
                plabel="󰄰  ''${pdesc}"
              fi
              profile_map["$plabel"]="$pname"
              profile_entries+=("$plabel")
            done < <(printf '%s' "$pw_json" | jq -r --argjson id "$device_id" '
              [ .[] | select(.id == $id) ][0].info.params.EnumProfile // []
              | map(select(.available != "no"))
              | sort_by(-(.priority // 0))
              | .[]
              | "\(.name)\t\(.description)"
            ')

            picked_profile=$(printf '%s\n' "''${profile_entries[@]}" | rofi -dmenu -i -p "Audio Codec" \
              -theme-str "entry {placeholder:\"Select profile for ''${dev_name}...\";}window{padding: 34% 34%;}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 22;}") || exit 0
            [ -z "$picked_profile" ] && exit 0
            if [ -n "''${profile_map[$picked_profile]+x}" ]; then
              exec ${scripts.connect-galaxy-buds} profile "''${profile_map[$picked_profile]}"
            fi
            ;;
          "$opt_open_gui")
            if [ "$gbc_running" = "true" ]; then
              "$gbc" app --activate-window >/dev/null 2>&1 || nohup "$gbc" >/dev/null 2>&1 &
            else
              nohup "$gbc" >/dev/null 2>&1 &
            fi
            ;;
          "$opt_start_tray")
            if systemctl --user list-unit-files galaxy-buds-client.service 2>/dev/null | grep -q galaxy-buds-client; then
              systemctl --user start galaxy-buds-client.service
            else
              nohup "$gbc" /StartMinimized >/dev/null 2>&1 &
            fi
            notify low 3500 "GalaxyBudsClient started" "Running minimized in the system tray"
            ;;
          *)
            if [ -n "''${action_map[$chosen]+x}" ]; then
              act_id="''${action_map[$chosen]}"
              if ! output=$("$gbc" action --execute "$act_id" 2>&1); then
                notify normal 5000 "GalaxyBudsClient action failed" "''${output:-$act_id}"
                exit 1
              fi
            fi
            ;;
        esac
      '';
  };
}
