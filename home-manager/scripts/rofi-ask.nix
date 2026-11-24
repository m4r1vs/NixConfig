/*
Typed Rofi `-modi` front end for hey-computer (`SUPER + a`, `rofi-launch ask`).
Matches `rofi-calculator`'s minimalist single-bar layout (no initial rows).
Prefix a prompt with `! ` or `/new ` to force a fresh conversation (`ask --new`).
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

        # Initial invocation: emit only the dynamic placeholder (zero rows, like calc)
        if [ "$retv" -eq 0 ]; then
          placeholder="Ask Hey Computer..."
          if status_json=$(${heyComputer} status --json 2>/dev/null); then
            placeholder=$(jq -r '
              if .running != null then
                "Ask Hey Computer (replaces current)..."
              elif .follow_up_secs != null then
                "Follow up... (! for new)"
              elif .agent == "down" then
                "Ask Hey Computer (offline)..."
              else
                "Ask Hey Computer..."
              end
            ' <<<"$status_json" 2>/dev/null || printf '%s\n' "$placeholder")
          else
            placeholder="Ask Hey Computer (offline)..."
          fi
          set_placeholder "$placeholder"
          exit 0
        fi

        query="''${1-}"
        trimmed=$(printf '%s' "$query" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -n "$trimmed" ] || exit 0

        args=(ask)
        case "$trimmed" in
        "! "*)
          args+=(--new)
          trimmed=''${trimmed#"! "}
          ;;
        "/new "*)
          args+=(--new)
          trimmed=''${trimmed#"/new "}
          ;;
        esac

        [ -n "$trimmed" ] || exit 0

        # Suppress stdout so Rofi closes cleanly after submitting
        printf '%s' "$trimmed" | ${heyComputer} "''${args[@]}" >/dev/null 2>&1 || true
        pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
      '';
  };
}
