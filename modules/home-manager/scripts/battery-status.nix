{pkgs, ...}: {
  battery-status =
    pkgs.writeShellScript "battery-status"
    # bash
    ''
      for bat in /sys/class/power_supply/BAT*; do
          if [ -d "$bat" ]; then
              status=$(cat "$bat/status")
              capacity=$(cat "$bat/capacity")

              if [ "$status" = "Full" ] || { [ "$status" = "Unknown" ] && [ "$capacity" = "100" ]; }; then
                  echo "󱟢 Fully Charged"
              elif [ "$status" = "Charging" ]; then
                echo " $capacity%"
              else
                  if [ "$capacity" -le 20 ]; then
                    echo "󰁺 $capacity%"
                  elif [ "$capacity" -le 40 ]; then
                    echo "󰁼 $capacity%"
                  elif [ "$capacity" -le 60 ]; then
                    echo "󰁾 $capacity%"
                  elif [ "$capacity" -le 80 ]; then
                    echo "󰂀 $capacity%"
                  else
                    echo "󰂁 $capacity%"
                  fi
              fi
              exit 0
          fi
      done

      exit 0
    '';
}
