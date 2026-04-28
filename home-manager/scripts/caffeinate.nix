{
  pkgs,
  scripts,
  ...
}: {
  caffeinate = pkgs.writeShellScript "caffeinate" ''
    # Query inhibitors via D-Bus for robust parsing
    GET_INHIBITORS() {
        ${pkgs.systemd}/bin/busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ListInhibitors --json=short | ${pkgs.jq}/bin/jq -c '.data[0]'
    }

    if [ "$1" = "toggle" ]; then
        if (GET_INHIBITORS | ${pkgs.jq}/bin/jq -e 'any(.[]; .[1] == "Nixos-Caffeinate")' > /dev/null); then
            ${pkgs.procps}/bin/pkill -f "systemd-inhibit --who=Nixos-Caffeinate"
            ${scripts.nixos-notify} -u low -e -t 3500 -h string:synchronous:caffeinate-script "Uncaffeinated" "Now I can fall asleep 󰒲 "
        else
            ${pkgs.systemd}/bin/systemd-inhibit --who=Nixos-Caffeinate --why="Caffeinate active" --what=idle:sleep:handle-lid-switch ${pkgs.coreutils}/bin/sleep infinity &
            ${scripts.nixos-notify} -u low -e -t 3500 -h string:synchronous:caffeinate-script "Caffeinated" "No more falling asleep!!"
        fi
    else
        INHIBITORS_JSON=$(GET_INHIBITORS)
        
        IS_CAFFEINATED=$(echo "$INHIBITORS_JSON" | ${pkgs.jq}/bin/jq -r 'any(.[]; .[1] == "Nixos-Caffeinate")')

        # Format inhibitors for tooltip
        TOOLTIP=$(echo "$INHIBITORS_JSON" | ${pkgs.jq}/bin/jq -r '
            map(select(.[3] == "block")) |
            if length > 0 then
                "<b>Active Inhibitors:</b>\n" + ([.[] | "• <b>\(.[1])</b> (\(.[0])): \(.[2])"] | join("\n"))
            else
                "No active inhibitors"
            end
        ')

        ICON="󰅶"
        if [ "$IS_CAFFEINATED" = "true" ]; then
            ICON="󰾪"
        fi

        ${pkgs.jq}/bin/jq -nc \
            --arg text "$ICON" \
            --arg tooltip "$TOOLTIP" \
            '{"text": $text, "tooltip": $tooltip}'
    fi
  '';
}
