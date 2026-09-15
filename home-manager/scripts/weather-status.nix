{pkgs, ...}: {
  weather-status =
    pkgs.writeShellScript "weather-status"
    # bash
    ''
      # Prints "<date>  <icon> <temp>°" for hyprlock / status bars.
      #
      # hyprlock runs its cmd[] children synchronously and refuses to exit while one
      # is still alive, so this must always return fast and always print something.
      # The last successful reading is cached and reused whenever wttr.in is down.
      CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/weather-status"

      raw=$(${pkgs.coreutils}/bin/timeout -k 1 3 ${pkgs.wttrbar}/bin/wttrbar --nerd --custom-indicator "{ICON} {temp_C}°" 2>/dev/null)
      weather=$(${pkgs.coreutils}/bin/printf '%s' "$raw" | ${pkgs.jq}/bin/jq -r '.text // empty' 2>/dev/null)
      tooltip=$(${pkgs.coreutils}/bin/printf '%s' "$raw" | ${pkgs.jq}/bin/jq -r '.tooltip // empty' 2>/dev/null)

      # wttrbar exits 0 on failure and reports it through the tooltip instead
      case "$tooltip" in
        "" | "cannot access wttr.in" | "invalid wttr.in response")
          weather=$(${pkgs.coreutils}/bin/cat "$CACHE" 2>/dev/null)
          ;;
        *)
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$CACHE")"
          ${pkgs.coreutils}/bin/printf '%s' "$weather" > "$CACHE"
          ;;
      esac

      date=$(${pkgs.coreutils}/bin/date +"%a, %b %d")

      if [ -n "$weather" ]; then
        echo "$date  $weather"
      else
        echo "$date"
      fi

      exit 0
    '';
}
