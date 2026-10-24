{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  netbird-vpn = helpers.mkScript {
    name = "netbird-vpn";
    runtimeInputs = [pkgs.coreutils pkgs.jq pkgs.procps];
    text =
      # bash
      ''
        # The system wrapper from services.netbird knows the daemon socket and
        # our management URL; a plain pkgs.netbird would talk to the wrong socket.
        netbird=/run/current-system/sw/bin/netbird

        # Waybar's custom/netbird module refreshes on SIGRTMIN+10
        refresh_waybar() {
            pkill -RTMIN+10 -x '\.?waybar(-wrapped)?' || true
        }

        # The CLI retries an unreachable daemon for ~10s, so cap it
        daemon_status() {
            timeout 3 "$netbird" status --json 2>/dev/null | jq -r '.daemonStatus' || echo "Unreachable"
        }

        disconnect() {
            "$netbird" down > /dev/null 2>&1 || true
            refresh_waybar
            ${scripts.nixos-notify} -u low -e -t 3500 -h string:synchronous:netbird-vpn "NetBird disconnected" "Internal services are no longer reachable"
        }

        connect() {
            # Blocks until connected; opens the SSO login in the browser if needed
            if "$netbird" up > /dev/null 2>&1; then
                refresh_waybar
                ${scripts.nixos-notify} -u low -e -t 3500 -h string:synchronous:netbird-vpn "NetBird connected" "Internal services are reachable"
            else
                ${scripts.nixos-notify} -u normal -t 10000 -h string:synchronous:netbird-vpn "NetBird failed to connect" "Status: $(daemon_status)"
            fi
        }

        case "''${1-}" in
            toggle)
                if [ "$(daemon_status)" = "Connected" ]; then disconnect; else connect; fi
                ;;
            down)
                disconnect
                ;;
            *)
                # Waybar hides the module while text is empty, i.e. when not connected
                if ! status=$(timeout 3 "$netbird" status --json 2>/dev/null); then
                    echo '{"text": "", "class": "disconnected"}'
                    exit 0
                fi
                echo "$status" | jq -c '
                    if .daemonStatus == "Connected" then {
                        text: "󰏒",
                        class: "connected",
                        tooltip: "<b>NetBird connected</b>\n\(.fqdn)\n\(.netbirdIp)\nPeers: \(.peers.connected)/\(.peers.total)\nManagement: \(.management.url)\n\nClick to disconnect"
                    } else {
                        text: "",
                        class: "disconnected",
                        tooltip: "NetBird: \(.daemonStatus)"
                    } end'
                ;;
        esac
      '';
  };
}
