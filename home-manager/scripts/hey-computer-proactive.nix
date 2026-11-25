# Shell-gated proactive automation for hey-computer (#26):
# - `location`: classifies current environment as `work`, `home`, or `other`
#   using connected monitor descriptions/models (`hyprctl monitors -j`) and
#   optional user-local `~/.config/hey-computer/locations.json` rules (IP prefix,
#   default gateway, monitor substrings, or per-location `{city,latitude,longitude}`
#   overrides — keeping private IPs and network names out of git).
# - `weather [location]`: fetches today's Open-Meteo daily forecast using VPN-safe
#   coordinates, persists 14 days atomically in `weather-history.json`, and emits
#   a deterministic day-over-day delta (`changed`, `unchanged`, or `unavailable`).
# - `collect-morning-digest`: fast 0-token pre-collector for hey-computer's native
#   `[scheduler.jobs.morning-digest]` cron (`*/5 5-14 * * *`). Queries
#   `hey-computer schedule show morning-digest --json` (`last_run_at`,
#   `last_status`): exits 0 with empty stdout when today already succeeded/suppressed,
#   when within a 15-minute failure retry cooldown, or while locked/offline
#   (bypassed when `HEY_COMPUTER_SCHEDULE_MANUAL=1`); otherwise prints `date`,
#   `location`, and the deterministic `weather_*` block so the scheduler wakes
#   the agent.
# - `collect-pre-daily`: fast 0-token pre-collector for `[scheduler.jobs.pre-daily]`
#   (`weekdays 09:56`). Exits 0 with empty stdout while locked/offline or away from
#   work/home (bypassed when `HEY_COMPUTER_SCHEDULE_MANUAL=1`); otherwise prints
#   `date` + `location`.
# - `morning-digest` / `pre-daily`: manual CLI runners retained for ad-hoc testing.
{
  pkgs,
  lib,
  config,
  systemArgs,
  helpers,
  ...
}: let
  hmCfg = config.home-manager.users.${systemArgs.username};
  heyComputer = lib.getExe hmCfg.programs.hey-computer.package;
  defaultCity = hmCfg.programs.configured.waybar.weatherLocation or "Hamburg";
  defaultLat = toString (hmCfg.services.configured.darkman.latitude or 53.54);
  defaultLon = toString (hmCfg.services.configured.darkman.longitude or 9.98);
  personalGoogleEmail =
    if systemArgs.useWorkProfileByDefault
    then "marius.niveri@gmail.com"
    else systemArgs.git.email;
  morningDigestPromptFile = pkgs.writeText "morning-digest-prompt.txt" ''
    Prepare today's Morning Brief using the `date`, `location`, and `weather_*` fields in `<untrusted_collector_output>`.

    Gather context:
    - Today's Google Calendar events (24-hour times).
    - Important unread personal Gmail messages (${personalGoogleEmail}) since last evening${lib.optionalString systemArgs.useWorkProfileByDefault ", recent non-noise forwarded work emails in Slack DM D0BKG91AAAJ (never Gmail for ${systemArgs.git.email})"}, and any urgent Slack or Linear mentions if available.
    - Any overdue or due-today personal Google Tasks (${personalGoogleEmail}) and open items in today's `Journal/<date>.md` if it already exists.

    If nothing at all is on today's calendar and there are no notable messages, mentions, or due tasks, reply with exactly `HEARTBEAT_OK` and do not modify the daily note.

    Otherwise, write and reply with the full editorial Markdown brief directly (never a 2-sentence summary):
    1. Start with `# Morning Brief — <Weekday>, <D Month>` (e.g. `# Morning Brief — Wednesday, 25 November`).
    2. Immediately below the H1, write a single plain-prose opening paragraph of 3–4 sentences (~50–80 words) beginning with a normal capitalized letter — never a bullet list, blockquote, emoji, quotation mark, bold/italic marker, or code span first (this paragraph renders with a Reforma 1969 editorial drop cap).
    3. Opening cadence: warm, observant, lightly poetic editorial prose that notices the real shape and rhythm of the day ahead (open stretches, meeting clusters, transitions). No exclamation marks, and never use clichés such as "tapestry", "symphony", "whispers", "gentle reminder", or "embrace the day".
    4. Weather rule (strict): ONLY if `weather_status: changed` in `<untrusted_collector_output>`, weave `weather_today` and the concrete shift from `weather_delta` naturally into the opening paragraph. If `weather_status` is `unchanged`, `unavailable`, or absent, omit weather completely and silently — do not mention forecasts, temperatures, sky conditions, or that weather is unchanged.
    5. Below the opening paragraph, include crisp, scannable `##` sections (`## Schedule`, `## Mail & Messages`, `## Tasks & Focus` as applicable) with 24-hour `HH:MM` times, concrete senders, and concise items. Omit any empty section.
    6. Widget restraint: call `show_widget` (`calendar_agenda`) at most once, and only when today has 3 or more timed events or a scheduling conflict.
    7. Idempotent daily-note sync: update today's `Journal/<date>.md` in the Obsidian vault. Create the file cleanly if needed, or if a `## Morning Brief` section already exists, replace it in place (up to the next `## ` heading or EOF) without duplicating on re-runs and without disturbing frontmatter, existing `- [ ]` tasks, or other notes. Inside `Journal/<date>.md`, nest the brief under `## Morning Brief` using `###` subheadings.
  '';
in {
  hey-computer-proactive = helpers.mkScript {
    name = "hey-computer-proactive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.dbus
      pkgs.gnugrep
      pkgs.hyprland
      pkgs.iproute2
      pkgs.jq
      pkgs.libnotify
      pkgs.procps
    ];
    text =
      # bash
      ''
        STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/hey-computer/proactive"
        CONFIG_FILE="''${XDG_CONFIG_HOME:-$HOME/.config}/hey-computer/locations.json"
        FAIL_LOG="$STATE_DIR/failures.log"
        WEATHER_HISTORY="$STATE_DIR/weather-history.json"
        WEATHER_GEOCACHE="$STATE_DIR/weather-geocache.json"
        DEFAULT_WEATHER_CITY=${lib.escapeShellArg defaultCity}
        DEFAULT_WEATHER_LAT=${lib.escapeShellArg defaultLat}
        DEFAULT_WEATHER_LON=${lib.escapeShellArg defaultLon}
        ALERT_COOLDOWN_SECS=14400 # 4 hours

        install -d -m 700 "$STATE_DIR"

        write_json_atomic() {
          local target="$1"
          local content="$2"
          local tmp
          tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX") || return 1
          chmod 600 "$tmp"
          if printf '%s\n' "$content" > "$tmp" && mv -f "$tmp" "$target"; then
            return 0
          fi
          rm -f "$tmp"
          return 1
        }

        log_failure() {
          local check="$1"
          local msg="$2"
          local ts
          ts=$(date -Iseconds)
          printf '%s [%s] %s\n' "$ts" "$check" "$msg" >> "$FAIL_LOG"

          local stamp="$STATE_DIR/last-alert-$check"
          local now last=0
          now=$(date +%s)
          if [ -f "$stamp" ]; then
            last=$(cat "$stamp" 2>/dev/null || printf '0')
          fi
          if [ $((now - last)) -ge "$ALERT_COOLDOWN_SECS" ]; then
            printf '%s\n' "$now" > "$stamp"
            notify-send --app-name=hey-computer --urgency=normal \
              "Proactive check failed ($check)" "$msg" >/dev/null 2>&1 || true
          fi
        }

        session_unlocked() {
          if pgrep -x hyprlock >/dev/null 2>&1; then
            return 1
          fi
          dbus-send --print-reply --dest=org.freedesktop.secrets \
            /org/freedesktop/secrets/aliases/default \
            org.freedesktop.DBus.Properties.Get \
            string:org.freedesktop.Secret.Collection \
            string:Locked 2>/dev/null | grep -q "boolean false"
        }

        use_live_hyprland_instance() {
          local instances sig
          instances=$(hyprctl instances -j 2>/dev/null) || return 0
          sig=$(jq -r --arg sig "''${HYPRLAND_INSTANCE_SIGNATURE:-}" --arg wl "''${WAYLAND_DISPLAY:-}" \
            '(map(select(.instance == $sig)) + map(select(.wl_socket == $wl)) + .)[0].instance // empty' <<<"$instances" 2>/dev/null || true)
          if [ -n "$sig" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          fi
        }

        network_online() {
          ip -4 route show default 2>/dev/null | grep -q '^default ' \
            || ip -6 route show default 2>/dev/null | grep -q '^default '
        }

        daemon_ready() {
          local status_json agent
          status_json=$(${heyComputer} status --json 2>/dev/null) || return 1
          agent=$(jq -r '.agent // "down"' <<<"$status_json" 2>/dev/null || printf 'down')
          [ "$agent" != "down" ]
        }

        classify_location() {
          use_live_hyprland_instance
          local monitors_json="" ips="" gateways="" rules_json='{"work":{"monitors":["LS27D70xE","HK2YA02261"]},"home":{"monitors":["27GL850","912NTVSCD959"]}}'
          monitors_json=$(hyprctl monitors -j 2>/dev/null || printf '[]')
          ips=$(ip -4 -o addr show scope global 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))' || printf '[]')
          gateways=$(ip -4 route show default 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))' || printf '[]')

          if [ -f "$CONFIG_FILE" ]; then
            rules_json=$(jq -c --argjson base "$rules_json" '$base * .' "$CONFIG_FILE" 2>/dev/null || printf '%s' "$rules_json")
          fi

          jq -rn \
            --argjson rules "$rules_json" \
            --argjson monitors "$monitors_json" \
            --argjson ips "$ips" \
            --argjson gateways "$gateways" '
            def any_match($haystacks; $needles):
              ($needles // []) as $ns |
              if ($ns | length) == 0 then false
              else any($haystacks[]; . as $h | any($ns[]; . as $n | ($n | length) > 0 and ($h | ascii_downcase | contains($n | ascii_downcase))))
              end;
            ($monitors | map([.name, .description, .make, .model, .serial] | map(select(. != null)) | join(" "))) as $mon_strs |
            if (any_match($ips; $rules.work.ip_prefixes) or any_match($gateways; $rules.work.gateways) or any_match($mon_strs; $rules.work.monitors)) then
              "work"
            elif (any_match($ips; $rules.home.ip_prefixes) or any_match($gateways; $rules.home.gateways) or any_match($mon_strs; $rules.home.monitors)) then
              "home"
            else
              "other"
            end
          ' 2>/dev/null || printf 'other\n'
        }

        run_and_wait_task() {
          local check="$1"
          local stamp="$2"
          local today="$3"
          local prompt="$4"
          local task_id task_json status err_msg deadline

          if ! task_id=$(${heyComputer} ask --background --profile deep --suppress-token HEARTBEAT_OK "$prompt" 2>/dev/null) \
            || ! [[ "$task_id" =~ ^[0-9]+$ ]]; then
            log_failure "$check" "failed to submit $check task to hey-computer."
            return 1
          fi

          # Wait up to 20 minutes for the queued/running background task to
          # reach a terminal status so `.last` is only stamped on real success
          # and execution errors (such as LimitReached) land in failures.log.
          deadline=$(( $(date +%s) + 1200 ))
          while [ "$(date +%s)" -lt "$deadline" ]; do
            sleep 2
            if ! task_json=$(${heyComputer} tasks show "$task_id" --json 2>/dev/null); then
              continue
            fi
            status=$(jq -r '.status // ""' <<<"$task_json" 2>/dev/null || true)
            case "$status" in
            completed|suppressed)
              printf '%s\n' "$today" > "$stamp"
              return 0
              ;;
            failed|cancelled)
              err_msg=$(jq -r '.error_message // .fail_reason // "task failed"' <<<"$task_json" 2>/dev/null || printf 'task failed')
              log_failure "$check" "task #$task_id $status: $err_msg"
              return 1
              ;;
            esac
          done

          log_failure "$check" "timed out waiting for background task #$task_id"
          return 1
        }

        resolve_weather_coords() {
          local loc="$1"
          local city="$DEFAULT_WEATHER_CITY"
          local lat="$DEFAULT_WEATHER_LAT"
          local lon="$DEFAULT_WEATHER_LON"
          local cfg_city="" cfg_lat="" cfg_lon=""

          if [ -f "$CONFIG_FILE" ]; then
            local cfg_lines=()
            mapfile -t cfg_lines < <(
              jq -r --arg loc "$loc" '
                (.[$loc] // {}) as $e |
                (if ($e.city | type) == "string" then $e.city else "" end),
                (if ($e.latitude | type) == "number" then ($e.latitude | tostring) else "" end),
                (if ($e.longitude | type) == "number" then ($e.longitude | tostring) else "" end)
              ' "$CONFIG_FILE" 2>/dev/null || true
            )
            cfg_city="''${cfg_lines[0]:-}"
            cfg_lat="''${cfg_lines[1]:-}"
            cfg_lon="''${cfg_lines[2]:-}"
          fi

          if [ -n "$cfg_lat" ] && [ -n "$cfg_lon" ]; then
            lat="$cfg_lat"
            lon="$cfg_lon"
            if [ -n "$cfg_city" ]; then
              city="$cfg_city"
            fi
          elif [ -n "$cfg_city" ]; then
            if [ "''${cfg_city,,}" = "''${DEFAULT_WEATHER_CITY,,}" ]; then
              city="$cfg_city"
            else
              local city_key="''${cfg_city,,}"
              local cached=()
              if [ -f "$WEATHER_GEOCACHE" ]; then
                mapfile -t cached < <(
                  jq -r --arg k "$city_key" '
                    .[$k] | select(type == "object" and (.lat | type) == "number" and (.lon | type) == "number") |
                    (.lat | tostring), (.lon | tostring)
                  ' "$WEATHER_GEOCACHE" 2>/dev/null || true
                )
              fi
              if [ -n "''${cached[0]:-}" ] && [ -n "''${cached[1]:-}" ]; then
                city="$cfg_city"
                lat="''${cached[0]}"
                lon="''${cached[1]}"
              else
                local geo_resp="" geo_lines=()
                if geo_resp=$(curl -fsSL --connect-timeout 3 --max-time 5 --get \
                  --data-urlencode "name=$cfg_city" \
                  --data-urlencode "count=1" \
                  --data-urlencode "language=en" \
                  --data-urlencode "format=json" \
                  "https://geocoding-api.open-meteo.com/v1/search" 2>/dev/null); then
                  mapfile -t geo_lines < <(
                    jq -r '
                      (.results[0] // empty) |
                      select((.latitude | type) == "number" and (.longitude | type) == "number") |
                      (.latitude | tostring), (.longitude | tostring)
                    ' <<<"$geo_resp" 2>/dev/null || true
                  )
                fi
                if [ -n "''${geo_lines[0]:-}" ] && [ -n "''${geo_lines[1]:-}" ]; then
                  city="$cfg_city"
                  lat="''${geo_lines[0]}"
                  lon="''${geo_lines[1]}"
                  local existing_cache="{}" updated_cache=""
                  if [ -f "$WEATHER_GEOCACHE" ]; then
                    existing_cache=$(jq -c 'if type == "object" then . else {} end' "$WEATHER_GEOCACHE" 2>/dev/null || printf '{}')
                  fi
                  if updated_cache=$(jq -c --arg k "$city_key" --arg city "$city" --argjson lat "$lat" --argjson lon "$lon" \
                    '. + {($k): {city: $city, lat: $lat, lon: $lon}}' <<<"$existing_cache" 2>/dev/null); then
                    write_json_atomic "$WEATHER_GEOCACHE" "$updated_cache" || true
                  fi
                fi
              fi
            fi
          fi

          jq -cn --arg city "$city" --argjson lat "$lat" --argjson lon "$lon" \
            '{city: $city, lat: $lat, lon: $lon}'
        }

        fetch_weather_snapshot() {
          local today="$1"
          local coords_json="$2"
          local city lat lon api_json
          city=$(jq -r '.city' <<<"$coords_json")
          lat=$(jq -r '.lat' <<<"$coords_json")
          lon=$(jq -r '.lon' <<<"$coords_json")

          api_json=$(curl -fsSL --connect-timeout 3 --max-time 5 --get \
            --data-urlencode "latitude=$lat" \
            --data-urlencode "longitude=$lon" \
            --data-urlencode "daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,precipitation_probability_max,wind_gusts_10m_max,sunrise,sunset" \
            --data-urlencode "timezone=auto" \
            --data-urlencode "forecast_days=1" \
            "https://api.open-meteo.com/v1/forecast" 2>/dev/null) || return 1

          jq -c --arg today "$today" --arg city "$city" --argjson lat "$lat" --argjson lon "$lon" '
            def wmo_bucket($c):
              if ($c == 0 or $c == 1) then "clear"
              elif $c == 2 then "partly_cloudy"
              elif $c == 3 then "overcast"
              elif ($c == 45 or $c == 48) then "fog"
              elif ($c == 51 or $c == 53 or $c == 55) then "drizzle"
              elif ($c == 56 or $c == 57 or $c == 66 or $c == 67) then "freezing_rain"
              elif ($c == 61 or $c == 63 or $c == 80 or $c == 81) then "rain"
              elif ($c == 65 or $c == 82) then "heavy_rain"
              elif ($c == 71 or $c == 73 or $c == 75 or $c == 77 or $c == 85 or $c == 86) then "snow"
              elif ($c == 95 or $c == 96 or $c == 99) then "thunderstorm"
              else "unknown"
              end;
            def wmo_label($c):
              if $c == 0 then "clear sky"
              elif $c == 1 then "mainly clear"
              elif $c == 2 then "partly cloudy"
              elif $c == 3 then "overcast"
              elif $c == 45 then "fog"
              elif $c == 48 then "rime fog"
              elif $c == 51 then "light drizzle"
              elif $c == 53 then "drizzle"
              elif $c == 55 then "dense drizzle"
              elif ($c == 56 or $c == 57) then "freezing drizzle"
              elif $c == 61 then "light rain"
              elif $c == 63 then "rain"
              elif $c == 65 then "heavy rain"
              elif ($c == 66 or $c == 67) then "freezing rain"
              elif $c == 71 then "light snow"
              elif $c == 73 then "snow"
              elif $c == 75 then "heavy snow"
              elif $c == 77 then "snow grains"
              elif $c == 80 then "light showers"
              elif $c == 81 then "rain showers"
              elif $c == 82 then "heavy showers"
              elif $c == 85 then "snow showers"
              elif $c == 86 then "heavy snow showers"
              elif $c == 95 then "thunderstorm"
              elif ($c == 96 or $c == 99) then "thunderstorm with hail"
              else "mixed conditions"
              end;
            .daily as $d |
            select(
              ($d | type) == "object"
              and (($d.weather_code[0] // null) | type) == "number"
              and (($d.temperature_2m_max[0] // null) | type) == "number"
              and (($d.temperature_2m_min[0] // null) | type) == "number"
            ) |
            ($d.weather_code[0] | floor) as $code |
            {
              date: $today,
              city: $city,
              lat: $lat,
              lon: $lon,
              weather_code: $code,
              condition: wmo_bucket($code),
              condition_label: wmo_label($code),
              temp_max: $d.temperature_2m_max[0],
              temp_min: $d.temperature_2m_min[0],
              feels_max: ($d.apparent_temperature_max[0] // $d.temperature_2m_max[0]),
              feels_min: ($d.apparent_temperature_min[0] // $d.temperature_2m_min[0]),
              precip_mm: ($d.precipitation_sum[0] // 0),
              precip_prob_pct: ($d.precipitation_probability_max[0] // 0),
              wind_gust_kmh: ($d.wind_gusts_10m_max[0] // 0),
              sunrise: (($d.sunrise[0] // "") | split("T")[1] // .),
              sunset: (($d.sunset[0] // "") | split("T")[1] // .)
            }
          ' <<<"$api_json" 2>/dev/null
        }

        evaluate_weather_delta() {
          local history_json="$1"
          local today="$2"
          local yesterday="$3"

          jq -r --arg today "$today" --arg yesterday "$yesterday" '
            def wmo_bucket($c):
              if ($c == 0 or $c == 1) then "clear"
              elif $c == 2 then "partly_cloudy"
              elif $c == 3 then "overcast"
              elif ($c == 45 or $c == 48) then "fog"
              elif ($c == 51 or $c == 53 or $c == 55) then "drizzle"
              elif ($c == 56 or $c == 57 or $c == 66 or $c == 67) then "freezing_rain"
              elif ($c == 61 or $c == 63 or $c == 80 or $c == 81) then "rain"
              elif ($c == 65 or $c == 82) then "heavy_rain"
              elif ($c == 71 or $c == 73 or $c == 75 or $c == 77 or $c == 85 or $c == 86) then "snow"
              elif ($c == 95 or $c == 96 or $c == 99) then "thunderstorm"
              else "unknown"
              end;
            def round1: ((. * 10) | round) / 10;
            def round2: ((. * 100) | round) / 100;
            def signed1: round1 | if . > 0 then "+\(.)" else "\(.)" end;
            def fmt_day($s):
              ($s.condition_label // (wmo_bucket($s.weather_code // -1) | gsub("_"; " "))) as $cond |
              "\($cond), \($s.temp_min | round1)..\($s.temp_max | round1)°C (feels \($s.feels_min | round1)..\($s.feels_max | round1)°C), precip \($s.precip_mm | round1) mm (\($s.precip_prob_pct | round)%), gusts \($s.wind_gust_kmh | round1) km/h"
              + (if (($s.sunrise // "") != "" and ($s.sunset // "") != "") then ", sun \($s.sunrise)–\($s.sunset)" else "" end);

            (.[$today] // null) as $t |
            (.[$yesterday] // null) as $y |

            if $t == null then
              "weather_status: unavailable\nweather_instruction: Weather data is unavailable — OMIT weather completely (do not mention forecasts, temperatures, sky conditions, or that weather is unavailable)."
            elif $y == null then
              "weather_status: changed\n"
              + "weather_city: \($t.city // "unknown")\n"
              + "weather_today: \(fmt_day($t))\n"
              + "weather_yesterday: none (no prior day recorded)\n"
              + "weather_delta: no baseline recorded for yesterday"
            else
              (wmo_bucket($t.weather_code // -1)) as $tb |
              (wmo_bucket($y.weather_code // -1)) as $yb |
              (($t.lat - $y.lat) | round2 | fabs) as $lat_d |
              (($t.lon - $y.lon) | round2 | fabs) as $lon_d |
              ((($t.city // "") | ascii_downcase) != (($y.city // "") | ascii_downcase)) as $city_changed |
              (($t.precip_mm >= 1.0) or ($t.precip_prob_pct >= 40)) as $t_wet |
              (($y.precip_mm >= 1.0) or ($y.precip_prob_pct >= 40)) as $y_wet |
              (($t.precip_mm - $y.precip_mm) | round2) as $precip_d |
              (($t.precip_prob_pct - $y.precip_prob_pct) | round2) as $prob_d |
              (($t_wet != $y_wet) and ((($precip_d | fabs) >= 1.0) or (($prob_d | fabs) >= 20))) as $wet_flip |
              (($precip_d | fabs) >= 4.0) as $precip_jump |
              (($t.temp_max - $y.temp_max) | round2) as $tmax_d |
              (($t.temp_min - $y.temp_min) | round2) as $tmin_d |
              (($t.feels_max - $y.feels_max) | round2) as $fmax_d |
              (($t.temp_min <= 0.0) != ($y.temp_min <= 0.0)) as $freeze_min |
              (($t.temp_max <= 0.0) != ($y.temp_max <= 0.0)) as $freeze_max |
              (($t.wind_gust_kmh - $y.wind_gust_kmh) | round2) as $gust_d |
              (($t.wind_gust_kmh >= 65.0) != ($y.wind_gust_kmh >= 65.0)) as $crossed_65 |
              ((($t.wind_gust_kmh >= 45.0) != ($y.wind_gust_kmh >= 45.0)) and (($gust_d | fabs) >= 10.0)) as $crossed_45 |

              [
                (if $city_changed then
                  "location changed (\($y.city) -> \($t.city))"
                elif ($lat_d >= 0.25 or $lon_d >= 0.25) then
                  "coordinates shifted (\($y.lat),\($y.lon) -> \($t.lat),\($t.lon))"
                else empty end),

                (if $tb != $yb then
                  "conditions shifted (\($yb | gsub("_"; " ")) -> \($tb | gsub("_"; " ")))"
                else empty end),

                (if $wet_flip then
                  if $t_wet then
                    "turning wet (\($t.precip_mm | round1) mm, \($t.precip_prob_pct | round)% vs \($y.precip_mm | round1) mm, \($y.precip_prob_pct | round)%)"
                  else
                    "drying out (\($t.precip_mm | round1) mm, \($t.precip_prob_pct | round)% vs \($y.precip_mm | round1) mm, \($y.precip_prob_pct | round)%)"
                  end
                elif $precip_jump then
                  "precipitation \($precip_d | signed1) mm (\($y.precip_mm | round1) -> \($t.precip_mm | round1) mm)"
                else empty end),

                (if ($tmax_d | fabs) >= 3.0 then
                  "high \($tmax_d | signed1)°C (\($y.temp_max | round1)°C -> \($t.temp_max | round1)°C)"
                else empty end),

                (if ($tmin_d | fabs) >= 3.0 then
                  "low \($tmin_d | signed1)°C (\($y.temp_min | round1)°C -> \($t.temp_min | round1)°C)"
                else empty end),

                (if ($fmax_d | fabs) >= 4.0 then
                  "feels-like high \($fmax_d | signed1)°C (\($y.feels_max | round1)°C -> \($t.feels_max | round1)°C)"
                else empty end),

                (if $freeze_min then
                  if $t.temp_min <= 0.0 then
                    "overnight low dropping to/below freezing (\($y.temp_min | round1)°C -> \($t.temp_min | round1)°C)"
                  else
                    "overnight low rising above freezing (\($y.temp_min | round1)°C -> \($t.temp_min | round1)°C)"
                  end
                else empty end),

                (if $freeze_max then
                  if $t.temp_max <= 0.0 then
                    "daytime high dropping to/below freezing (\($y.temp_max | round1)°C -> \($t.temp_max | round1)°C)"
                  else
                    "daytime high rising above freezing (\($y.temp_max | round1)°C -> \($t.temp_max | round1)°C)"
                  end
                else empty end),

                (if $crossed_65 then
                  "gale-force gusts \(if $t.wind_gust_kmh >= 65.0 then "arriving" else "easing" end) (\($y.wind_gust_kmh | round1) -> \($t.wind_gust_kmh | round1) km/h)"
                elif $crossed_45 then
                  "strong wind gusts \(if $t.wind_gust_kmh >= 45.0 then "picking up" else "calming" end) (\($y.wind_gust_kmh | round1) -> \($t.wind_gust_kmh | round1) km/h)"
                else empty end)
              ] as $reasons |

              if ($reasons | length) > 0 then
                "weather_status: changed\n"
                + "weather_city: \($t.city // "unknown")\n"
                + "weather_today: \(fmt_day($t))\n"
                + "weather_yesterday: \(fmt_day($y))\n"
                + "weather_delta: \($reasons | join("; "))"
              else
                "weather_status: unchanged\n"
                + "weather_instruction: Weather is unchanged from yesterday — OMIT weather completely (do not mention forecasts, temperatures, sky conditions, or that weather is unchanged)."
              end
            end
          ' <<<"$history_json"
        }

        collect_weather_delta() {
          local loc="$1"
          local today="$2"
          local yesterday history_json coords_json today_snap updated_history

          yesterday=$(date -d "$today - 1 day" +%Y-%m-%d)
          history_json="{}"
          if [ -f "$WEATHER_HISTORY" ]; then
            history_json=$(jq -c 'if type == "object" then . else {} end' "$WEATHER_HISTORY" 2>/dev/null || printf '{}')
          fi

          coords_json=$(resolve_weather_coords "$loc")
          today_snap=""
          if today_snap=$(fetch_weather_snapshot "$today" "$coords_json") && [ -n "$today_snap" ]; then
            if updated_history=$(jq -c --arg today "$today" --argjson snap "$today_snap" '
              (. + {($today): $snap})
              | to_entries
              | map(select(.key | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")))
              | sort_by(.key)
              | .[-14:]
              | from_entries
            ' <<<"$history_json" 2>/dev/null) && [ -n "$updated_history" ]; then
              history_json="$updated_history"
              write_json_atomic "$WEATHER_HISTORY" "$history_json" || true
            fi
          fi

          evaluate_weather_delta "$history_json" "$today" "$yesterday"
        }

        run_morning_digest() {
          local today stamp loc weather_block base_prompt prompt manual
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/morning-digest.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            # Already ran today: silent 0-token no-op.
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            # Wait quietly until the user unlocks the desktop and network is up.
            session_unlocked || exit 0
            network_online || exit 0
          fi

          if ! daemon_ready; then
            log_failure "morning-digest" "hey-computer daemon is not ready; will retry on next tick."
            exit 1
          fi

          loc=$(classify_location)
          weather_block=$(collect_weather_delta "$loc" "$today")
          base_prompt=$(cat ${morningDigestPromptFile})
          printf -v prompt '%s\n\n<untrusted_collector_output>\ndate: %s\nlocation: %s\n%s\n</untrusted_collector_output>' \
            "$base_prompt" "$today" "$loc" "$weather_block"

          run_and_wait_task "morning-digest" "$stamp" "$today" "$prompt" || exit 1
        }

        run_pre_daily() {
          local today stamp loc prompt
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/pre-daily.last"

          if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
            exit 0
          fi

          session_unlocked || exit 0
          network_online || exit 0

          loc=$(classify_location)
          # If the user configured location rules and is neither at work nor home, skip quietly.
          if [ -f "$CONFIG_FILE" ] && [ "$loc" = "other" ]; then
            exit 0
          fi

          if ! daemon_ready; then
            log_failure "pre-daily" "hey-computer daemon is not ready before the 10:00 daily."
            exit 1
          fi

          prompt="Pre-daily standup brief (10:00 daily, $today, location: $loc). First check today's Google Calendar: if I am out of office / on vacation or there is no 10:00 daily today, reply with exactly HEARTBEAT_OK. Otherwise, summarize in 3-5 concise bullets: (1) my active Linear issues / recent GitLab MR updates from yesterday, (2) any relevant Slack mentions since yesterday afternoon, and (3) what is on today's schedule after the daily."

          run_and_wait_task "pre-daily" "$stamp" "$today" "$prompt" || exit 1
        }

        collect_morning_digest() {
          local today stamp sched_json last_run_at last_status last_date now_ms loc manual
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/morning-digest.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            # Honour legacy stamp file on same-day upgrades.
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            if sched_json=$(${heyComputer} schedule show morning-digest --json 2>/dev/null); then
              last_run_at=$(jq -r '.last_run_at // 0' <<<"$sched_json" 2>/dev/null || printf '0')
              last_status=$(jq -r '.last_status // ""' <<<"$sched_json" 2>/dev/null || true)
              if [[ "$last_run_at" =~ ^[0-9]+$ ]] && [ "$last_run_at" -gt 0 ]; then
                last_date=$(date -d "@$((last_run_at / 1000))" +%Y-%m-%d 2>/dev/null || true)
                if [ "$last_date" = "$today" ] && { [ "$last_status" = "ok" ] || [ "$last_status" = "suppressed" ]; }; then
                  exit 0
                fi
                if [ "$last_status" = "failed" ]; then
                  now_ms=$(( $(date +%s) * 1000 ))
                  if [ $((now_ms - last_run_at)) -lt 900000 ]; then
                    exit 0
                  fi
                fi
              fi
            fi

            session_unlocked || exit 0
            network_online || exit 0
          fi

          loc=$(classify_location)
          printf 'date: %s\nlocation: %s\n' "$today" "$loc"
          collect_weather_delta "$loc" "$today"
        }

        collect_pre_daily() {
          local today stamp loc manual
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/pre-daily.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            session_unlocked || exit 0
            network_online || exit 0
          fi

          loc=$(classify_location)
          if [ "$manual" != "1" ] && [ -f "$CONFIG_FILE" ] && [ "$loc" = "other" ]; then
            exit 0
          fi

          printf 'date: %s\nlocation: %s\n' "$today" "$loc"
        }

        case "''${1-}" in
        location)
          classify_location
          ;;
        weather)
          loc="''${2:-}"
          if [ -z "$loc" ]; then
            loc=$(classify_location)
          fi
          collect_weather_delta "$loc" "$(date +%Y-%m-%d)"
          ;;
        collect-morning-digest)
          collect_morning_digest
          ;;
        collect-pre-daily)
          collect_pre_daily
          ;;
        morning-digest)
          run_morning_digest
          ;;
        pre-daily)
          run_pre_daily
          ;;
        *)
          echo "Usage: hey-computer-proactive <location|weather|collect-morning-digest|collect-pre-daily|morning-digest|pre-daily>" >&2
          exit 2
          ;;
        esac
      '';
  };
}
