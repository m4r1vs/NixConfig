/*
Rofi `-modi` menu for hey-computer scheduled actions (`rofi-launch schedules`,
launched via "Ask Computer Schedules" desktop entry).

Lists declarative schedules (Morning Brief, Pre-Daily Brief, Weekly Distill)
and agent-created schedules/reminders, with in-place controls and direct
inspection in `hey-computer-viewer`.

Keybindings (configured in `rofi-launch.nix`, avoiding `rofi.nix`'s global
`Alt+{h,j,k,l,e,y}` navigation chords):
- `Enter` : open Schedule Inspector + latest output in `hey-computer-viewer`
- `Alt+r` : trigger schedule run now, wake Waybar, refresh in place
- `Alt+p` : pause / resume schedule in place (preserving selection)
- `Alt+x` : remove unmanaged schedule (or toast if managed in NixConfig)
- `Alt+m` : open per-schedule Actions Submenu
*/
{
  pkgs,
  lib,
  config,
  systemArgs,
  scripts,
  helpers,
  ...
}: let
  heyComputer = lib.getExe config.home-manager.users.${systemArgs.username}.programs.hey-computer.package;
in {
  rofi-hey-computer-schedules = helpers.mkScript {
    name = "rofi-hey-computer-schedules";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
      pkgs.procps
      pkgs.systemd
    ];
    text =
      # bash
      ''
        state_file="''${XDG_RUNTIME_DIR:-/tmp}/rofi-hc-schedules-state.json"

        rasi_escape() {
          printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
        }

        set_placeholder() {
          printf '\000theme\037entry { placeholder: "%s"; }\n' "$(rasi_escape "$1")"
        }

        wake_watcher() {
          pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
        }

        notify_low() {
          local summary="$1"
          local body="$2"
          ${scripts.nixos-notify} -u low -e -t 3000 -h string:synchronous:hey-computer-schedules "$summary" "$body" || true
        }

        write_state() {
          local payload="$1"
          local tmp
          tmp=$(mktemp "''${state_file}.XXXXXX")
          chmod 600 "$tmp"
          printf '%s\n' "$payload" >"$tmp"
          mv -f "$tmp" "$state_file"
        }

        fetch_state() {
          local raw=""
          if raw=$(${heyComputer} schedule list --all --json 2>/dev/null) \
            && printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
            write_state "$raw"
            return 0
          fi
          write_state "[]"
          return 1
        }

        schedule_title() {
          local name="$1"
          if [ -f "$state_file" ]; then
            jq -r --arg name "$name" '
              def title_case($s):
                ($s | gsub("[-_]+"; " ") | split(" ")
                 | map(if length > 0 then (.[0:1] | ascii_upcase) + .[1:] else "" end)
                 | join(" "));
              (.[] | select(.name == $name)
               | if (.title // "") != "" then .title
                 elif .name == "morning-digest" then "Morning Brief"
                 elif .name == "pre-daily" then "Pre-Daily Brief"
                 elif .name == "weekly-distill" then "Weekly Distill"
                 else title_case(.name)
                 end)
            ' "$state_file" 2>/dev/null | head -n 1 || printf '%s' "$name"
          else
            printf '%s' "$name"
          fi
        }

        schedule_field() {
          local name="$1"
          local expr="$2"
          if [ -f "$state_file" ]; then
            jq -r --arg name "$name" ".[] | select(.name == \$name) | ($expr)" "$state_file" 2>/dev/null | head -n 1 || true
          fi
        }

        open_viewer_schedule() {
          local name="$1"
          nohup ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect -- \
            ${heyComputer} view --schedule "$name" </dev/null >/dev/null 2>&1 &
        }

        open_viewer_overview() {
          nohup ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect -- \
            ${heyComputer} view --schedules </dev/null >/dev/null 2>&1 &
        }

        open_viewer_turn() {
          local turn_id="$1"
          nohup ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect -- \
            ${heyComputer} view --turn-id "$turn_id" </dev/null >/dev/null 2>&1 &
        }

        run_schedule_now() {
          local name="$1"
          local title
          title=$(schedule_title "$name")
          if ${heyComputer} schedule run "$name" >/dev/null 2>&1; then
            wake_watcher
            notify_low "Ask Computer Schedules" "Triggered: ''${title}"
          else
            notify_low "Ask Computer Schedules" "Could not trigger ''${title} (is daemon running?)"
          fi
        }

        toggle_schedule_enabled() {
          local name="$1"
          local title enabled
          title=$(schedule_title "$name")
          enabled=$(schedule_field "$name" '(.enabled // false) | tostring')
          if [ "$enabled" = "true" ]; then
            if ${heyComputer} schedule pause "$name" >/dev/null 2>&1; then
              wake_watcher
              notify_low "Ask Computer Schedules" "Paused: ''${title}"
            else
              notify_low "Ask Computer Schedules" "Failed to pause ''${title}"
            fi
          else
            if ${heyComputer} schedule resume "$name" >/dev/null 2>&1; then
              wake_watcher
              notify_low "Ask Computer Schedules" "Resumed: ''${title}"
            else
              notify_low "Ask Computer Schedules" "Failed to resume ''${title}"
            fi
          fi
        }

        remove_schedule() {
          local name="$1"
          local title managed
          title=$(schedule_title "$name")
          managed=$(schedule_field "$name" '(.managed // false) | tostring')
          if [ "$managed" = "true" ]; then
            notify_low "Ask Computer Schedules" "Managed in NixConfig — use Alt+p to pause"
            return 1
          fi
          if ${heyComputer} schedule remove "$name" >/dev/null 2>&1; then
            wake_watcher
            notify_low "Ask Computer Schedules" "Removed: ''${title}"
            return 0
          fi
          notify_low "Ask Computer Schedules" "Failed to remove ''${title}"
          return 1
        }

        render_schedules_menu() {
          local keep_sel="''${1:-false}"
          printf '\000data\037list\n'
          printf '\000no-custom\037true\n'
          printf '\000keep-selection\037%s\n' "$keep_sel"

          local count="0"
          if [ -f "$state_file" ]; then
            count=$(jq -r 'length' "$state_file" 2>/dev/null || printf '0')
          fi

          if [ "$count" -gt 0 ]; then
            set_placeholder "Scheduled Actions — Enter inspect · Alt+r run · Alt+p pause · Alt+m menu"
            jq -r '
              def clean($s): ($s // "" | gsub("[[:cntrl:]]+"; " ") | sub("^ +"; "") | sub(" +$"; ""));
              def title_case($s):
                ($s | gsub("[-_]+"; " ") | split(" ")
                 | map(if length > 0 then (.[0:1] | ascii_upcase) + .[1:] else "" end)
                 | join(" "));
              def fmt_epoch($v):
                if $v == null then ""
                else
                  (if $v > 100000000000 then ($v / 1000) else $v end)
                  | floor
                  | strflocaltime("%b %d %H:%M")
                end;

              .[]
              | (.name // "") as $name
              | (
                  if (.title // "") != "" then clean(.title)
                  elif $name == "morning-digest" then "Morning Brief"
                  elif $name == "pre-daily" then "Pre-Daily Brief"
                  elif $name == "weekly-distill" then "Weekly Distill"
                  else title_case($name)
                  end
                ) as $title
              | ((.running // false) == true) as $running
              | (.enabled != false) as $enabled
              | ((.managed // false) == true) as $managed
              | (.consecutive_failures // 0) as $fails
              | (.last_status // "") as $last_st
              | (.mode // "") as $mode
              | clean(.human_schedule // .schedule_spec // "") as $spec
              | (
                  if $running then "󱚣"
                  elif ($fails > 0 or $last_st == "failed") then "󰅚"
                  elif ($enabled | not) then "󰏤"
                  elif $name == "morning-digest" then "󰖨"
                  elif $name == "pre-daily" then "󰃭"
                  elif $name == "weekly-distill" then "󰧑"
                  elif ($mode == "reminder" or .max_runs == 1 or ((.schedule_spec // "") | startswith("in ") or startswith("at "))) then "󰂚"
                  else "󰔟"
                  end
                ) as $icon
              | (
                  if $running then "[running]"
                  elif ($enabled | not) then "[paused]"
                  elif $fails > 0 then "[failing ×\($fails)]"
                  elif $last_st == "failed" then "[failed]"
                  else "[active]"
                  end
                ) as $badge
              | (
                  if ($enabled | not) then ""
                  elif (.next_run_relative // "") != "" then "next: \(clean(.next_run_relative))"
                  elif (.next_run_local // "") != "" then "next: \(clean(.next_run_local))"
                  elif .next_run_at != null then "next: \(fmt_epoch(.next_run_at))"
                  else ""
                  end
                ) as $next_part
              | (
                  if ($last_st | length) > 0 then
                    (
                      if (.last_run_relative // "") != "" then "last: \($last_st) (\(clean(.last_run_relative)))"
                      elif (.last_run_local // "") != "" then "last: \($last_st) (\(clean(.last_run_local)))"
                      else "last: \($last_st)"
                      end
                    )
                  else ""
                  end
                ) as $last_part
              | ([
                  (if ($spec | length) > 0 then $spec else empty end),
                  (if ($next_part | length) > 0 then $next_part else empty end),
                  (if ($last_part | length) > 0 then $last_part else empty end)
                ] | join(" · ")) as $details
              | (if ($details | length) > 0 then "  —  \($details)" else "" end) as $tail
              | clean("\($name) \($title) \(.schedule_spec // "") \($spec) \(if $managed then "managed nixconfig" else "custom agent" end) \($badge) \($last_st) \(.profile // "") \((.prompt // "")[0:120])") as $meta
              | "\($icon)  \($badge) \($title)\($tail)\u0000info\u001fsched:\($name)\u001fmeta\u001f\($meta)"
            ' "$state_file" 2>/dev/null || true
          else
            set_placeholder "No scheduled actions found"
          fi

          printf '󰕮  Open All Schedules Overview in Viewer\000info\037overview\037meta\037all schedules overview viewer\n'
        }

        render_schedule_submenu() {
          local name="$1"
          local title enabled managed latest_turn_id
          title=$(schedule_title "$name")
          enabled=$(schedule_field "$name" '(.enabled // false) | tostring')
          managed=$(schedule_field "$name" '(.managed // false) | tostring')
          latest_turn_id=$(schedule_field "$name" '.latest_turn_id // ""')

          printf '\000data\037sched-menu:%s\n' "$name"
          printf '\000no-custom\037true\n'
          printf '\000keep-selection\037false\n'
          set_placeholder "''${title} (''${name})"

          printf '󰕮  Open in Viewer (details & latest output)\000info\037act-open:%s\n' "$name"
          printf '󰐊  Run now\000info\037act-run:%s\n' "$name"
          if [ "$enabled" = "true" ]; then
            printf '󰏤  Pause schedule\000info\037act-toggle:%s\n' "$name"
          else
            printf '󰐊  Resume schedule\000info\037act-toggle:%s\n' "$name"
          fi
          if [ -n "$latest_turn_id" ] && [ "$latest_turn_id" != "null" ]; then
            printf '󰍡  Open latest turn #%s only\000info\037act-latest:%s\n' "$latest_turn_id" "$latest_turn_id"
          fi
          if [ "$managed" != "true" ]; then
            printf '󰆴  Remove schedule\000info\037act-remove:%s\n' "$name"
          fi
          printf '󰌍  Back\000info\037back\n'
        }

        retv="''${ROFI_RETV:-0}"
        info="''${ROFI_INFO:-}"

        # Initial invocation
        if [ "$retv" -eq 0 ]; then
          fetch_state || true
          render_schedules_menu "false"
          exit 0
        fi

        # Custom keybinds:
        # ROFI_RETV=10 -> kb-custom-1 (Alt+r): Run now and refresh in place
        if [ "$retv" -eq 10 ]; then
          case "$info" in
          sched:*)
            run_schedule_now "''${info#sched:}"
            fetch_state || true
            render_schedules_menu "true"
            exit 0
            ;;
          *)
            render_schedules_menu "true"
            exit 0
            ;;
          esac
        fi

        # ROFI_RETV=11 -> kb-custom-2 (Alt+p): Toggle pause/resume in place
        if [ "$retv" -eq 11 ]; then
          case "$info" in
          sched:*)
            toggle_schedule_enabled "''${info#sched:}"
            fetch_state || true
            render_schedules_menu "true"
            exit 0
            ;;
          *)
            render_schedules_menu "true"
            exit 0
            ;;
          esac
        fi

        # ROFI_RETV=12 -> kb-custom-3 (Alt+x): Remove unmanaged schedule (or toast if managed)
        if [ "$retv" -eq 12 ]; then
          case "$info" in
          sched:*)
            if remove_schedule "''${info#sched:}"; then
              fetch_state || true
              render_schedules_menu "false"
            else
              render_schedules_menu "true"
            fi
            exit 0
            ;;
          *)
            render_schedules_menu "true"
            exit 0
            ;;
          esac
        fi

        # ROFI_RETV=13 -> kb-custom-4 (Alt+m): Open Schedule Submenu
        if [ "$retv" -eq 13 ]; then
          case "$info" in
          sched:*)
            render_schedule_submenu "''${info#sched:}"
            exit 0
            ;;
          *)
            render_schedules_menu "true"
            exit 0
            ;;
          esac
        fi

        # Standard selection (ROFI_RETV == 1)
        case "$info" in
        sched:*)
          open_viewer_schedule "''${info#sched:}"
          exit 0
          ;;
        overview)
          open_viewer_overview
          exit 0
          ;;
        back)
          fetch_state || true
          render_schedules_menu "false"
          exit 0
          ;;
        act-open:*)
          open_viewer_schedule "''${info#act-open:}"
          exit 0
          ;;
        act-run:*)
          run_schedule_now "''${info#act-run:}"
          fetch_state || true
          render_schedules_menu "false"
          exit 0
          ;;
        act-toggle:*)
          sched_name="''${info#act-toggle:}"
          toggle_schedule_enabled "$sched_name"
          fetch_state || true
          render_schedule_submenu "$sched_name"
          exit 0
          ;;
        act-latest:*)
          open_viewer_turn "''${info#act-latest:}"
          exit 0
          ;;
        act-remove:*)
          if remove_schedule "''${info#act-remove:}"; then
            fetch_state || true
            render_schedules_menu "false"
          else
            render_schedule_submenu "''${info#act-remove:}"
          fi
          exit 0
          ;;
        *)
          exit 0
          ;;
        esac
      '';
  };
}
