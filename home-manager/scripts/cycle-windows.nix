{pkgs, ...}: {
  cycle-windows = direction:
    pkgs.writeShellScript "cycle-windows-${direction}"
    ''
      # Get all windows in a predictable order (by workspace ID, then coordinates)
      windows=$(${pkgs.hyprland}/bin/hyprctl clients -j | ${pkgs.jq}/bin/jq -r 'map(select(.workspace.id > 0)) | sort_by(.workspace.id, .at[1], .at[0]) | .[].address')
      active=$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.address // empty')

      if [ -z "$windows" ]; then
        exit 0
      fi

      ${if direction == "prev" then "windows=$(echo \"$windows\" | ${pkgs.coreutils}/bin/tac)" else ""}

      if [ -z "$active" ]; then
        # If no window is active, focus the first one
        next_window=$(echo "$windows" | head -n1)
      else
        # Find the next window in the list after the active one
        next_window=$(echo "$windows" | ${pkgs.gnugrep}/bin/grep -A1 "$active" | tail -n1)

        # If we are at the end or grep didn't find the active window (e.g. it was closed), wrap around
        if [ "$next_window" == "$active" ] || [ -z "$next_window" ]; then
          next_window=$(echo "$windows" | head -n1)
        fi
      fi

      if [ -n "$next_window" ]; then
        ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow address:"$next_window"
      fi
    '';
}