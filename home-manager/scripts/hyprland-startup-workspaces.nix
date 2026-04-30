{
  pkgs,
  scripts,
  lib,
  ...
}: {
  hyprland-startup-workspaces =
    pkgs.writeShellScript "hyprland-startup-workspaces"
    # bash
    ''
      hour=$(${pkgs.coreutils}/bin/date +%H)

      if (( hour >= 5 && hour < 12 )); then
        WELCOME_STRING="Good Morning  "
      elif (( hour >= 12 && hour < 18 )); then
        WELCOME_STRING="Good Afternoon  "
      elif (( hour >= 18 && hour < 23 )); then
        WELCOME_STRING="Good Evening 󰖚 "
      elif (( hour >= 23 || hour < 5 )); then
        WELCOME_STRING="Hello, Nightowl 󰖔 "
      else
        WELCOME_STRING="Hello, Time-traveller  "
      fi

      # Wait until keyring is unlocked
      until ${pkgs.dbus}/bin/dbus-send --print-reply --dest=org.freedesktop.secrets \
        /org/freedesktop/secrets/aliases/default \
        org.freedesktop.DBus.Properties.Get \
        string:org.freedesktop.Secret.Collection \
        string:Locked 2>/dev/null | grep -q "boolean false"; do
        ${scripts.nixos-notify} -u low -e -t 12000 -h string:synchronous:startup-script "$WELCOME_STRING" "Please unlock the keyring so I can get everything running."
        sleep 0.5
      done

      ${scripts.nixos-notify} -u low -e -t 12000 -h string:synchronous:startup-script "$WELCOME_STRING" "Let me get everything running for you..."

      hyprctl dispatch exec "${lib.getExe pkgs.signal-desktop} --ozone-platform-hint=auto"
      hyprctl dispatch exec "${lib.getExe pkgs.whatsapp-electron} --ozone-platform-hint=auto"
      hyprctl dispatch exec "${lib.getExe pkgs.obsidian} --ozone-platform-hint=auto"
      hyprctl dispatch exec "${lib.getExe pkgs.ghostty}"
      hyprctl dispatch exec "${lib.getExe pkgs.ghostty} --class=ghostty.spotify_player -e ${pkgs.spotify-player}/bin/spotify_player"
      hyprctl dispatch exec "${lib.getExe pkgs.brave} --profile-directory=Default --ozone-platform-hint=auto --enable-features=TouchpadOverscrollHistoryNavigation"

      sleep 2
      hyprctl dispatch workspace 2
      sleep 2
      hyprctl dispatch workspace 3
      sleep 2
      hyprctl dispatch workspace 9

      sleep 2

      hyprctl dispatch workspace 1
      ${scripts.nixos-notify} -u low -e -t 3000 -h string:synchronous:startup-script "You're ready to go 󱓟 "

      exit 0
    '';
}
