{
  pkgs,
  scripts,
  ...
}: {
  rofi-wallpaper = pkgs.writeShellScript "rofi-wallpaper" ''
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    mkdir -p "$WALLPAPER_DIR"

    # Construct options with icons for rofi
    OPTIONS=""
    FILES=()
    for file in "$WALLPAPER_DIR"/*; do
        [ -e "$file" ] || continue
        filename=$(basename "$file")
        case "$filename" in
            *.jpg|*.jpeg|*.png|*.webp|*.gif|*.heic|*.HEIC)
                display_name=$(echo "$filename" | sed -E 's/\.[^.]+$//; s/[_-]/ /g')
                FILES+=("$filename")
                if [ -z "$OPTIONS" ]; then
                    OPTIONS="$display_name\0icon\x1f$file"
                else
                    OPTIONS="$OPTIONS\n$display_name\0icon\x1f$file"
                fi
                ;;
        esac
    done

    # Show rofi with icon support and a grid layout matching the emoji picker style
    # Lets Hyprland's "blur,rofi" layer rule work through the themed background
    CHOICE_INDEX=$(echo -e "$OPTIONS" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Wallpaper" \
        -format i \
        -show-icons \
        -theme-str "window { padding: 15% 25%; } listview { dynamic: true; columns: 3; lines: 4; spacing: 20px; layout: vertical; flow: horizontal; } element { orientation: vertical; padding: 10px; } element-icon { size: 200px; } element-text { enabled: true; horizontal-align: 0.5; } icon-current-entry { enabled: false; } inputbar { padding: 0 0 20px 0; }")

    if [ -z "$CHOICE_INDEX" ] || [ "$CHOICE_INDEX" -lt 0 ]; then
        exit 0
    fi

    CHOICE="''${FILES[$CHOICE_INDEX]}"
    WALLPAPER="$WALLPAPER_DIR/$CHOICE"
    if [ -f "$WALLPAPER" ]; then
        ${scripts.nixos-notify} -e -i "$WALLPAPER" -h string:synchronous:wallpaper-change -t 1800 "New Wallpaper:" "$CHOICE"
        ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type any --transition-fps 60 --transition-step 20 --transition-duration 1
    fi
  '';
}
