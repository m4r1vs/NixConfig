{
  pkgs,
  scripts,
  ...
}: {
  rofi-powermode = pkgs.writeShellScript "rofi-powermode" ''
    # Options
    performance="󰓅 Performance"
    auto="󰾅 Auto"
    light="󰾆 Light"
    very_light=" Very Light"

    # Get current mode
    current_mode=$(${scripts.powermode} query)

    # Determine which one is currently selected for Rofi
    case "$current_mode" in
      performance)
        performance="󰓅 Performance (Active)"
        ;;
      balanced)
        auto="󰾅 Auto (Active)"
        ;;
      power-saver)
        light="󰾆 Light (Active)"
        ;;
      very-light)
        very_light=" Very Light (Active)"
        ;;
    esac

    options="$performance\n$auto\n$light\n$very_light"

    chosen="$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Power Mode" -theme-str "entry {placeholder:\"Select Power Profile...\";}window{padding: 40% 40%;}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 22;}")"

    case "$chosen" in
      "$performance")
        ${scripts.powermode} performance
        ;;
      "$auto")
        ${scripts.powermode} auto
        ;;
      "$light")
        ${scripts.powermode} light
        ;;
      "$very_light")
        ${scripts.powermode} very-light
        ;;
    esac
  '';
}
