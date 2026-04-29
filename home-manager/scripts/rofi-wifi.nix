{
  pkgs,
  scripts,
  ...
}: {
  rofi-wifi = pkgs.writeShellScript "rofi-wifi" ''
    export PATH=''${pkgs.lib.makeBinPath [
      pkgs.networkmanager
      pkgs.rofi
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      pkgs.gnused
    ]}:$PATH

    notify="${scripts.nixos-notify} -e -u low -t 3500 -h string:synchronous:rofi-wifi"

    check_wifi_status() {
        status=$(nmcli radio wifi)
        if [ "$status" = "disabled" ]; then
            chosen=$(echo -e "󰤮 Enable Wi-Fi\n󰈆 Exit" | rofi -dmenu -i -p "Wi-Fi is Off" -theme-str 'window {width: 15em;} listview {lines: 2;}')
            if [ "$chosen" = "󰤮 Enable Wi-Fi" ]; then
                nmcli radio wifi on
                sleep 2
            else
                exit 0
            fi
        fi
    }

    show_menu() {
        check_wifi_status

        $notify "Scanning Wi-Fi..." "I'm going through all the frequencies!"

        # Rescan to get fresh list
        nmcli device wifi rescan >/dev/null 2>&1

        # Scan and get list
        # We use -t for terse output and -f to specify fields
        # SSID can contain colons, nmcli escapes them with \:
        # We use sed to replace non-escaped colons with | for safer parsing
        raw_list=$(nmcli -t -f IN-USE,SSID,SECURITY,BARS device wifi list | sed 's/\\:/\x01/g; s/:/|/g; s/\x01/:/g')

        # Process the list with gawk
        # We want to format it for rofi: "Icon SSID (Connected) LockIcon"
        # Deduplicate by SSID, prioritizing strongest signal or active connection
        formatted_list=$(echo "$raw_list" | gawk -F'|' '
        {
            in_use = $1
            ssid = $2
            security = $3
            bars = $4

            if (ssid == "") next;

            # Map bars to numeric strength for comparison
            strength = 0
            if (bars ~ /█/) strength = 4
            else if (bars ~ /▆/) strength = 3
            else if (bars ~ /▄/) strength = 2
            else if (bars ~ /▂/) strength = 1

            # Store the best entry for each SSID
            # Prioritize in_use == "*", then higher strength
            if (!(ssid in best_strength) || in_use == "*" || (best_in_use[ssid] != "*" && strength > best_strength[ssid])) {
                best_strength[ssid] = strength
                best_in_use[ssid] = in_use
                best_security[ssid] = security
                best_bars[ssid] = bars
            }
        }
        END {
            for (ssid in best_strength) {
                in_use = best_in_use[ssid]
                security = best_security[ssid]
                bars = best_bars[ssid]

                icon = "󰤨"
                if (bars ~ /█/) icon = "󰤨"
                else if (bars ~ /▆/) icon = "󰤥"
                else if (bars ~ /▄/) icon = "󰤢"
                else if (bars ~ /▂/) icon = "󰤟"
                else icon = "󰤯"

                lock = (security ~ /WPA|WEP/ ? " " : "")
                active = (in_use == "*" ? " (Connected)" : "")

                # Priority for sorting: Active (9), then strength (0-4)
                priority = (in_use == "*" ? 9 : best_strength[ssid])

                printf "%d|%s  %s%s%s\n", priority, icon, ssid, active, lock
            }
        }' | sort -t'|' -k1,1rn | cut -d'|' -f2-)

        # Add manual options
        options="$formatted_list\n󰤮 Disable Wi-Fi\n󰈆 Exit"

        chosen=$(echo -e "$options" | rofi -dmenu -i -p "Wi-Fi" -theme-str 'entry{placeholder:"󰖩  Search Networks...";} window{width: 30em;}')

        if [ -z "$chosen" ] || [ "$chosen" = "󰈆 Exit" ]; then
            exit 0
        fi

        if [ "$chosen" = "󰤮 Disable Wi-Fi" ]; then
            nmcli radio wifi off
            exit 0
        fi

        # Extract SSID
        # The line format is: "Icon  SSID (Connected) "
        # We need to strip the icon and the suffixes
        SSID=$(echo "$chosen" | sed -E 's/^[^ ]+  //; s/ \(Connected\)//; s/ //')

        if [ -z "$SSID" ]; then
            exit 0
        fi

        # Check if already connected to this one
        if echo "$chosen" | grep -q "(Connected)"; then
            $notify "Wi-Fi" "Already connected to $SSID"
            exit 0
        fi

        # Try to connect
        # Check if connection is already known
        if nmcli -t -f NAME connection show | grep -x "$SSID" >/dev/null; then
            $notify "Wi-Fi" "Connecting to known network: $SSID..."
            if nmcli connection up id "$SSID"; then
                $notify "Wi-Fi" "Connected to $SSID"
            else
                $notify "Wi-Fi" "Failed to connect to $SSID"
            fi
        else
            # New network, check if secure
            if echo "$chosen" | grep -q ""; then
                PASSWORD=$(rofi -dmenu -password -p "Password for $SSID" -theme-str 'window{width: 20em;} listview{enabled: false;}')
                if [ -z "$PASSWORD" ]; then
                    exit 0
                fi
                $notify "Wi-Fi" "Connecting to $SSID..."
                if nmcli device wifi connect "$SSID" password "$PASSWORD"; then
                    $notify "Wi-Fi" "Connected to $SSID"
                else
                    $notify "Wi-Fi" "Failed to connect to $SSID"
                fi
            else
                $notify "Wi-Fi" "Connecting to open network: $SSID..."
                if nmcli device wifi connect "$SSID"; then
                    $notify "Wi-Fi" "Connected to $SSID"
                else
                    $notify "Wi-Fi" "Failed to connect to $SSID"
                fi
            fi
        fi
    }

    show_menu
  '';
}
