/*
Rofi `-modi` menu for hey-computer conversation history and active background
tasks (`SUPER + SHIFT + a`, `rofi-launch history`, aliased from `tasks` and
Waybar left-click when background tasks are running).

Keybindings (configured in `rofi-launch.nix`, avoiding `rofi.nix`'s global
`Alt+{h,j,k,l,e,y}` navigation chords):
- `Enter`  : open thread in `hey-computer-viewer` (or safe 3-item submenu on active task)
- `/query` : type `/<query>` + `Enter` (or unmatched text + `Enter`) for full-DB FTS5 search
- `Alt+r`  : reply to selected conversation via `rofi-launch ask <id>`
- `Alt+c`  : copy answer (`hey-computer tasks copy <id>`) or active task prompt
- `Alt+x`  : cancel selected running/queued background task immediately and refresh
- `Alt+m`  : open per-item Actions Submenu
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
  rofi-hey-computer-history = helpers.mkScript {
    name = "rofi-hey-computer-history";
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
        state_file="''${XDG_RUNTIME_DIR:-/tmp}/rofi-hc-history-state.json"

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
          ${scripts.nixos-notify} -u low -e -t 2500 -h string:synchronous:hey-computer-history "$summary" "$body" || true
        }

        write_state() {
          local payload="$1"
          local tmp
          tmp=$(mktemp "''${state_file}.XXXXXX")
          chmod 600 "$tmp"
          printf '%s\n' "$payload" >"$tmp"
          mv -f "$tmp" "$state_file"
        }

        # Fetch history JSON (with fallback to `tasks list` for older binaries or empty state if DB does not exist yet).
        fetch_state() {
          local query="''${1:-}"
          local raw=""
          local fallback_raw=""
          local now_ms
          now_ms=$(($(date +%s) * 1000))

          if [ -n "$query" ]; then
            if raw=$(${heyComputer} history --limit 50 --include-failed --json -- "$query" 2>/dev/null) \
              && printf '%s' "$raw" | jq -e 'type == "object" and (.items | type == "array")' >/dev/null 2>&1; then
              write_state "$raw"
              return 0
            fi
            # Fallback if older binary lacks `--include-failed` on `history`
            if raw=$(${heyComputer} history --limit 50 --json -- "$query" 2>/dev/null) \
              && printf '%s' "$raw" | jq -e 'type == "object" and (.items | type == "array")' >/dev/null 2>&1; then
              write_state "$raw"
              return 0
            fi
          else
            if raw=$(${heyComputer} history --limit 60 --include-failed --json 2>/dev/null) \
              && printf '%s' "$raw" | jq -e 'type == "object" and (.items | type == "array")' >/dev/null 2>&1; then
              write_state "$raw"
              return 0
            fi
          fi

          # Graceful fallback for older `hey-computer` binaries lacking `history` subcommand
          if fallback_raw=$(${heyComputer} tasks list --all --limit 40 --json 2>/dev/null) \
            && printf '%s' "$fallback_raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
            local normalized
            normalized=$(jq -c --argjson now_ms "$now_ms" --arg q "$query" '
              def clean($s): ($s // "" | gsub("[[:cntrl:]]+"; " ") | sub("^ +"; "") | sub(" +$"; ""));
              def matches($q):
                if $q == "" then true
                else ((.request // "") + " " + (.answer // "") | ascii_downcase | contains($q | ascii_downcase))
                end;
              {
                now_ms: $now_ms,
                query: (if $q == "" then null else $q end),
                active_tasks: [
                  .[] | select(.status == "running" or .status == "queued")
                  | {
                      id: .id,
                      status: .status,
                      profile: (.profile // ""),
                      created_at_ms: (.created_at_ms // $now_ms),
                      started_at_ms: (.started_at_ms // null),
                      title: clean(.request),
                      request: (.request // "")
                    }
                ],
                items: [
                  .[] | select(.status != "running" and .status != "queued")
                  | select(matches($q))
                  | {
                      id: .id,
                      latest_turn_id: .id,
                      lane: (.lane // "background"),
                      origin: (.origin // "cli"),
                      status: (.status // "completed"),
                      profile: (.profile // ""),
                      created_at_ms: (.created_at_ms // 0),
                      updated_at_ms: (.finished_at_ms // .created_at_ms // 0),
                      title: clean(.request),
                      request: (.request // ""),
                      answer_preview: (clean(.answer)[0:140]),
                      error_message: (.error_message // ""),
                      turn_count: 1,
                      widget_count: ((.widgets // []) | length)
                    }
                ]
              }
            ' <<<"$fallback_raw")
            write_state "$normalized"
            return 0
          fi

          # Empty state (e.g. history.db not initialized yet)
          local empty_json
          empty_json=$(jq -cn --argjson now_ms "$now_ms" --arg q "$query" '{
            now_ms: $now_ms,
            query: (if $q == "" then null else $q end),
            active_tasks: [],
            items: []
          }')
          write_state "$empty_json"
          return 0
        }

        open_viewer_turn() {
          local turn_id="$1"
          shift || true
          nohup ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect -- \
            ${heyComputer} view --turn-id "$turn_id" "$@" </dev/null >/dev/null 2>&1 &
        }

        # Invoke rofi directly (not via scripts.rofi-launch) to avoid a Nix derivation cycle with rofi-launch.
        launch_rofi_ask() {
          local reply_id="''${1:-}"
          HEY_COMPUTER_REPLY_TO="$reply_id" nohup ${pkgs.rofi}/bin/rofi \
            -modi ask:${scripts.rofi-ask} \
            -show ask \
            -theme-str 'entry {placeholder:"Ask Computer...";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}' \
            </dev/null >/dev/null 2>&1 &
        }

        launch_rofi_schedules() {
          nohup ${pkgs.rofi}/bin/rofi -i \
            -kb-custom-1 "Alt+r" \
            -kb-custom-2 "Alt+p" \
            -kb-custom-3 "Alt+x" \
            -kb-custom-4 "Alt+m" \
            -modi schedules:${scripts.rofi-hey-computer-schedules} \
            -show schedules \
            -theme-str 'entry {placeholder:"Scheduled Actions...";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 24% 22%;}' \
            </dev/null >/dev/null 2>&1 &
        }

        copy_prompt_for_id() {
          local kind="$1"
          local turn_id="$2"
          local prompt_text=""

          if [ -f "$state_file" ]; then
            if [ "$kind" = "task" ]; then
              prompt_text=$(jq -r --argjson id "$turn_id" '
                (.active_tasks // [])[] | select((.id // -1) == $id) | (.request // .title // "")
              ' "$state_file" 2>/dev/null | head -n 1 || true)
            else
              prompt_text=$(jq -r --argjson id "$turn_id" '
                (.items // [])[] | select((.latest_turn_id // .id // -1) == $id) | (.request // .title // "")
              ' "$state_file" 2>/dev/null | head -n 1 || true)
            fi
          fi

          # Prefer full untruncated request from `tasks show` if available
          local full_req=""
          if full_req=$(${heyComputer} tasks show "$turn_id" --json 2>/dev/null | jq -r '.request // ""' 2>/dev/null) \
            && [ -n "$full_req" ]; then
            prompt_text="$full_req"
          fi

          if [ -n "$prompt_text" ]; then
            printf '%s' "$prompt_text" | ${helpers.clipboard.copy}
            notify_low "Ask Computer" "Copied prompt (#''${turn_id})"
          else
            notify_low "Ask Computer" "No prompt found for #''${turn_id}"
          fi
        }

        copy_answer_for_id() {
          local turn_id="$1"
          if ${heyComputer} tasks copy "$turn_id" >/dev/null 2>&1; then
            notify_low "Ask Computer" "Copied answer (#''${turn_id})"
          else
            notify_low "Ask Computer" "No answer to copy for #''${turn_id}"
          fi
        }

        render_main_menu() {
          local keep_sel="''${1:-false}"
          if [ ! -f "$state_file" ]; then
            fetch_state ""
          fi

          local active_count item_count search_query
          active_count=$(jq -r '(.active_tasks // []) | length' "$state_file" 2>/dev/null || printf '0')
          item_count=$(jq -r '(.items // []) | length' "$state_file" 2>/dev/null || printf '0')
          search_query=$(jq -r '.query // ""' "$state_file" 2>/dev/null || true)

          if [ -n "$search_query" ]; then
            printf '\000data\037search:%s\n' "$search_query"
          else
            printf '\000data\037main\n'
          fi
          printf '\000no-custom\037false\n'
          printf '\000keep-selection\037%s\n' "$keep_sel"

          if [ -n "$search_query" ]; then
            set_placeholder "Search: ''${search_query} (''${item_count} hits) — Enter open · Alt+r reply · Alt+m menu"
            printf '󰌍  Clear search (back to recent chats)\000info\037clear-search\037meta\037clear back reset recent\n'
          elif [ "$active_count" -gt 0 ]; then
            set_placeholder "History (''${active_count} active) — /search · Alt+x cancel · Alt+r reply · Alt+m menu"
          else
            set_placeholder "Ask Computer History — /search · Alt+r reply · Alt+c copy · Alt+m menu"
          fi

          # Pinned top section: active & queued background tasks (only on main view, or when present)
          if [ -z "$search_query" ] && [ "$active_count" -gt 0 ]; then
            jq -r '
              def clean($s): ($s // "" | gsub("[[:cntrl:]]+"; " ") | sub("^ +"; "") | sub(" +$"; ""));
              def trunc($s; $n): clean($s) as $t | if ($t | length) > $n then ($t[0:$n] + "…") else $t end;
              def fmt_elapsed($ms):
                ($ms / 1000 | floor) as $s |
                if $s < 0 then "0s"
                elif $s < 60 then "\($s)s"
                elif $s < 3600 then "\($s / 60 | floor)m\($s % 60)s"
                else "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor)m"
                end;

              (.now_ms // (now * 1000)) as $now_ms |
              (.active_tasks // [])[]
              | (.id | tostring) as $id
              | (.status // "running") as $st
              | (.profile // "") as $prof
              | (if ($prof | length) > 0 then " · \($prof)" else "" end) as $prof_tag
              | trunc(.title // .request_preview // .request // "(untitled)"; 64) as $title
              | clean(.request // .title // "") as $full_req
              | (
                  if (.elapsed // "") != "" then .elapsed
                  elif (.elapsed_secs // null) != null then fmt_elapsed(.elapsed_secs * 1000)
                  elif (.started_at_ms // .created_at_ms // null) != null then fmt_elapsed($now_ms - (.started_at_ms // .created_at_ms))
                  else ""
                  end
                ) as $el
              | (if ($el | length) > 0 then " \($el)" else "" end) as $el_tag
              | "active task background \($st) \($prof) #\($id) \($full_req)" as $meta
              | if $st == "queued" then
                  "󰔟  [queued\($prof_tag)] #\($id): \($title)  (Enter actions · Alt+x cancel)\u0000info\u001ftask:\($id)\u001fmeta\u001f\($meta)"
                else
                  "󱚣  [running\($el_tag)\($prof_tag)] #\($id): \($title)  (Enter actions · Alt+x cancel)\u0000info\u001ftask:\($id)\u001fmeta\u001f\($meta)"
                end
            ' "$state_file" 2>/dev/null || true
          fi

          # Chronological thread-grouped past chats
          if [ "$item_count" -gt 0 ]; then
            jq -r '
              def clean($s): ($s // "" | gsub("[[:cntrl:]]+"; " ") | sub("^ +"; "") | sub(" +$"; ""));
              def trunc($s; $n): clean($s) as $t | if ($t | length) > $n then ($t[0:$n] + "…") else $t end;
              def fmt_rel($ts_ms; $now_ms):
                (($now_ms - $ts_ms) / 1000 | floor) as $d |
                if $ts_ms <= 0 then ""
                elif $d < 60 then "just now"
                elif $d < 3600 then "\($d / 60 | floor)m ago"
                elif $d < 86400 then "\($d / 3600 | floor)h ago"
                elif $d < 172800 then "yesterday"
                elif $d < 604800 then "\($d / 86400 | floor)d ago"
                else (($ts_ms / 1000) | floor | strflocaltime("%b %d"))
                end;

              (.now_ms // (now * 1000)) as $now_ms |
              (.items // [])[]
              | ((.latest_turn_id // .id) | tostring) as $id
              | (.origin // "typed") as $origin
              | (.lane // "foreground") as $lane
              | (.status // "completed") as $status
              | (.schedule_name // "") as $sched
              | (.profile // "") as $prof
              | (.updated_at_ms // .finished_at_ms // .created_at_ms // 0) as $ts
              | (
                  if (.relative_time // "") != "" then .relative_time
                  else fmt_rel($ts; $now_ms)
                  end
                ) as $rel
              | (
                  if (.local_date // "") != "" then .local_date
                  elif (.date // "") != "" then .date
                  elif $ts > 0 then (($ts / 1000) | floor | strflocaltime("%Y-%m-%d"))
                  else ""
                  end
                ) as $date
              | (
                  if $status == "failed" or $status == "cancelled" then "󰅚"
                  elif $sched == "morning-digest" then "󰖨"
                  elif $origin == "distill" or $sched == "weekly-distill" then "󰧑"
                  elif $origin == "schedule" or $origin == "schedule_script" or ($sched | length) > 0 then "󰔟"
                  elif $origin == "voice" then "󰍬"
                  elif $lane == "background" then "󱚣"
                  else "󰌌"
                  end
                ) as $icon
              | trunc(.title // .request_preview // .request // "(untitled)"; 52) as $title
              | clean(.answer_preview // .snippet // "") as $raw_prev
              | trunc($raw_prev; 58) as $prev
              | trunc(.error_message // ""; 48) as $err
              | (.turn_count // 1) as $turns
              | (.widget_count // 0) as $widgets
              | (if $turns > 1 then "  💬 \($turns)" else "" end) as $turn_badge
              | (
                  if $status == "failed" or $status == "cancelled" then
                    if ($err | length) > 0 then "  —  [\($status)] \($err)"
                    else "  —  [\($status)]"
                    end
                  elif ($prev | length) > 0 then
                    "  —  \($prev)"
                  elif $widgets > 0 then
                    "  —  [\($widgets) widget\(if $widgets == 1 then "" else "s" end)]"
                  else
                    ""
                  end
                ) as $tail
              | (if ($rel | length) > 0 then "\($rel) · " else "" end) as $time_prefix
              | clean("#\($id) \($origin) \($lane) \($prof) \($status) \($sched) \($date) \(.title // .request // "") \($raw_prev)") as $meta
              | "\($icon)  \($time_prefix)\($title)\($tail)\($turn_badge)\u0000info\u001fchat:\($id)\u001fmeta\u001f\($meta)"
            ' "$state_file" 2>/dev/null || true
          elif [ "$active_count" -eq 0 ] && [ -z "$search_query" ]; then
            printf '󰚩  Ask Computer…  (no conversations yet)\000info\037open-ask\n'
            printf '󰔟  Scheduled Actions…\000info\037open-schedules\n'
          fi
        }

        render_task_submenu() {
          local task_id="$1"
          local title=""
          if [ -f "$state_file" ]; then
            title=$(jq -r --argjson id "$task_id" '
              (.active_tasks // [])[] | select((.id // -1) == $id)
              | (.title // .request_preview // .request // "")
              | gsub("[[:cntrl:]]+"; " ")
              | .[0:48]
            ' "$state_file" 2>/dev/null | head -n 1 || true)
          fi

          printf '\000data\037task-menu:%s\n' "$task_id"
          printf '\000no-custom\037true\n'
          printf '\000keep-selection\037false\n'
          set_placeholder "Task #''${task_id}''${title:+: $title}"

          printf '󰜺  Cancel task #%s\000info\037task-cancel:%s\n' "$task_id" "$task_id"
          printf '󰆏  Copy prompt\000info\037task-copy-prompt:%s\n' "$task_id"
          printf '󰌍  Back\000info\037back\n'
        }

        render_chat_submenu() {
          local turn_id="$1"
          local title=""
          if [ -f "$state_file" ]; then
            title=$(jq -r --argjson id "$turn_id" '
              (.items // [])[] | select((.latest_turn_id // .id // -1) == $id)
              | (.title // .request_preview // .request // "")
              | gsub("[[:cntrl:]]+"; " ")
              | .[0:48]
            ' "$state_file" 2>/dev/null | head -n 1 || true)
          fi

          printf '\000data\037chat-menu:%s\n' "$turn_id"
          printf '\000no-custom\037true\n'
          printf '\000keep-selection\037false\n'
          set_placeholder "Actions for #''${turn_id}''${title:+: $title}"

          printf '󰕮  Open in Viewer\000info\037chat-open:%s\n' "$turn_id"
          printf '󰏫  Open & Focus Follow-up Composer\000info\037chat-composer:%s\n' "$turn_id"
          printf '󰑚  Reply via Rofi Ask\000info\037chat-reply:%s\n' "$turn_id"
          printf '󰆏  Copy Answer\000info\037chat-copy-answer:%s\n' "$turn_id"
          printf '󰅍  Copy Prompt\000info\037chat-copy-prompt:%s\n' "$turn_id"
          printf '󰌍  Back\000info\037back\n'
        }

        retv="''${ROFI_RETV:-0}"
        info="''${ROFI_INFO:-}"
        data="''${ROFI_DATA:-}"

        # Initial invocation
        if [ "$retv" -eq 0 ]; then
          fetch_state ""
          render_main_menu "false"
          exit 0
        fi

        # Custom input (ROFI_RETV=2): `/query` or unmatched text runs full-DB FTS5 search
        if [ "$retv" -eq 2 ]; then
          typed="''${1:-}"
          query="''${typed#/}"
          query=$(printf '%s' "$query" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
          fetch_state "$query"
          render_main_menu "false"
          exit 0
        fi

        # Custom keybinds:
        # ROFI_RETV=10 -> kb-custom-1 (Alt+r): Reply via Rofi Ask
        if [ "$retv" -eq 10 ]; then
          case "$info" in
          chat:*)
            launch_rofi_ask "''${info#chat:}"
            exit 0
            ;;
          *)
            render_main_menu "true"
            exit 0
            ;;
          esac
        fi

        # ROFI_RETV=11 -> kb-custom-2 (Alt+c): Copy answer (chat) or prompt (active task)
        if [ "$retv" -eq 11 ]; then
          case "$info" in
          chat:*)
            turn_id="''${info#chat:}"
            copy_answer_for_id "$turn_id"
            exit 0
            ;;
          task:*)
            task_id="''${info#task:}"
            copy_prompt_for_id "task" "$task_id"
            exit 0
            ;;
          *)
            render_main_menu "true"
            exit 0
            ;;
          esac
        fi

        # ROFI_RETV=12 -> kb-custom-3 (Alt+x): Cancel active task in place
        if [ "$retv" -eq 12 ]; then
          case "$info" in
          task:*)
            task_id="''${info#task:}"
            ${heyComputer} tasks cancel "$task_id" >/dev/null 2>&1 || true
            wake_watcher
            notify_low "Ask Computer" "Cancelled task #''${task_id}"
            fetch_state ""
            render_main_menu "false"
            exit 0
            ;;
          *)
            render_main_menu "true"
            exit 0
            ;;
          esac
        fi

        # ROFI_RETV=13 -> kb-custom-4 (Alt+m): Open Actions Submenu
        if [ "$retv" -eq 13 ]; then
          case "$info" in
          chat:*)
            render_chat_submenu "''${info#chat:}"
            exit 0
            ;;
          task:*)
            render_task_submenu "''${info#task:}"
            exit 0
            ;;
          *)
            render_main_menu "true"
            exit 0
            ;;
          esac
        fi

        # Standard selection (ROFI_RETV == 1)
        case "$info" in
        task:*)
          render_task_submenu "''${info#task:}"
          exit 0
          ;;
        chat:*)
          open_viewer_turn "''${info#chat:}"
          exit 0
          ;;
        clear-search)
          fetch_state ""
          render_main_menu "false"
          exit 0
          ;;
        back)
          if [[ "$data" == search:* ]]; then
            fetch_state "''${data#search:}"
          fi
          render_main_menu "false"
          exit 0
          ;;
        open-ask)
          launch_rofi_ask ""
          exit 0
          ;;
        open-schedules)
          launch_rofi_schedules
          exit 0
          ;;
        task-cancel:*)
          task_id="''${info#task-cancel:}"
          ${heyComputer} tasks cancel "$task_id" >/dev/null 2>&1 || true
          wake_watcher
          notify_low "Ask Computer" "Cancelled task #''${task_id}"
          fetch_state ""
          render_main_menu "false"
          exit 0
          ;;
        task-copy-prompt:*)
          copy_prompt_for_id "task" "''${info#task-copy-prompt:}"
          exit 0
          ;;
        chat-open:*)
          open_viewer_turn "''${info#chat-open:}"
          exit 0
          ;;
        chat-composer:*)
          open_viewer_turn "''${info#chat-composer:}" --focus-composer
          exit 0
          ;;
        chat-reply:*)
          launch_rofi_ask "''${info#chat-reply:}"
          exit 0
          ;;
        chat-copy-answer:*)
          copy_answer_for_id "''${info#chat-copy-answer:}"
          exit 0
          ;;
        chat-copy-prompt:*)
          copy_prompt_for_id "chat" "''${info#chat-copy-prompt:}"
          exit 0
          ;;
        *)
          exit 0
          ;;
        esac
      '';
  };
}
