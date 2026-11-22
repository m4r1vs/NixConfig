{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  rofi-nightlight = helpers.mkScript {
    name = "rofi-nightlight";
    runtimeInputs = [
      pkgs.rofi
    ];
    text =
      # bash
      ''
        read -r mode cur_t cur_g s_temp _ s_elev s_phase <<<"$(${scripts.nightlight} status)"

        mark() {
          local label="$1"
          local active="$2"
          if [ "$active" = "1" ]; then
            printf '%s (Active)' "$label"
          else
            printf '%s' "$label"
          fi
        }

        opt_auto=$(mark "󰖨  Auto · Solar (''${s_phase}, ''${s_temp}K)" "$([ "$mode" = "auto" ] && echo 1 || echo 0)")
        opt_off=$(mark "󰌶  Off · Identity (6500K)" "$([ "$mode" = "off" ] && echo 1 || echo 0)")
        opt_mild=$(mark "󰖚  Mild · 5000K" "$([ "$mode" = "manual" ] && [ "$cur_t" -eq 5000 ] && echo 1 || echo 0)")
        opt_warm=$(mark "󰖔  Warm · 4200K" "$([ "$mode" = "manual" ] && [ "$cur_t" -eq 4200 ] && echo 1 || echo 0)")
        opt_night=$(mark "󰽥  Night · 3800K" "$([ "$mode" = "manual" ] && [ "$cur_t" -eq 3800 ] && echo 1 || echo 0)")
        opt_candle=$(mark "󰈸  Candle · 2800K" "$([ "$mode" = "manual" ] && [ "$cur_t" -eq 2800 ] && echo 1 || echo 0)")
        opt_warmer="󰃠  Warmer (−300K)"
        opt_cooler="󰃞  Cooler (+300K)"
        opt_dim="󰃟  Dim · 85% Gamma"
        opt_full="󰃠  Full · 100% Gamma"

        options=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s' \
          "$opt_auto" "$opt_off" "$opt_mild" "$opt_warm" "$opt_night" "$opt_candle" \
          "$opt_warmer" "$opt_cooler" "$opt_dim" "$opt_full")

        case "$mode" in
          auto)   mode_label="Auto · ''${cur_t}K (sun ''${s_elev}°)" ;;
          off)    mode_label="Off · 6500K" ;;
          manual) mode_label="Manual · ''${cur_t}K · ''${cur_g}%" ;;
          *)      mode_label="''${cur_t}K" ;;
        esac

        chosen=$(printf '%s\n' "$options" | rofi -dmenu -i -p "Night Light" \
          -theme-str "entry {placeholder:\"''${mode_label} — pick or type Kelvin...\";}window{padding: 32% 36%;}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 22;}") || exit 0

        [ -z "$chosen" ] && exit 0

        case "$chosen" in
          "$opt_auto")   ${scripts.nightlight} auto ;;
          "$opt_off")    ${scripts.nightlight} off ;;
          "$opt_mild")   ${scripts.nightlight} set 5000 ;;
          "$opt_warm")   ${scripts.nightlight} set 4200 ;;
          "$opt_night")  ${scripts.nightlight} set 3800 ;;
          "$opt_candle") ${scripts.nightlight} set 2800 ;;
          "$opt_warmer") ${scripts.nightlight} step -300 ;;
          "$opt_cooler") ${scripts.nightlight} step 300 ;;
          "$opt_dim")    ${scripts.nightlight} gamma 85 ;;
          "$opt_full")   ${scripts.nightlight} gamma 100 ;;
          *)
            # Allow typing an arbitrary Kelvin (e.g. "3400" or "3400K") or gamma ("80%")
            if [[ "$chosen" =~ ^[[:space:]]*([0-9]+)%[[:space:]]*$ ]]; then
              ${scripts.nightlight} gamma "''${BASH_REMATCH[1]}"
            elif [[ "$chosen" =~ ^[[:space:]]*([0-9]+)[Kk]?[[:space:]]*$ ]]; then
              ${scripts.nightlight} set "''${BASH_REMATCH[1]}"
            fi
            ;;
        esac
      '';
  };
}
