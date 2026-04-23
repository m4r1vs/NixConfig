{pkgs, ...}: {
  waybar-gcal =
    pkgs.writeShellScript "waybar-gcal"
    ''
      # Helper function to output JSON
      output_json() {
          local text="$1"
          local tooltip="''${2:-}"
          if [[ -z "$tooltip" ]]; then
              # Fetch tooltip content (7 day agenda) if not provided
              tooltip=$(${pkgs.gcalcli}/bin/gcalcli --nocolor agenda now 7d 2>/dev/null || echo "No agenda available")
          fi
          ${pkgs.jq}/bin/jq -nc --arg text "$text" --arg tooltip "$tooltip" '{"text": $text, "tooltip": $tooltip}'
      }

      # Check if gcalcli is initialized
      if ! ${pkgs.gcalcli}/bin/gcalcli --nocolor list >/dev/null 2>&1; then
          output_json "Run gcalcli init first" ""
          exit 0
      fi

      # Get the next event in TSV format
      # We fetch results without --nostarted to handle "Ongoing"
      # Looking ahead 2 days (172800 seconds)
      event=$(${pkgs.gcalcli}/bin/gcalcli --nocolor agenda "now" "2 days" --tsv 2>/dev/null)

      if [[ -z "$event" ]]; then
          output_json "󰃮"
          exit 0
      fi

      now_ts=$(${pkgs.coreutils}/bin/date +%s)
      tomorrow_date=$(${pkgs.coreutils}/bin/date -d "tomorrow" +%Y-%m-%d)

      # Parse the output
      while IFS= read -r line; do
          # Skip header or empty lines
          [[ -z "$line" ]] && continue
          [[ "$line" == "start_date"* ]] && continue
          [[ "$line" == "Start Date"* ]] && continue

          # Split by tab into fields
          # Fields: start_date, start_time, end_date, end_time, [link], title
          IFS=$'\t' read -r f0 f1 f2 f3 f4 f5 f6 rest <<< "$line"

          if [[ "$f4" == http* ]]; then
              s_date="$f0"; s_time="$f1"; e_date="$f2"; e_time="$f3"; title="$f5"
          else
              s_date="$f0"; s_time="$f1"; e_date="$f2"; e_time="$f3"; title="$f4"
          fi

          # Skip if we don't have enough data
          [[ -z "$s_date" || -z "$title" ]] && continue

          start_ts=$(${pkgs.coreutils}/bin/date -d "$s_date $s_time" +%s)
          # End time might be empty for all-day events, defaulting to end of day
          if [[ -z "$e_time" ]]; then
              end_ts=$(${pkgs.coreutils}/bin/date -d "$s_date 23:59" +%s)
          else
              end_ts=$(${pkgs.coreutils}/bin/date -d "$s_date $e_time" +%s)
          fi

          # Skip events that already ended
          if [[ "$now_ts" -gt "$end_ts" ]]; then
              continue
          fi

          # Found our candidate event
          break
      done <<< "$event"

      if [[ -z "$s_date" || -z "$title" ]]; then
          output_json "󰃮"
          exit 0
      fi

      diff=$((start_ts - now_ts))

      # 1. Ongoing
      if [[ "$now_ts" -ge "$start_ts" && "$now_ts" -lt "$end_ts" ]]; then
          output_json "󰨱 Right now: <i>$title</i>"
          exit 0
      fi

      # 2. More than 2 days away (already filtered by agenda range, but good to double check)
      if [[ "$diff" -gt 172800 ]]; then
          output_json "󰃮"
          exit 0
      fi

      # 3. Tomorrow
      if [[ "$s_date" == "$tomorrow_date" ]]; then
          # Format time if not an all-day event
          if [[ -n "$s_time" ]]; then
              output_json "󰃭 Tomorrow, $s_time: <i>$title</i>"
          else
              output_json "󰃭 Tomorrow: <i>$title</i>"
          fi
          exit 0
      fi

      # 4. Today, in 5 hours or less
      if [[ "$diff" -gt 0 && "$diff" -le 18000 ]]; then
          # Use awk for one decimal place
          hours=$(${pkgs.gawk}/bin/awk -v d="$diff" 'BEGIN { printf "%.1f", d / 3600 }')
          output_json "󰨱 In $hours hours: <i>$title</i>"
          exit 0
      fi

      # 5. Fallback (Today, more than 5 hours away)
      if [[ "$diff" -gt 0 ]]; then
          if [[ -n "$s_time" ]]; then
              output_json "󰃭 Today, $s_time: <i>$title</i>"
          else
              output_json "󰃭 Today: <i>$title</i>"
          fi
          exit 0
      fi

      output_json "No upcoming events"
    '';
}
