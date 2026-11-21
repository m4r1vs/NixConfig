{
  pkgs,
  lib,
  scripts,
  helpers,
  host,
  ...
}: {
  powermode = helpers.mkScript {
    name = "powermode";
    runtimeInputs =
      [
        pkgs.coreutils
        pkgs.jq
        pkgs.power-profiles-daemon
        pkgs.procps
      ]
      ++ lib.optionals (host.windowManager == "hyprland") [pkgs.hyprland];
    text =
      # bash
      ''
        # power-profiles-daemon has three profiles (performance, balanced, power-saver);
        # this marker distinguishes "very-light" from "light", which both use power-saver.
        STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/powermode-very-light"

        # Waybar's custom/powermode module refreshes on SIGRTMIN+11.
        refresh_waybar() {
          pkill -RTMIN+11 -x '\.?waybar(-wrapped)?' || true
        }

        current_mode() {
          local ppd
          ppd=$(powerprofilesctl get 2>/dev/null || echo "balanced")
          if [ "$ppd" = "power-saver" ] && [ -e "$STATE_FILE" ]; then
            echo "very-light"
          else
            if [ "$ppd" != "power-saver" ]; then
              rm -f "$STATE_FILE"
            fi
            echo "$ppd"
          fi
        }

        apply_hyprland() {
          ${lib.optionalString (host.windowManager == "hyprland") ''
          local mode="$1"
          if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            local sig
            sig=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance // empty' || true)
            if [ -z "$sig" ]; then
              return 0
            fi
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          fi

          local visuals="true"
          if [ "$mode" = "very-light" ]; then
            visuals="false"
          fi

          hyprctl eval "hl.config({ animations = { enabled = $visuals }, decoration = { blur = { enabled = $visuals }, shadow = { enabled = $visuals } } })" >/dev/null 2>&1 || return 0

          local monitors_json
          monitors_json=$(hyprctl monitors -j 2>/dev/null) || return 0

          local name target_mode pos scale transform lua_extra
          while IFS=$'\t' read -r name target_mode pos scale transform; do
            [ -n "$name" ] || continue
            lua_extra=""
            if [ "$transform" != "0" ]; then
              lua_extra=", transform = $transform"
            fi
            hyprctl eval "hl.monitor({ output = \"$name\", mode = \"$target_mode\", position = \"$pos\", scale = $scale$lua_extra })" >/dev/null 2>&1 || true
          done < <(printf '%s\n' "$monitors_json" | jq -r --arg target_mode "$mode" '
            .[]
            | select((.disabled | not) and (.name | startswith("eDP-")))
            | . as $m
            | ("\(.width)x\(.height)@") as $prefix
            | [
                (.availableModes // [])[]
                | select(startswith($prefix))
                | capture("^(?<mode>.+@(?<hz>[0-9]+(?:\\.[0-9]+)?))Hz$")
                | { mode, hz: (.hz | tonumber) }
              ]
            | if length == 0 then empty else . end
            | (
                if $target_mode == "very-light" then
                  (map(select(.hz <= 60.5)) | max_by(.hz)) // min_by(.hz)
                else
                  max_by(.hz)
                end
              ) as $chosen
            | select((($chosen.hz - $m.refreshRate) | fabs) >= 0.5)
            | [$m.name, $chosen.mode, "\($m.x)x\($m.y)", ($m.scale | tostring), ($m.transform | tostring)]
            | @tsv
          ')
        ''}
          : "$1"
        }

        case "''${1-}" in
        performance)
          rm -f "$STATE_FILE"
          powerprofilesctl set performance
          apply_hyprland full
          refresh_waybar
          ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Performance" "Max performance enabled"
          ;;
        auto)
          rm -f "$STATE_FILE"
          powerprofilesctl set balanced
          apply_hyprland full
          refresh_waybar
          ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Auto" "Balanced power and performance"
          ;;
        light)
          rm -f "$STATE_FILE"
          powerprofilesctl set power-saver
          apply_hyprland full
          refresh_waybar
          ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Light" "Power saving enabled"
          ;;
        very-light)
          touch "$STATE_FILE"
          powerprofilesctl set power-saver
          apply_hyprland very-light
          refresh_waybar
          ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Very Light" "Maximum power saving (60 Hz, visuals off)"
          ;;
        apply)
          if [ "$(current_mode)" = "very-light" ]; then
            apply_hyprland very-light
          else
            apply_hyprland full
          fi
          refresh_waybar
          ;;
        query)
          current_mode
          ;;
        waybar)
          if [ "$(current_mode)" = "very-light" ]; then
            echo '{"text":"","class":"very-light","tooltip":"<b>Power Mode: Very Light</b>\nPower saver · 60 Hz · visuals off\n\nClick to change"}'
          else
            echo '{"text":"","class":"inactive"}'
          fi
          ;;
        *)
          echo "Usage: powermode {performance|auto|light|very-light|apply|query|waybar}"
          echo "Current mode: $(current_mode)"
          exit 1
          ;;
        esac
      '';
  };
}
