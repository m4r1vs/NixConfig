{
  pkgs,
  scripts,
  ...
}: {
  caffeinate = pkgs.writeShellScript "caffeinate" ''
    # Waybar's custom/caffeinate module refreshes on SIGRTMIN+8. waybar is
    # wrapped (.waybar-wrapped), and a plain `pkill waybar` would also hit waybar-mpris.
    refresh_waybar() {
        ${pkgs.procps}/bin/pkill -RTMIN+8 -x '\.?waybar(-wrapped)?' || true
    }

    list_inhibitors() {
        ${pkgs.systemd}/bin/busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ListInhibitors --json=short
    }

    if [ "''${1-}" = "toggle" ]; then
        if ${pkgs.procps}/bin/pgrep -f "systemd-inhibit --who=Nixos-Caffeinate" > /dev/null; then
            ${pkgs.procps}/bin/pkill -f "systemd-inhibit --who=Nixos-Caffeinate"
            # logind releases the lock asynchronously once the fd is closed
            sleep 0.1
            refresh_waybar
            ${scripts.nixos-notify} -u low -e -t 3500 -h string:synchronous:caffeinate-script "Uncaffeinated" "Now I can fall asleep 󰒲 "
        else
            # Signal waybar from inside the inhibited command, so the lock already exists
            ${pkgs.systemd}/bin/systemd-inhibit --who=Nixos-Caffeinate --why="Caffeinate active" --what=idle:sleep:handle-lid-switch \
                ${pkgs.bash}/bin/sh -c "${pkgs.procps}/bin/pkill -RTMIN+8 -x '\.?waybar(-wrapped)?'; exec ${pkgs.coreutils}/bin/sleep infinity" &
            ${scripts.nixos-notify} -u low -e -t 3500 -h string:synchronous:caffeinate-script "Caffeinated" "No more falling asleep!!"
        fi
    else
        list_inhibitors | ${pkgs.jq}/bin/jq -c '.data[0] as $i | {
            text: (if any($i[]; .[1] == "Nixos-Caffeinate") then "󰾪" else "󰅶" end),
            tooltip: ($i | map(select(.[3] == "block")) |
                if length > 0 then
                    "<b>Active Inhibitors:</b>\n" + (map("• <b>\(.[1])</b> (\(.[0])): \(.[2])") | join("\n"))
                else
                    "No active inhibitors"
                end)
        }'
    fi
  '';
}
