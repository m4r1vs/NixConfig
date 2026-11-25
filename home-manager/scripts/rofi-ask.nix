/*
Typed Rofi `-modi` front end for hey-computer (`SUPER + a`, `rofi-launch ask`).
Matches `rofi-calculator`'s minimalist single-bar layout (no initial rows).
Supports composable prefixes in any order:
- `! ` or `/new `   -> `ask --new` (fresh conversation)
- `/deep ` or `/d ` -> `ask --profile deep`
- `/fast `          -> `ask --profile fast`
- `/bg ` or `/task ` -> `ask --background` (background lane)
*/
{
  pkgs,
  lib,
  config,
  systemArgs,
  helpers,
  ...
}: let
  heyComputer = lib.getExe config.home-manager.users.${systemArgs.username}.programs.hey-computer.package;
in {
  rofi-ask = helpers.mkScript {
    name = "rofi-ask";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
      pkgs.procps
    ];
    text =
      # bash
      ''
        set_placeholder() {
          local escaped
          escaped=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
          printf '\000theme\037entry { placeholder: "%s"; }\n' "$escaped"
        }

        retv="''${ROFI_RETV:-0}"
        reply_to="''${HEY_COMPUTER_REPLY_TO:-}"

        # Initial invocation: emit only the dynamic placeholder (zero rows, like calc)
        if [ "$retv" -eq 0 ]; then
          placeholder="Ask Computer..."
          if [ -n "$reply_to" ]; then
            placeholder="Reply to #''${reply_to}..."
          elif status_json=$(${heyComputer} status --json 2>/dev/null); then
            placeholder=$(jq -r '
              (if (.background_running // 0) > 0 and (.background_queued // 0) > 0 then
                  " [\(.background_running) bg, \(.background_queued) queued]"
                elif (.background_running // 0) > 0 then
                  " [\(.background_running) bg]"
                elif (.background_queued // 0) > 0 then
                  " [\(.background_queued) queued]"
                else "" end) as $bg
              | if .running != null then
                  "Ask Computer (replaces current, or /bg)\($bg)..."
                elif .follow_up_secs != null then
                  "Follow up\($bg)..."
                elif .agent == "locked" then
                  "Ask Computer (keyring locked)\($bg)..."
                elif .agent == "starting" then
                  "Ask Computer (starting…)\($bg)..."
                elif .agent == "down" then
                  "Ask Computer (offline)..."
                else
                  "Ask Computer\($bg)..."
                end
            ' <<<"$status_json" 2>/dev/null || printf '%s\n' "$placeholder")
          else
            placeholder="Ask Computer (offline)..."
          fi
          set_placeholder "$placeholder"
          exit 0
        fi

        query="''${1-}"
        trimmed=$(printf '%s' "$query" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -n "$trimmed" ] || exit 0

        case "$trimmed" in
        "/speak" | "/tts")
          ${heyComputer} speak toggle >/dev/null 2>&1 || true
          pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
          exit 0
          ;;
        "/distill")
          nohup ${heyComputer} distill </dev/null >/dev/null 2>&1 &
          pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
          exit 0
          ;;
        esac

        args=(ask --source typed)
        explicit_new=0
        while true; do
          case "$trimmed" in
          "! "*)
            args+=(--new)
            explicit_new=1
            trimmed=''${trimmed#"! "}
            ;;
          "/new "*)
            args+=(--new)
            explicit_new=1
            trimmed=''${trimmed#"/new "}
            ;;
          "/deep "*)
            args+=(--profile deep)
            trimmed=''${trimmed#"/deep "}
            ;;
          "/d "*)
            args+=(--profile deep)
            trimmed=''${trimmed#"/d "}
            ;;
          "/fast "*)
            args+=(--profile fast)
            trimmed=''${trimmed#"/fast "}
            ;;
          "/bg "*)
            args+=(--background)
            trimmed=''${trimmed#"/bg "}
            ;;
          "/task "*)
            args+=(--background)
            trimmed=''${trimmed#"/task "}
            ;;
          *)
            break
            ;;
          esac
          trimmed=$(printf '%s' "$trimmed" | sed 's/^[[:space:]]*//')
        done

        if [ -n "$reply_to" ] && [ "$explicit_new" -eq 0 ]; then
          args+=(--reply-to "$reply_to")
        fi

        [ -n "$trimmed" ] || exit 0

        # Suppress stdout (including background task IDs) so Rofi closes cleanly
        printf '%s' "$trimmed" | ${heyComputer} "''${args[@]}" >/dev/null 2>&1 || true
        pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
      '';
  };
}
