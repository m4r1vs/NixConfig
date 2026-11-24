/*
Waybar custom/hey-computer module script (replaces custom/os-logo on hosts with
hey-computer enabled).

Continuous watcher (`watch` subcommand, restarted by Waybar if it exits):
- Thinking: animates quickly through 6 robot Nerd Font icons (no text, no color)
- Follow-up window open: shows the robot-chat icon (no text, no color)
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

        query_state() {
          local status_json
          if status_json=$(${heyComputer} status --json 2>/dev/null); then
            jq -r '
              if .running != null then "thinking"
              elif .follow_up_secs != null then "followup"
              else "idle" end
            ' <<<"$status_json" 2>/dev/null || printf 'idle'
          else
            printf 'idle'
          fi
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
            case "$(query_state)" in
            thinking)
              emit "{\"text\":\" ''${frames[$frame_idx]} \",\"class\":\"thinking\",\"tooltip\":\"Hey Computer: thinking (click to cancel)\"}"
              frame_idx=$(( (frame_idx + 1) % ''${#frames[@]} ))
              sleep_interruptible 0.18
              ;;
            followup)
              frame_idx=0
              emit '{"text":" 󱚥 ","class":"followup","tooltip":"Hey Computer: follow-up window (click to ask)"}'
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
          case "$(query_state)" in
          thinking)
            echo '{"text":" 󱜙 ","class":"thinking","tooltip":"Hey Computer: thinking (click to cancel)"}'
            ;;
          followup)
            echo '{"text":" 󱚥 ","class":"followup","tooltip":"Hey Computer: follow-up window (click to ask)"}'
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
