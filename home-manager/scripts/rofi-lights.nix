{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  rofi-lights = helpers.mkScript {
    name = "rofi-lights";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.openhue-cli
    ];
    text =
      # bash
      ''
        icon="${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/apps/gammastep.svg"
        state_file="''${XDG_RUNTIME_DIR:-/tmp}/rofi-lights-state.json"

        notify() {
          local urgency="$1"
          local summary="$2"
          local body="$3"
          ${scripts.nixos-notify} -u "$urgency" -e -t 4000 -i "$icon" -h string:synchronous:manage-lights "$summary" "$body"
        }

        rasi_escape() {
          printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
        }

        set_placeholder() {
          printf '\000theme\037entry { placeholder: "%s"; }\n' "$(rasi_escape "$1")"
        }

        # Match openhue/config.go resolution ($XDG_CONFIG_HOME/openhue/config.yaml or ~/.openhue/config.yaml)
        find_config() {
          if [ -n "''${XDG_CONFIG_HOME:-}" ] && [ -f "''${XDG_CONFIG_HOME}/openhue/config.yaml" ]; then
            printf '%s' "''${XDG_CONFIG_HOME}/openhue/config.yaml"
          elif [ -f "''${HOME}/.openhue/config.yaml" ]; then
            printf '%s' "''${HOME}/.openhue/config.yaml"
          elif [ -f "''${HOME}/.config/openhue/config.yaml" ]; then
            printf '%s' "''${HOME}/.config/openhue/config.yaml"
          fi
        }

        read_cfg_key() {
          local file="$1"
          local key="$2"
          awk -F: -v k="$key" '
            tolower($1) ~ "^[[:space:]]*" k "[[:space:]]*$" {
              sub(/^[^:]*:[[:space:]]*/, "")
              gsub(/^["\047]|["\047][[:space:]]*$/, "")
              gsub(/[[:space:]]+$/, "")
              print
              exit
            }
          ' "$file"
        }

        cfg_file=$(find_config)
        bridge=""
        api_key=""
        if [ -n "$cfg_file" ]; then
          bridge=$(read_cfg_key "$cfg_file" "bridge")
          api_key=$(read_cfg_key "$cfg_file" "key")
        fi

        bridge_put() {
          local path="$1"
          local body="$2"
          [ -n "$bridge" ] && [ -n "$api_key" ] || return 1

          local resp http_code json_body
          resp=$(curl -sk --max-time 4 -w '\n%{http_code}' \
            -X PUT \
            -H "hue-application-key: ''${api_key}" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "https://''${bridge}/clip/v2/resource/''${path}" 2>/dev/null) || return 1

          http_code=$(printf '%s\n' "$resp" | tail -n 1)
          json_body=$(printf '%s\n' "$resp" | sed '$d')

          case "$http_code" in
            2??)
              if [ -n "$json_body" ] && printf '%s' "$json_body" | jq -e '(.errors // []) | length > 0' >/dev/null 2>&1; then
                return 1
              fi
              return 0
              ;;
            *)
              return 1
              ;;
          esac
        }

        fetch_state() {
          local tmp_dir rooms_out smart_out pid_rooms pid_smart rc_rooms
          tmp_dir=$(mktemp -d)
          rooms_out="$tmp_dir/rooms.json"
          smart_out="$tmp_dir/smart.json"

          timeout 5 openhue get rooms --json >"$rooms_out" 2>/dev/null &
          pid_rooms=$!

          pid_smart=""
          if [ -n "$bridge" ] && [ -n "$api_key" ]; then
            curl -sk --max-time 4 -H "hue-application-key: ''${api_key}" \
              "https://''${bridge}/clip/v2/resource/smart_scene" >"$smart_out" 2>/dev/null &
            pid_smart=$!
          else
            printf '{"data":[]}\n' >"$smart_out"
          fi

          rc_rooms=0
          wait "$pid_rooms" || rc_rooms=$?
          if [ -n "$pid_smart" ]; then
            wait "$pid_smart" || printf '{"data":[]}\n' >"$smart_out"
          fi

          if [ "$rc_rooms" -ne 0 ] || [ ! -s "$rooms_out" ] || ! jq -e 'type == "array" or type == "object"' "$rooms_out" >/dev/null 2>&1; then
            rm -rf "$tmp_dir"
            return 1
          fi

          if ! jq -e 'type == "object" and (.data | type == "array")' "$smart_out" >/dev/null 2>&1; then
            printf '{"data":[]}\n' >"$smart_out"
          fi

          jq -n \
            --slurpfile rooms_raw "$rooms_out" \
            --slurpfile smart_raw "$smart_out" '
            ($rooms_raw[0] | if type == "array" then . elif type == "object" then [.] else [] end) as $rooms |
            ($smart_raw[0].data // []) as $smart |
            {
              rooms: (
                $rooms
                | map(
                    . as $r |
                    {
                      id: (.Id // ""),
                      name: (.Name // "Unnamed Room"),
                      grouped_light_id: (.GroupedLight.Id // ""),
                      on: ((.GroupedLight.HueData.on.on // false) == true),
                      brightness: ((.GroupedLight.HueData.dimming.brightness // 0) | round),
                      smart_scenes: (
                        $smart
                        | map(select((.group.rid // "") == ($r.Id // "")))
                        | map({
                            id: (.id // ""),
                            name: (.metadata.name // "All-day scene"),
                            active: (
                              (.state | if type == "string" then . elif type == "object" then (.status // "") else "" end)
                              == "active"
                            )
                          })
                        | sort_by(.name | ascii_downcase)
                      ),
                      scenes: (
                        (.Scenes // [])
                        | map({
                            id: (.Id // ""),
                            name: (.Name // "Unnamed Scene"),
                            active: (((.HueData.status.active // "inactive") != "inactive") and ((.HueData.status.active // "") != ""))
                          })
                        | sort_by(.name | ascii_downcase)
                      )
                    }
                  )
                | sort_by(.name | ascii_downcase)
              )
            }
          ' >"''${state_file}.tmp" && mv "''${state_file}.tmp" "$state_file"

          rm -rf "$tmp_dir"
          return 0
        }

        render_setup_menu() {
          printf '\000data\037setup\n'
          printf '\000no-custom\037true\n'
          set_placeholder "Hue Bridge not configured — press Enter to pair"
          printf '󰒓  Pair Philips Hue Bridge (openhue setup)\000info\037setup\n'
        }

        render_unreachable_menu() {
          printf '\000data\037error\n'
          printf '\000no-custom\037true\n'
          set_placeholder "Hue Bridge unreachable''${bridge:+ ($bridge)}"
          printf '󰑐  Retry connecting to Hue Bridge\000info\037retry\n'
          printf '󰒓  Re-run openhue setup\000info\037setup\n'
        }

        render_rooms_menu() {
          printf '\000data\037rooms\n'
          printf '\000no-custom\037true\n'
          printf '\000keep-selection\037false\n'
          set_placeholder "Select a room..."

          local any_on="false"
          local id name is_on bri active_scene
          while IFS=$'\t' read -r id name is_on bri active_scene; do
            [ -z "$id" ] && continue
            if [ "$is_on" = "true" ]; then
              any_on="true"
              if [ -n "$active_scene" ]; then
                printf '󰌵  %s · %s%% · %s\000info\037room:%s\n' "$name" "$bri" "$active_scene" "$id"
              else
                printf '󰌵  %s · %s%%\000info\037room:%s\n' "$name" "$bri" "$id"
              fi
            else
              printf '󰌶  %s · Off\000info\037room:%s\n' "$name" "$id"
            fi
          done < <(jq -r '
            .rooms[]
            | [
                .id,
                .name,
                (.on | tostring),
                (.brightness | tostring),
                (
                  ([.smart_scenes[] | select(.active) | .name][0])
                  // ([.scenes[] | select(.active) | .name][0])
                  // ""
                )
              ]
            | @tsv
          ' "$state_file")

          if [ "$any_on" = "true" ]; then
            printf '󰌶  All Lights Off\000info\037all-off\n'
          fi
        }

        render_room_menu() {
          local room_id="$1"
          local keep_sel="''${2:-false}"

          local room_json
          room_json=$(jq -c --arg id "$room_id" '.rooms[] | select(.id == $id)' "$state_file")
          if [ -z "$room_json" ]; then
            render_rooms_menu
            return
          fi

          local name is_on bri active_scene default_smart
          name=$(printf '%s' "$room_json" | jq -r '.name')
          is_on=$(printf '%s' "$room_json" | jq -r '.on | tostring')
          bri=$(printf '%s' "$room_json" | jq -r '.brightness | tostring')
          active_scene=$(printf '%s' "$room_json" | jq -r '
            ([.smart_scenes[] | select(.active) | .name][0])
            // ([.scenes[] | select(.active) | .name][0])
            // ""
          ')
          default_smart=$(printf '%s' "$room_json" | jq -r '.smart_scenes[0].name // ""')

          printf '\000data\037room:%s\n' "$room_id"
          printf '\000no-custom\037false\n'
          printf '\000keep-selection\037%s\n' "$keep_sel"

          if [ "$is_on" = "true" ]; then
            if [ -n "$active_scene" ]; then
              set_placeholder "''${name} · ''${bri}% · ''${active_scene} — or type %"
            else
              set_placeholder "''${name} · ''${bri}% — or type %"
            fi
            printf '󰌶  Turn lights off\000info\037off:%s\n' "$room_id"
          else
            set_placeholder "''${name} · Off — or type %"
            if [ -n "$default_smart" ]; then
              printf '󰌵  Turn lights on  (%s)\000info\037on:%s\n' "$default_smart" "$room_id"
            else
              printf '󰌵  Turn lights on\000info\037on:%s\n' "$room_id"
            fi
          fi

          # Brightness +/- 10% (keeps Rofi open)
          local next_up next_down up_hint down_hint
          if [ "$is_on" = "true" ]; then
            next_up=$((bri + 10))
            [ "$next_up" -gt 100 ] && next_up=100
            next_down=$((bri - 10))
            [ "$next_down" -lt 1 ] && next_down=1

            if [ "$bri" -ge 100 ]; then
              up_hint="100% max"
            else
              up_hint="''${bri}% → ''${next_up}%"
            fi
            if [ "$bri" -le 1 ]; then
              down_hint="1% min"
            else
              down_hint="''${bri}% → ''${next_down}%"
            fi
          else
            up_hint="Off → 10%"
            down_hint="Off → 1%"
          fi

          printf '󰃠  Brightness +10%%  (%s)\000info\037bri:%s:+10\n' "$up_hint" "$room_id"
          printf '󰃞  Brightness −10%%  (%s)\000info\037bri:%s:-10\n' "$down_hint" "$room_id"

          # All-day smart scenes
          local sid sname sactive
          while IFS=$'\t' read -r sid sname sactive; do
            [ -z "$sid" ] && continue
            if [ "$sactive" = "true" ] && [ "$is_on" = "true" ]; then
              printf '󰖨  %s  (All-day · Active)\000info\037smart:%s:%s\n' "$sname" "$room_id" "$sid"
            else
              printf '󰖨  %s  (All-day)\000info\037smart:%s:%s\n' "$sname" "$room_id" "$sid"
            fi
          done < <(printf '%s' "$room_json" | jq -r '.smart_scenes[] | [.id, .name, (.active | tostring)] | @tsv')

          # Defined Hue scenes for this room
          while IFS=$'\t' read -r sid sname sactive; do
            [ -z "$sid" ] && continue
            if [ "$sactive" = "true" ] && [ "$is_on" = "true" ]; then
              printf '󰏘  %s  (Active)\000info\037scene:%s:%s\n' "$sname" "$room_id" "$sid"
            else
              printf '󰏘  %s\000info\037scene:%s:%s\n' "$sname" "$room_id" "$sid"
            fi
          done < <(printf '%s' "$room_json" | jq -r '.scenes[] | [.id, .name, (.active | tostring)] | @tsv')

          printf '󰌍  Back\000info\037back\n'
        }

        turn_room_off() {
          local room_id="$1"
          local gl_id
          gl_id=$(jq -r --arg id "$room_id" '.rooms[] | select(.id == $id) | .grouped_light_id // ""' "$state_file")
          if [ -n "$gl_id" ] && bridge_put "grouped_light/''${gl_id}" '{"on":{"on":false}}'; then
            return 0
          fi
          timeout 5 openhue set room "$room_id" --off >/dev/null 2>&1
        }

        turn_room_on() {
          local room_id="$1"
          local smart_id gl_id
          smart_id=$(jq -r --arg id "$room_id" '.rooms[] | select(.id == $id) | .smart_scenes[0].id // ""' "$state_file")
          if [ -n "$smart_id" ] && bridge_put "smart_scene/''${smart_id}" '{"recall":{"action":"activate"}}'; then
            return 0
          fi
          gl_id=$(jq -r --arg id "$room_id" '.rooms[] | select(.id == $id) | .grouped_light_id // ""' "$state_file")
          if [ -n "$gl_id" ] && bridge_put "grouped_light/''${gl_id}" '{"on":{"on":true}}'; then
            return 0
          fi
          timeout 5 openhue set room "$room_id" --on >/dev/null 2>&1
        }

        set_room_brightness() {
          local room_id="$1"
          local target_bri="$2"
          local gl_id
          gl_id=$(jq -r --arg id "$room_id" '.rooms[] | select(.id == $id) | .grouped_light_id // ""' "$state_file")

          local ok=false
          if [ -n "$gl_id" ] && bridge_put "grouped_light/''${gl_id}" "{\"on\":{\"on\":true},\"dimming\":{\"brightness\":''${target_bri}}}"; then
            ok=true
          elif timeout 5 openhue set room "$room_id" --on --brightness "$target_bri" >/dev/null 2>&1; then
            ok=true
          fi

          if [ "$ok" = "true" ]; then
            jq --arg id "$room_id" --argjson bri "$target_bri" '
              .rooms |= map(if .id == $id then .on = true | .brightness = $bri else . end)
            ' "$state_file" >"''${state_file}.tmp" && mv "''${state_file}.tmp" "$state_file"
            return 0
          fi
          return 1
        }

        activate_smart_scene() {
          local smart_id="$1"
          bridge_put "smart_scene/''${smart_id}" '{"recall":{"action":"activate"}}'
        }

        activate_scene() {
          local scene_id="$1"
          if bridge_put "scene/''${scene_id}" '{"recall":{"action":"active"}}'; then
            return 0
          fi
          timeout 5 openhue set scene "$scene_id" >/dev/null 2>&1
        }

        retv="''${ROFI_RETV:-0}"
        info="''${ROFI_INFO:-}"
        data="''${ROFI_DATA:-}"

        # Initial invocation
        if [ "$retv" -eq 0 ]; then
          if [ -z "$cfg_file" ]; then
            render_setup_menu
            exit 0
          fi
          if ! fetch_state; then
            notify normal "Manage Lights" "Could not reach Hue Bridge''${bridge:+ at $bridge}"
            render_unreachable_menu
            exit 0
          fi
          render_rooms_menu
          exit 0
        fi

        # Custom input (e.g. typing "45%" inside a room submenu)
        if [ "$retv" -eq 2 ]; then
          if [[ "$data" == room:* ]] && [ -f "$state_file" ]; then
            room_id="''${data#room:}"
            typed="''${1:-}"
            if [[ "$typed" =~ ^[[:space:]]*([0-9]+)%?[[:space:]]*$ ]]; then
              val=$((10#''${BASH_REMATCH[1]}))
              if [ "$val" -eq 0 ]; then
                turn_room_off "$room_id" || notify normal "Manage Lights" "Failed to turn room off"
                exit 0
              fi
              [ "$val" -gt 100 ] && val=100
              if ! set_room_brightness "$room_id" "$val"; then
                notify normal "Manage Lights" "Failed to set brightness to ''${val}%"
              fi
              render_room_menu "$room_id" "false"
              exit 0
            fi
            render_room_menu "$room_id" "false"
            exit 0
          fi
          exit 0
        fi

        # Standard selection (ROFI_RETV == 1)
        case "$info" in
          setup)
            nohup "${pkgs.ghostty}/bin/ghostty" --class=ghostty.openhue --wait-after-command=true -e "${pkgs.openhue-cli}/bin/openhue" setup </dev/null >/dev/null 2>&1 &
            exit 0
            ;;
          retry)
            if ! fetch_state; then
              notify normal "Manage Lights" "Still unable to reach Hue Bridge''${bridge:+ at $bridge}"
              render_unreachable_menu
              exit 0
            fi
            render_rooms_menu
            ;;
          back)
            if [ -f "$state_file" ]; then
              render_rooms_menu
            fi
            ;;
          room:*)
            room_id="''${info#room:}"
            render_room_menu "$room_id" "false"
            ;;
          all-off)
            if [ -f "$state_file" ]; then
              while IFS= read -r rid; do
                [ -z "$rid" ] && continue
                turn_room_off "$rid" || true
              done < <(jq -r '.rooms[] | select(.on) | .id' "$state_file")
            fi
            exit 0
            ;;
          off:*)
            room_id="''${info#off:}"
            turn_room_off "$room_id" || notify normal "Manage Lights" "Failed to turn room off"
            exit 0
            ;;
          on:*)
            room_id="''${info#on:}"
            turn_room_on "$room_id" || notify normal "Manage Lights" "Failed to turn room on"
            exit 0
            ;;
          bri:*)
            rest="''${info#bri:}"
            room_id="''${rest%:*}"
            delta="''${rest##*:}"
            if [ -f "$state_file" ]; then
              is_on=$(jq -r --arg id "$room_id" '.rooms[] | select(.id == $id) | .on | tostring' "$state_file")
              cur_bri=$(jq -r --arg id "$room_id" '.rooms[] | select(.id == $id) | .brightness' "$state_file")
              if [ "$is_on" != "true" ]; then
                if [ "$delta" = "+10" ]; then
                  new_bri=10
                else
                  new_bri=1
                fi
              else
                new_bri=$((cur_bri + delta))
                [ "$new_bri" -gt 100 ] && new_bri=100
                [ "$new_bri" -lt 1 ] && new_bri=1
              fi
              if ! set_room_brightness "$room_id" "$new_bri"; then
                notify normal "Manage Lights" "Failed to adjust brightness"
              fi
              render_room_menu "$room_id" "true"
            fi
            ;;
          smart:*)
            rest="''${info#smart:}"
            smart_id="''${rest#*:}"
            activate_smart_scene "$smart_id" || notify normal "Manage Lights" "Failed to activate all-day scene"
            exit 0
            ;;
          scene:*)
            rest="''${info#scene:}"
            scene_id="''${rest#*:}"
            activate_scene "$scene_id" || notify normal "Manage Lights" "Failed to activate scene"
            exit 0
            ;;
        esac
      '';
  };
}
