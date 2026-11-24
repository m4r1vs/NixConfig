/*
Waybar custom/hey-computer module script (replaces custom/os-logo on hosts with
hey-computer enabled).

Continuous watcher (`watch` subcommand, restarted by Waybar if it exits):
- Thinking: animates quickly through 6 robot Nerd Font icons (no text, no color)
- Follow-up window open: shows the robot-chat icon (no text, no color)
- Background tasks active while foreground is idle: shows a steady robot icon
  with background task count in tooltip
- Otherwise (idle / starting / down): shows the NixOS logo like custom/os-logo

Click actions preserve custom/os-logo when idle (left: rofi search, right: power
menu), cancel when thinking, and open rofi-ask when the follow-up window is open.
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
  waybar-hey-computer = helpers.mkScript {
    name = "waybar-hey-computer";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.procps
    ];
    text =
      # bash
      ''
        wake_watcher() {
          pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
        }

        query_status() {
          local status_json
          if status_json=$(${heyComputer} status --json 2>/dev/null); then
            jq -r '
              [
                (if .running != null then "thinking"
                 elif .follow_up_secs != null then "followup"
                 elif ((.background_running // 0) + (.background_queued // 0)) > 0 then "background"
                 else "idle" end),
                (.running_profile // ""),
                ((.background_running // 0) | tostring),
                ((.background_queued // 0) | tostring)
              ] | join("|")
            ' <<<"$status_json" 2>/dev/null || printf 'idle||0|0'
          else
            printf 'idle||0|0'
          fi
        }

        query_state() {
          local state _profile _bg_run _bg_queue
          IFS='|' read -r state _profile _bg_run _bg_queue <<<"$(query_status)"
          printf '%s' "$state"
        }

        format_bg_suffix() {
          local bg_run="$1" bg_queue="$2"
          if [ "$bg_run" -gt 0 ] && [ "$bg_queue" -gt 0 ]; then
            printf ' • %s bg, %s queued' "$bg_run" "$bg_queue"
          elif [ "$bg_run" -gt 0 ]; then
            printf ' • %s bg' "$bg_run"
          elif [ "$bg_queue" -gt 0 ]; then
            printf ' • %s queued' "$bg_queue"
          fi
        }

        format_json() {
          jq -cn --arg text "$1" --arg class "$2" --arg tooltip "$3" \
            '{text: $text, class: $class, tooltip: $tooltip}'
        }

        case "''${1-}" in
        cancel)
          ${heyComputer} cancel >/dev/null 2>&1 || true
          wake_watcher
          ;;
        click)
          case "$(query_state)" in
          thinking)
            ${heyComputer} cancel >/dev/null 2>&1 || true
            wake_watcher
            ;;
          followup)
            exec ${scripts.rofi-launch} ask
            ;;
          *)
            exec ${scripts.rofi-launch} search
            ;;
          esac
          ;;
        right-click)
          if [ "$(query_state)" = "thinking" ]; then
            ${heyComputer} cancel >/dev/null 2>&1 || true
            wake_watcher
          else
            exec ${scripts.rofi-launch} power
          fi
          ;;
        watch)
          sleep_pid=""
          cleanup() {
            if [ -n "$sleep_pid" ]; then
              kill "$sleep_pid" 2>/dev/null || true
            fi
            exit 0
          }
          trap cleanup TERM INT HUP PIPE
          trap 'if [ -n "$sleep_pid" ]; then kill "$sleep_pid" 2>/dev/null || true; fi' USR1

          frames=("󰚩" "󱚝" "󱚟" "󱚡" "󱚣" "󱜙")
          frame_idx=0
          last_line=""

          emit() {
            if [ "$1" != "$last_line" ]; then
              printf '%s\n' "$1" || exit 0
              last_line="$1"
            fi
          }

          sleep_interruptible() {
            sleep "$1" &
            sleep_pid=$!
            wait "$sleep_pid" 2>/dev/null || true
            sleep_pid=""
          }

          while true; do
            IFS='|' read -r state profile bg_run bg_queue <<<"$(query_status)"
            bg_suffix=$(format_bg_suffix "$bg_run" "$bg_queue")
            case "$state" in
            thinking)
              profile_tag=""
              if [ -n "$profile" ]; then
                profile_tag=" ($profile)"
              fi
              emit "$(format_json " ''${frames[$frame_idx]} " "thinking" "Ask Computer: thinking''${profile_tag}''${bg_suffix} (click to cancel)")"
              frame_idx=$(( (frame_idx + 1) % ''${#frames[@]} ))
              sleep_interruptible 0.18
              ;;
            followup)
              frame_idx=0
              emit "$(format_json " 󱚥 " "followup" "Ask Computer: follow-up window''${bg_suffix} (click to ask)")"
              sleep_interruptible 0.5
              ;;
            background)
              frame_idx=0
              if [ "$bg_run" -gt 0 ] && [ "$bg_queue" -gt 0 ]; then
                tooltip="Ask Computer: $bg_run background task(s), $bg_queue queued"
              elif [ "$bg_run" -gt 0 ]; then
                tooltip="Ask Computer: $bg_run background task(s) running"
              else
                tooltip="Ask Computer: $bg_queue background task(s) queued"
              fi
              emit "$(format_json " 󱚣 " "background" "$tooltip")"
              sleep_interruptible 0.5
              ;;
            *)
              frame_idx=0
              emit '{"text":"  ","class":"idle","tooltip":""}'
              sleep_interruptible 0.5
              ;;
            esac
          done
          ;;
        *)
          IFS='|' read -r state profile bg_run bg_queue <<<"$(query_status)"
          bg_suffix=$(format_bg_suffix "$bg_run" "$bg_queue")
          case "$state" in
          thinking)
            profile_tag=""
            if [ -n "$profile" ]; then
              profile_tag=" ($profile)"
            fi
            format_json " 󱜙 " "thinking" "Ask Computer: thinking''${profile_tag}''${bg_suffix} (click to cancel)"
            ;;
          followup)
            format_json " 󱚥 " "followup" "Ask Computer: follow-up window''${bg_suffix} (click to ask)"
            ;;
          background)
            if [ "$bg_run" -gt 0 ] && [ "$bg_queue" -gt 0 ]; then
              tooltip="Ask Computer: $bg_run background task(s), $bg_queue queued"
            elif [ "$bg_run" -gt 0 ]; then
              tooltip="Ask Computer: $bg_run background task(s) running"
            else
              tooltip="Ask Computer: $bg_queue background task(s) queued"
            fi
            format_json " 󱚣 " "background" "$tooltip"
            ;;
          *)
            echo '{"text":"  ","class":"idle","tooltip":""}'
            ;;
          esac
          ;;
        esac
      '';
  };
}
