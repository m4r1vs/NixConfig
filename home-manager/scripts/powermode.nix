{
  pkgs,
  scripts,
  ...
}: {
  powermode = pkgs.writeShellScript "powermode" ''
    POWERPROFILESCTL=${pkgs.power-profiles-daemon}/bin/powerprofilesctl
    HYPRCTL=${pkgs.hyprland}/bin/hyprctl
    JQ=${pkgs.jq}/bin/jq
    PIDOF=${pkgs.procps}/bin/pidof
    ANIMATION_STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/powermode-hypr-animations"

    hypr_running() {
      $PIDOF Hyprland >/dev/null 2>&1
    }

    restore_hypr_animations() {
      if ! hypr_running; then
        return
      fi

      target=1
      if [ -f "$ANIMATION_STATE_FILE" ]; then
        target=$(cat "$ANIMATION_STATE_FILE")
        rm -f "$ANIMATION_STATE_FILE"
      fi

      $HYPRCTL keyword animations:enabled "$target" >/dev/null 2>&1 || true
    }

    disable_hypr_animations() {
      if ! hypr_running; then
        return
      fi

      if [ ! -f "$ANIMATION_STATE_FILE" ]; then
        current=$($HYPRCTL -j getoption animations:enabled 2>/dev/null | $JQ -r '.int // empty')
        if [ -n "$current" ]; then
          echo "$current" > "$ANIMATION_STATE_FILE"
        fi
      fi

      $HYPRCTL keyword animations:enabled 0 >/dev/null 2>&1 || true
    }

    case "$1" in
    performance)
      $POWERPROFILESCTL set performance
      restore_hypr_animations
      ${scripts.nixos-notify} -e -h string:synchronous:powermode-changed "Power Mode: Performance" "Max performance enabled"
      ;;
    auto)
      $POWERPROFILESCTL set balanced
      restore_hypr_animations
      ${scripts.nixos-notify} -e -h string:synchronous:powermode-changed "Power Mode: Auto" "Balanced power and performance"
      ;;
    light)
      $POWERPROFILESCTL set power-saver
      restore_hypr_animations
      ${scripts.nixos-notify} -e -h string:synchronous:powermode-changed "Power Mode: Light" "Maximum power saving"
      ;;
    ultralight)
      $POWERPROFILESCTL set power-saver
      disable_hypr_animations
      ${scripts.nixos-notify} -e -h string:synchronous:powermode-changed "Power Mode: Ultralight" "Animations disabled for maximum power saving"
      ;;
    query)
      current_mode=$($POWERPROFILESCTL get)

      if [ "$current_mode" = "power-saver" ] && hypr_running; then
        animations_enabled=$($HYPRCTL -j getoption animations:enabled 2>/dev/null | $JQ -r '.int // empty')
        if [ "$animations_enabled" = "0" ]; then
          echo "ultralight"
          exit 0
        fi
      fi

      echo "$current_mode"
      ;;
    *)
      echo "Usage: powermode {performance|auto|light|ultralight|query}"
      echo "Current mode: $($POWERPROFILESCTL get)"
      exit 1
      ;;
    esac
  '';
}
