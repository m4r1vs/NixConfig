{pkgs, ...}: {
  launch-once = {
    command,
    grep,
    useHypr ? false,
    toggle ? false,
  }:
    pkgs.writeShellScript "launch-once"
    (
      if useHypr
      then
        /*
        bash
        */
        if toggle
        then ''
          CLIENT=$(${pkgs.hyprland}/bin/hyprctl clients -j | ${pkgs.jq}/bin/jq -r ".[] | select(.initialClass == \"${grep}\" or .initialTitle == \"${grep}\" or .class == \"${grep}\")")
          if [ -n "$CLIENT" ]; then
            ADDR=$(echo "$CLIENT" | ${pkgs.jq}/bin/jq -r ".address")
            WORKSPACE=$(echo "$CLIENT" | ${pkgs.jq}/bin/jq -r ".workspace.id")
            CURRENT_WORKSPACE=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r ".[] | select(.focused == true) | .activeWorkspace.id")

            if [ "$WORKSPACE" = "$CURRENT_WORKSPACE" ]; then
              ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDR"
            else
              ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspace "$CURRENT_WORKSPACE,address:$ADDR"
              ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow address:$ADDR
            fi
            exit 0
          else
            ${command} &
          fi
        ''
        else ''
          CLIENT=$(${pkgs.hyprland}/bin/hyprctl clients -j | ${pkgs.jq}/bin/jq -r ".[] | select(.initialClass == \"${grep}\" or .initialTitle == \"${grep}\" or .class == \"${grep}\")")
          if [ -n "$CLIENT" ]; then
            exit 0
          else
            ${command} &
          fi
        ''
      else
        /*
        bash
        */
        ''
          if ${pkgs.procps}/bin/pgrep -f "${grep}" > /dev/null; then
            exit 0
          else
            ${command} &
            exit 0
          fi
        ''
    );
}