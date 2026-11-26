/*
Waybar custom/hey-computer module script (replaces custom/os-logo on hosts with
hey-computer enabled).

Continuous watcher (`watch` subcommand, restarted by Waybar if it exits):
- Thinking / speaking: animates quickly through robot Nerd Font icons (no text, no color)
- Follow-up window open: shows the robot-chat icon (no text, no color)
- Background tasks active while foreground is idle: shows a steady robot icon
  with background task count in tooltip
- Otherwise (idle / locked / starting / down): shows the NixOS logo like custom/os-logo

Click actions preserve custom/os-logo when idle (left: rofi search, middle:
toggle spoken voice answers, right: power menu), cancel when thinking or
speaking, and open rofi-ask when the follow-up window is open.
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
      pkgs.libnotify
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
                 elif (.speaking // false) then "speaking"
                 elif .follow_up_secs != null then "followup"
                 elif ((.background_running // 0) + (.background_queued // 0)) > 0 then "background"
                 else "idle" end),
                (.agent // "down"),
                (.running_profile // ""),
                ((.background_running // 0) | tostring),
                ((.background_queued // 0) | tostring),
                (if (.speak // false) then "1" else "0" end)
              ] | join("|")
            ' <<<"$status_json" 2>/dev/null || printf 'idle|offline||0|0|0'
          else
            printf 'idle|offline||0|0|0'
          fi
        }

        query_state() {
          local state _agent _profile _bg_run _bg_queue _speak
          IFS='|' read -r state _agent _profile _bg_run _bg_queue _speak <<<"$(query_status)"
          printf '%s' "$state"
        }

        format_bg_suffix() {
          local bg_run="$1" bg_queue="$2" speak="$3" out=""
          if [ "$bg_run" -gt 0 ] && [ "$bg_queue" -gt 0 ]; then
            out=" • ''${bg_run} bg, ''${bg_queue} queued"
          elif [ "$bg_run" -gt 0 ]; then
            out=" • ''${bg_run} bg"
          elif [ "$bg_queue" -gt 0 ]; then
            out=" • ''${bg_queue} queued"
          fi
          if [ "$speak" = "1" ]; then
            out="''${out} • speak on"
          fi
          printf '%s' "$out"
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
        quiet-speech)
          if [ "$(query_state)" = "speaking" ]; then
            ${heyComputer} cancel >/dev/null 2>&1 || true
            wake_watcher
          fi
          ;;
        toggle-speak)
          if speak_json=$(${heyComputer} speak toggle --json 2>/dev/null); then
            enabled=$(jq -r '.enabled // false' <<<"$speak_json" 2>/dev/null || printf 'false')
            if [ "$enabled" = "true" ]; then
              notify-send -e --app-name=hey-computer --urgency=low --expire-time=2500 "Ask Computer" "Spoken voice answers: ON" || true
            else
              notify-send -e --app-name=hey-computer --urgency=low --expire-time=2500 "Ask Computer" "Spoken voice answers: OFF" || true
            fi
          fi
          wake_watcher
          ;;
        click)
          case "$(query_state)" in
          thinking | speaking)
            ${heyComputer} cancel >/dev/null 2>&1 || true
            wake_watcher
            ;;
          followup)
            exec ${scripts.rofi-launch} ask
            ;;
          background)
            exec ${scripts.rofi-launch} history
            ;;
          *)
            exec ${scripts.rofi-launch} search
            ;;
          esac
          ;;
        right-click)
          case "$(query_state)" in
          thinking | speaking)
            ${heyComputer} cancel >/dev/null 2>&1 || true
            wake_watcher
            ;;
          *)
            exec ${scripts.rofi-launch} power
            ;;
          esac
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
            IFS='|' read -r state agent profile bg_run bg_queue speak <<<"$(query_status)"
            bg_suffix=$(format_bg_suffix "$bg_run" "$bg_queue" "$speak")
            case "$state" in
            thinking)
              profile_tag=""
              if [ -n "$profile" ]; then
                profile_tag=" ($profile)"
              fi
              emit "$(format_json " ''${frames[$frame_idx]} " "thinking" "Ask Computer: thinking''${profile_tag}''${bg_suffix} (click to cancel)")"
              frame_idx=$(((frame_idx + 1) % ''${#frames[@]}))
              sleep_interruptible 0.18
              ;;
            speaking)
              emit "$(format_json " 󰕾 " "speaking" "Ask Computer: speaking''${bg_suffix} (click to stop)")"
              sleep_interruptible 0.3
              ;;
            followup)
              frame_idx=0
              emit "$(format_json " 󱚥 " "followup" "Ask Computer: follow-up window''${bg_suffix} (click to ask)")"
              sleep_interruptible 0.5
              ;;
            background)
              frame_idx=0
              if [ "$bg_run" -gt 0 ] && [ "$bg_queue" -gt 0 ]; then
                tooltip="Ask Computer: $bg_run background task(s), $bg_queue queued (click for tasks & history)"
              elif [ "$bg_run" -gt 0 ]; then
                tooltip="Ask Computer: $bg_run background task(s) running (click for tasks & history)"
              else
                tooltip="Ask Computer: $bg_queue background task(s) queued (click for tasks & history)"
              fi
              emit "$(format_json " 󱚣 " "bg-tasks" "$tooltip")"
              sleep_interruptible 0.5
              ;;
            *)
              frame_idx=0
              case "$agent" in
              locked)
                emit "$(format_json "  " "idle" "Ask Computer: keyring locked''${bg_suffix}")"
                ;;
              starting)
                emit "$(format_json "  " "idle" "Ask Computer: starting…")"
                ;;
              offline | down)
                emit "$(format_json "  " "idle" "Ask Computer: offline")"
                ;;
              *)
                if [ "$speak" = "1" ]; then
                  emit "$(format_json "  " "idle" "Ask Computer: spoken answers ON (middle-click to mute)")"
                else
                  emit '{"text":"  ","class":"idle","tooltip":""}'
                fi
                ;;
              esac
              sleep_interruptible 0.5
              ;;
            esac
          done
          ;;
        *)
          IFS='|' read -r state agent profile bg_run bg_queue speak <<<"$(query_status)"
          bg_suffix=$(format_bg_suffix "$bg_run" "$bg_queue" "$speak")
          case "$state" in
          thinking)
            profile_tag=""
            if [ -n "$profile" ]; then
              profile_tag=" ($profile)"
            fi
            format_json " 󱜙 " "thinking" "Ask Computer: thinking''${profile_tag}''${bg_suffix} (click to cancel)"
            ;;
          speaking)
            format_json " 󰕾 " "speaking" "Ask Computer: speaking''${bg_suffix} (click to stop)"
            ;;
          followup)
            format_json " 󱚥 " "followup" "Ask Computer: follow-up window''${bg_suffix} (click to ask)"
            ;;
          background)
            if [ "$bg_run" -gt 0 ] && [ "$bg_queue" -gt 0 ]; then
              tooltip="Ask Computer: $bg_run background task(s), $bg_queue queued (click for tasks & history)"
            elif [ "$bg_run" -gt 0 ]; then
              tooltip="Ask Computer: $bg_run background task(s) running (click for tasks & history)"
            else
              tooltip="Ask Computer: $bg_queue background task(s) queued (click for tasks & history)"
            fi
            format_json " 󱚣 " "bg-tasks" "$tooltip"
            ;;
          *)
            case "$agent" in
            locked)
              format_json "  " "idle" "Ask Computer: keyring locked''${bg_suffix}"
              ;;
            starting)
              format_json "  " "idle" "Ask Computer: starting…"
              ;;
            offline | down)
              format_json "  " "idle" "Ask Computer: offline"
              ;;
            *)
              if [ "$speak" = "1" ]; then
                format_json "  " "idle" "Ask Computer: spoken answers ON (middle-click to mute)"
              else
                echo '{"text":"  ","class":"idle","tooltip":""}'
              fi
              ;;
            esac
            ;;
          esac
          ;;
        esac
      '';
  };
}
