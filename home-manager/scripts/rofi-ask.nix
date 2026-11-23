/*
Typed Rofi front end for hey-computer (`SUPER + a`, `rofi-launch ask`).
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
      pkgs.rofi
    ];
    text =
      # bash
      ''
        placeholder="Ask Hey Computer..."
        if status_json=$(${heyComputer} status --json 2>/dev/null); then
          placeholder=$(jq -r '
            if .running != null then
              "Ask Hey Computer (replaces running request)..."
            elif .follow_up_secs != null then
              "Follow up (\(.follow_up_secs | ceil)s) — prefix ! for new..."
            elif .agent == "down" then
              "Ask Hey Computer (agent down)..."
            else
              "Ask Hey Computer..."
            end
          ' <<<"$status_json" 2>/dev/null || printf '%s\n' "$placeholder")
        else
          placeholder="Ask Hey Computer (daemon not running)..."
        fi

        # Escape double quotes and backslashes for rofi -theme-str
        escaped_placeholder=''${placeholder//\\/\\\\}
        escaped_placeholder=''${escaped_placeholder//\"/\\\"}

        query=$(rofi -dmenu -i -l 0 -p "Ask" \
          -theme-str "entry { placeholder: \"$escaped_placeholder\"; } listview { enabled: false; } element-icon { enabled: false; } icon-current-entry { enabled: false; } inputbar { padding: 0 0 0 42; } window { padding: 44% 25%; }" \
          < /dev/null) || exit 0

        # Trim leading/trailing whitespace
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

        printf '%s' "$trimmed" | ${heyComputer} "''${args[@]}"
        pkill -RTMIN+12 -x '\.?waybar(-wrapped)?' || true
      '';
  };
}
