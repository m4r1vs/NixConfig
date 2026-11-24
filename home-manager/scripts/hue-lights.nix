/*
Philips Hue helper CLI for hey-computer (`smart-scene`, `smart-scenes`, `all-off`, `step`).
Covers Hue CLIP v2 smart scenes (all-day / time-based schedules), single-call
all-lights-off, and single-call relative brightness steps that `openhue-cli`
does not provide directly, while reading the bridge API key internally so
credentials never enter the LLM's context.
*/
{
  pkgs,
  helpers,
  ...
}: {
  hue-lights = helpers.mkScript {
    name = "hue-lights";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.jq
      pkgs.openhue-cli
    ];
    text =
      # bash
      ''
        die() {
          printf '%s\n' "$*" >&2
          exit 1
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

        cfg_file=""
        cfg_file=$(find_config)
        [ -n "$cfg_file" ] || die "Hue Bridge is not configured (run openhue setup)."

        bridge=""
        api_key=""
        bridge=$(read_cfg_key "$cfg_file" "bridge")
        api_key=$(read_cfg_key "$cfg_file" "key")
        [ -n "$bridge" ] && [ -n "$api_key" ] || die "Incomplete openhue config at $cfg_file."

        bridge_get() {
          local path="$1"
          curl -fsSk --max-time 5 \
            -H "hue-application-key: ''${api_key}" \
            "https://''${bridge}/clip/v2/resource/''${path}" 2>/dev/null
        }

        bridge_put() {
          local path="$1"
          local body="$2"
          local resp http_code json_body
          resp=$(curl -sk --max-time 5 -w '\n%{http_code}' \
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

        fetch_rooms() {
          timeout 6 openhue get rooms --json 2>/dev/null || die "Could not reach Hue Bridge."
        }

        cmd_smart_scenes() {
          local tmp_dir rooms_file smart_file
          tmp_dir=$(mktemp -d)
          trap 'rm -rf "$tmp_dir"' RETURN
          rooms_file="$tmp_dir/rooms.json"
          smart_file="$tmp_dir/smart.json"
          fetch_rooms > "$rooms_file"
          bridge_get "smart_scene" > "$smart_file" || die "Could not fetch smart scenes from Hue Bridge."
          jq -rn --slurpfile rooms "$rooms_file" --slurpfile smart "$smart_file" '
            (($rooms[0] // []) | map({(.Id): .Name}) | add // {}) as $rmap |
            ($smart[0].data // [])
            | map({
                room: ($rmap[.group.rid // ""] // "Unknown"),
                name: (.metadata.name // "Unnamed"),
                state: (.state | if type == "string" then . elif type == "object" then (.status // "inactive") else "inactive" end)
              })
            | sort_by(.room, .name)
            | .[]
            | "\(.room)\t\(.name)\t[\(.state)]"
          '
        }

        cmd_smart_scene() {
          local room_query="''${1:-}"
          local scene_query="''${2:-}"
          [ -n "$room_query" ] || die "Usage: hue-lights smart-scene <room> [scene-name]"

          local rooms_json room_info room_id room_name
          rooms_json=$(fetch_rooms)
          room_info=$(jq -rc --arg q "$room_query" '
            ($q | ascii_downcase) as $ql |
            [ .[] | select((.Name | ascii_downcase) == $ql) ][0]
            // [ .[] | select((.Name | ascii_downcase) | contains($ql)) ][0]
            // empty
          ' <<<"$rooms_json")
          [ -n "$room_info" ] || die "Room not found: $room_query"

          room_id=$(jq -r '.Id' <<<"$room_info")
          room_name=$(jq -r '.Name' <<<"$room_info")

          local smart_json match smart_id smart_name
          smart_json=$(bridge_get "smart_scene") || die "Could not fetch smart scenes from Hue Bridge."
          match=$(jq -rc --arg rid "$room_id" --arg sq "$scene_query" '
            [ (.data // [])[] | select((.group.rid // "") == $rid) ] as $list |
            if $sq == "" then
              $list[0] // empty
            else
              ($sq | ascii_downcase) as $sql |
              [ $list[] | select(((.metadata.name // "") | ascii_downcase) == $sql) ][0]
              // [ $list[] | select(((.metadata.name // "") | ascii_downcase) | contains($sql)) ][0]
              // empty
            end
          ' <<<"$smart_json")

          if [ -z "$match" ]; then
            if [ -n "$scene_query" ]; then
              die "Smart scene '$scene_query' not found in $room_name."
            fi
            timeout 6 openhue set room "$room_id" --on >/dev/null 2>&1 || die "Failed to turn on $room_name."
            printf 'Turned on %s (no all-day smart scene configured).\n' "$room_name"
            return 0
          fi

          smart_id=$(jq -r '.id' <<<"$match")
          smart_name=$(jq -r '.metadata.name // "All-day scene"' <<<"$match")
          bridge_put "smart_scene/''${smart_id}" '{"recall":{"action":"activate"}}' \
            || die "Failed to activate smart scene '$smart_name' in $room_name."
          printf 'Activated %s in %s.\n' "$smart_name" "$room_name"
        }

        cmd_all_off() {
          local rooms_json turned_off=()
          rooms_json=$(fetch_rooms)
          local rid rname gl_id
          while IFS=$'\t' read -r rid rname gl_id; do
            [ -z "$rid" ] && continue
            if [ -n "$gl_id" ] && bridge_put "grouped_light/''${gl_id}" '{"on":{"on":false}}'; then
              turned_off+=("$rname")
            elif timeout 6 openhue set room "$rid" --off >/dev/null 2>&1; then
              turned_off+=("$rname")
            else
              die "Failed to turn off $rname."
            fi
          done < <(jq -r '.[] | select((.GroupedLight.HueData.on.on // false) == true) | [.Id, .Name, (.GroupedLight.Id // "")] | @tsv' <<<"$rooms_json")

          if [ "''${#turned_off[@]}" -eq 0 ]; then
            printf 'All lights are already off.\n'
          else
            local joined
            joined=$(printf '%s, ' "''${turned_off[@]}")
            printf 'Turned off: %s.\n' "''${joined%, }"
          fi
        }

        parse_delta() {
          local raw="$1"
          raw="''${raw%\%}"
          [[ "$raw" =~ ^[+-]?[0-9]+$ ]] || die "Invalid brightness step: $1 (expected e.g. +20 or -20)"
          printf '%s' "$raw"
        }

        cmd_step_room() {
          local room_query="''${1:-}"
          local raw_delta="''${2:-}"
          [ -n "$room_query" ] && [ -n "$raw_delta" ] || die "Usage: hue-lights step room <room> <+/-delta>"

          local delta
          delta=$(parse_delta "$raw_delta")

          local rooms_json room_info rid rname gl_id is_on cur_bri new_bri
          rooms_json=$(fetch_rooms)
          room_info=$(jq -rc --arg q "$room_query" '
            ($q | ascii_downcase) as $ql |
            [ .[] | select((.Name | ascii_downcase) == $ql) ][0]
            // [ .[] | select((.Name | ascii_downcase) | contains($ql)) ][0]
            // empty
          ' <<<"$rooms_json")
          [ -n "$room_info" ] || die "Room not found: $room_query"

          rid=$(jq -r '.Id' <<<"$room_info")
          rname=$(jq -r '.Name' <<<"$room_info")
          gl_id=$(jq -r '.GroupedLight.Id // ""' <<<"$room_info")
          is_on=$(jq -r '(.GroupedLight.HueData.on.on // false) | tostring' <<<"$room_info")
          cur_bri=$(jq -r '(.GroupedLight.HueData.dimming.brightness // 0) | round' <<<"$room_info")

          if [ "$is_on" != "true" ]; then
            if [ "$delta" -gt 0 ]; then
              new_bri=$delta
            else
              new_bri=1
            fi
          else
            new_bri=$((cur_bri + delta))
          fi
          [ "$new_bri" -gt 100 ] && new_bri=100
          [ "$new_bri" -lt 1 ] && new_bri=1

          if [ -n "$gl_id" ] && bridge_put "grouped_light/''${gl_id}" "{\"on\":{\"on\":true},\"dimming\":{\"brightness\":''${new_bri}}}"; then
            :
          elif timeout 6 openhue set room "$rid" --on --brightness "$new_bri" >/dev/null 2>&1; then
            :
          else
            die "Failed to set brightness for $rname."
          fi

          if [ "$is_on" != "true" ]; then
            printf '%s: off -> %s%%\n' "$rname" "$new_bri"
          else
            printf '%s: %s%% -> %s%%\n' "$rname" "$cur_bri" "$new_bri"
          fi
        }

        cmd_step_light() {
          local room_query="''${1:-}"
          local light_query="''${2:-}"
          local raw_delta="''${3:-}"
          [ -n "$room_query" ] && [ -n "$light_query" ] && [ -n "$raw_delta" ] \
            || die "Usage: hue-lights step light <room> <light> <+/-delta>"

          local delta
          delta=$(parse_delta "$raw_delta")

          local rooms_json light_info rname lid lname is_on cur_bri new_bri
          rooms_json=$(fetch_rooms)
          light_info=$(jq -rc --arg rq "$room_query" --arg lq "$light_query" '
            ($rq | ascii_downcase) as $rql |
            ($lq | ascii_downcase) as $lql |
            (
              [ .[] | select((.Name | ascii_downcase) == $rql) ][0]
              // [ .[] | select((.Name | ascii_downcase) | contains($rql)) ][0]
            ) as $room |
            if $room == null then empty else
              ($room.Devices // [] | map(.Light) | map(select(. != null))) as $lights |
              (
                [ $lights[] | select((.Name | ascii_downcase) == $lql) ][0]
                // [ $lights[] | select((.Name | ascii_downcase) | contains($lql)) ][0]
              ) as $l |
              if $l == null then empty else
                {
                  room: $room.Name,
                  id: $l.Id,
                  name: $l.Name,
                  on: ($l.HueData.on.on // false),
                  brightness: (($l.HueData.dimming.brightness // 0) | round)
                }
              end
            end
          ' <<<"$rooms_json")
          [ -n "$light_info" ] || die "Light '$light_query' not found in room '$room_query'."

          rname=$(jq -r '.room' <<<"$light_info")
          lid=$(jq -r '.id' <<<"$light_info")
          lname=$(jq -r '.name' <<<"$light_info")
          is_on=$(jq -r '.on | tostring' <<<"$light_info")
          cur_bri=$(jq -r '.brightness' <<<"$light_info")

          if [ "$is_on" != "true" ]; then
            if [ "$delta" -gt 0 ]; then
              new_bri=$delta
            else
              new_bri=1
            fi
          else
            new_bri=$((cur_bri + delta))
          fi
          [ "$new_bri" -gt 100 ] && new_bri=100
          [ "$new_bri" -lt 1 ] && new_bri=1

          if bridge_put "light/''${lid}" "{\"on\":{\"on\":true},\"dimming\":{\"brightness\":''${new_bri}}}"; then
            :
          elif timeout 6 openhue set light "$lid" --on --brightness "$new_bri" >/dev/null 2>&1; then
            :
          else
            die "Failed to set brightness for $lname in $rname."
          fi

          if [ "$is_on" != "true" ]; then
            printf '%s / %s: off -> %s%%\n' "$rname" "$lname" "$new_bri"
          else
            printf '%s / %s: %s%% -> %s%%\n' "$rname" "$lname" "$cur_bri" "$new_bri"
          fi
        }

        case "''${1:-}" in
        smart-scenes)
          cmd_smart_scenes
          ;;
        smart-scene)
          shift
          cmd_smart_scene "$@"
          ;;
        all-off)
          cmd_all_off
          ;;
        step)
          case "''${2:-}" in
          room)
            shift 2
            cmd_step_room "$@"
            ;;
          light)
            shift 2
            cmd_step_light "$@"
            ;;
          *)
            die "Usage: hue-lights step {room <room> <+/-delta>|light <room> <light> <+/-delta>}"
            ;;
          esac
          ;;
        *)
          die "Usage: hue-lights {smart-scenes|smart-scene <room> [scene]|all-off|step room <room> <+/-delta>|step light <room> <light> <+/-delta>}"
          ;;
        esac
      '';
  };
}
