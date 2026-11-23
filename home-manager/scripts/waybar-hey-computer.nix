/*
Waybar custom/hey-computer module script (signal 12, interval 1).
Hidden when idle; shows thinking (with elapsed seconds), follow-up countdown,
starting, or down state. Clicking while thinking cancels; clicking in the
follow-up window opens `rofi-ask`.
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
        refresh_waybar() {
          pkill -RTMIN+12 -x '\.?waybar(-wrapped)?' || true
        }

        case "''${1-}" in
        cancel)
          ${heyComputer} cancel >/dev/null 2>&1 || true
          refresh_waybar
          ;;
        click)
          if status_json=$(${heyComputer} status --json 2>/dev/null) \
            && jq -e '.running != null' <<<"$status_json" >/dev/null 2>&1; then
            ${heyComputer} cancel >/dev/null 2>&1 || true
            refresh_waybar
          else
            exec ${scripts.rofi-ask}
          fi
          ;;
        *)
          if ! status_json=$(${heyComputer} status --json 2>/dev/null); then
            echo '{"text":"󱙺 !","class":"down","tooltip":"<b>Hey Computer</b>\nDaemon is not running"}'
            exit 0
          fi
          jq -c '
            if .running != null then {
              text: "󱙺 \(.running_secs // 0 | floor)s",
              class: "thinking",
              tooltip: "<b>Hey Computer: thinking</b>\nRequest #\(.running) (\(.running_secs // 0 | floor)s)\n\nClick to cancel"
            } elif .agent == "starting" then {
              text: "󱙺 …",
              class: "starting",
              tooltip: "<b>Hey Computer</b>\nStarting agent…"
            } elif .agent == "down" then {
              text: "󱙺 !",
              class: "down",
              tooltip: "<b>Hey Computer</b>\nAgent is down"
            } elif .follow_up_secs != null then {
              text: "󱙺 \(.follow_up_secs | ceil)s",
              class: "followup",
              tooltip: "<b>Hey Computer: follow-up window</b>\n\(.follow_up_secs | ceil)s left (\(.handled) handled)\n\nClick to ask · Right-click to cancel"
            } else {
              text: "",
              class: "idle",
              tooltip: "Hey Computer: idle (\(.handled) handled)"
            } end
          ' <<<"$status_json"
          ;;
        esac
      '';
  };
}
