{
  pkgs,
  scripts,
  ...
}: {
  random-wallpaper = directory:
    pkgs.writeShellScript "random-wallpaper"
    # bash
    ''
      WALLPAPER="$(find ${builtins.path {path = directory;}} -type f | ${pkgs.coreutils}/bin/shuf -n 1)"
      osascript <<EOF
      tell application "System Events"
          set desktopCount to count of desktops
          repeat with i from 1 to desktopCount
              set picture of desktop i to POSIX file "$WALLPAPER"
          end repeat
      end tell
      EOF
      WALLPAPER_NAME="$(basename "$WALLPAPER")"
      ${scripts.custom-wallpaper-theme} "$WALLPAPER_NAME"
    '';
}
