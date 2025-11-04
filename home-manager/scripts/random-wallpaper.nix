{
  pkgs,
  scripts,
  ...
}: {
  random-wallpaper = directory:
    pkgs.writeShellScript "random-wallpaper"
    # bash
    ''
      WALLPAPER="$(find ${builtins.path {path = directory;}} -type f | shuf -n 1)"
      ${scripts.nixos-notify} -e -i "$WALLPAPER" -h string:synchronous:random-wallpaper -t 1800 "Now showing" "$(basename "$WALLPAPER")"
      ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type any --transition-fps 60 --transition-step 20 --transition-duration 1
    '';
}
