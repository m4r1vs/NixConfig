{
  pkgs,
  scripts,
  ...
}: {
  cleartext-wifi =
    pkgs.writeShellScript "cleartext-wifi"
    ''
      export PATH=${pkgs.lib.makeBinPath [pkgs.networkmanager pkgs.gnugrep pkgs.coreutils]}:$PATH

      # Get the name of the active Wi-Fi connection
      CON_NAME=$(nmcli -t -f ACTIVE,NAME,TYPE connection show | grep '^yes:.*:802-11-wireless' | cut -d: -f2)

      if [ -z "$CON_NAME" ]; then
        ${scripts.nixos-notify} -u low -e "󰤭 " "Not connected to any Wi-Fi"
      else
        # Get the password (PSK) for the connection
        # -s for secrets, -g for field
        PASSWORD=$(nmcli -s -g 802-11-wireless-security.psk connection show "$CON_NAME" 2>/dev/null)

        if [ -z "$PASSWORD" ]; then
          ${scripts.nixos-notify} -u low -e "󱛍  Name: $CON_NAME" "  Open or Passwordless"
        else
          ${scripts.nixos-notify} -u low -e -t 20000 "󱛍  Name: $CON_NAME" "  PW: $PASSWORD"
          echo "$PASSWORD" | ${pkgs.wl-clipboard}/bin/wl-copy
        fi
      fi
    '';
}
