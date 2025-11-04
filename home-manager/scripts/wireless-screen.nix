{
  pkgs,
  scripts,
  ...
}: {
  wireless-screen =
    pkgs.writeShellScript "wireless-screen"
    ''
      MON_NAME="HEADLESS"

      ${pkgs.hyprland}/bin/hyprctl monitors | grep -q "$MON_NAME"

      if [[ $? -eq 0 ]]; then
        ${pkgs.hyprland}/bin/hyprctl output destroy $MON_NAME
        ${scripts.nixos-notify} -e -t 2000 "Destroyed $MON_NAME screen" "and enabling Firewall..."
        systemctl start firewall
        exit 0
      fi

      OUTPUT="$(${pkgs.hyprland}/bin/hyprctl output create auto $MON_NAME)"

      if [[ $? -ne 0 ]]; then
        ${scripts.nixos-notify} -e -t 2000 "Failed to create $MON_NAME screen:" "$OUTPUT"
        exit 0
      fi

      RESPONSE="$(${scripts.nixos-notify} -e -t 3000 --action="FHD=1080p" --action="WQHD=1440p" --action="UHD=2160p" "Created Screen: $MON_NAME in 1080p@60hz (Scale 2x)" "Pick a different resolution at 1x scale:")"

      if [[ "$RESPONSE" == *"FHD"* ]]; then
        ${pkgs.hyprland}/bin/hyprctl keyword monitor $MON_NAME,1920x1080@60,auto,1
      elif [[ "$RESPONSE" == *"WQHD"* ]]; then
        ${pkgs.hyprland}/bin/hyprctl keyword monitor $MON_NAME,2560x1440@60,auto,1
      elif [[ "$RESPONSE" == *"UHD"* ]]; then
        ${pkgs.hyprland}/bin/hyprctl keyword monitor $MON_NAME,3840x2160@60,auto,1
      fi

      ${scripts.nixos-notify} -e -t 2000 "Disabling Firewall for now..."
      systemctl stop firewall

      ${pkgs.gnome-network-displays}/bin/gnome-network-displays &
    '';
}
