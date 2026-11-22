{
  pkgs,
  config,
  systemArgs,
  scripts,
  helpers,
  ...
}: let
  cfg = config.home-manager.users.${systemArgs.username}.services.configured.hyprsunset;
in {
  nightlight = helpers.mkScript {
    name = "nightlight";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hyprland
      pkgs.python3
    ];
    text =
      # bash
      ''
        STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/nightlight-state"
        LAST_FILE="''${XDG_RUNTIME_DIR:-/tmp}/nightlight-last"

        LAT="${toString cfg.latitude}"
        LNG="${toString cfg.longitude}"
        DAY_TEMP="${toString cfg.dayTemperature}"
        NIGHT_TEMP="${toString cfg.nightTemperature}"
        MIN_ELEV="${toString cfg.minElevation}"
        MAX_ELEV="${toString cfg.maxElevation}"
        NIGHT_GAMMA="${toString cfg.nightGamma}"

        # Ensure hyprctl can find the compositor when invoked from a systemd timer or sleep hook
        ensure_hypr_env() {
          if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            local sig
            sig=$(hyprctl instances -j 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["instance"] if d else "")' 2>/dev/null || true)
            [ -n "$sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          fi
        }

        wait_for_hyprsunset() {
          local tries=0
          while [ "$tries" -lt 20 ]; do
            if hyprctl hyprsunset temperature >/dev/null 2>&1; then
              return 0
            fi
            tries=$((tries + 1))
            sleep 0.15
          done
          return 1
        }

        # Prints: "<target_temp> <target_gamma> <elevation_deg> <phase>"
        solar_target() {
          python3 - "$LAT" "$LNG" "$DAY_TEMP" "$NIGHT_TEMP" "$MIN_ELEV" "$MAX_ELEV" "$NIGHT_GAMMA" <<'PY'
        import datetime, math, sys

        lat = float(sys.argv[1])
        lng = float(sys.argv[2])
        day_temp = int(sys.argv[3])
        night_temp = int(sys.argv[4])
        min_elev = float(sys.argv[5])
        max_elev = float(sys.argv[6])
        night_gamma = int(sys.argv[7])

        now = datetime.datetime.now(datetime.timezone.utc)
        # Julian day since J2000.0 (NOAA solar position approximation, <0.5 deg error)
        doy = now.timetuple().tm_yday
        frac_hour = now.hour + now.minute / 60.0 + now.second / 3600.0
        gamma_yr = 2.0 * math.pi / 365.0 * (doy - 1 + (frac_hour - 12.0) / 24.0)

        eqtime = 229.18 * (
            0.000075
            + 0.001868 * math.cos(gamma_yr)
            - 0.032077 * math.sin(gamma_yr)
            - 0.014615 * math.cos(2 * gamma_yr)
            - 0.040849 * math.sin(2 * gamma_yr)
        )
        decl = (
            0.006918
            - 0.399912 * math.cos(gamma_yr)
            + 0.070257 * math.sin(gamma_yr)
            - 0.006758 * math.cos(2 * gamma_yr)
            + 0.000907 * math.sin(2 * gamma_yr)
            - 0.002697 * math.cos(3 * gamma_yr)
            + 0.00148 * math.sin(3 * gamma_yr)
        )

        tst = (frac_hour * 60.0 + eqtime + 4.0 * lng) % 1440.0
        ha_deg = tst / 4.0 - 180.0
        ha = math.radians(ha_deg)
        lat_r = math.radians(lat)

        sin_elev = math.sin(lat_r) * math.sin(decl) + math.cos(lat_r) * math.cos(decl) * math.cos(ha)
        elev = math.degrees(math.asin(max(-1.0, min(1.0, sin_elev))))

        if elev >= max_elev:
            t = 0.0
            phase = "Day"
        elif elev <= min_elev:
            t = 1.0
            phase = "Night"
        else:
            linear = (max_elev - elev) / (max_elev - min_elev)
            # Raised-cosine ease for a smooth twilight ramp
            t = 0.5 * (1.0 - math.cos(math.pi * linear))
            phase = "Twilight"

        raw_temp = day_temp - t * (day_temp - night_temp)
        temp = int(round(raw_temp / 50.0) * 50)
        temp = max(2000, min(day_temp, temp))

        raw_gamma = 100.0 - t * (100.0 - night_gamma)
        gamma_pct = int(round(raw_gamma))
        gamma_pct = max(50, min(100, gamma_pct))

        print(f"{temp} {gamma_pct} {elev:.1f} {phase}")
        PY
        }

        read_state() {
          if [ -r "$STATE_FILE" ]; then
            cat "$STATE_FILE"
          else
            echo "auto"
          fi
        }

        apply_ctm() {
          local temp="$1"
          local gamma="$2"
          local force="''${3:-0}"
          local sig="''${temp}:''${gamma}"

          if [ "$force" != "1" ] && [ -r "$LAST_FILE" ] && [ "$(cat "$LAST_FILE")" = "$sig" ]; then
            return 0
          fi

          if [ "$temp" -ge "$DAY_TEMP" ] && [ "$gamma" -ge 100 ]; then
            hyprctl hyprsunset identity >/dev/null
          else
            if [ "$temp" -ge "$DAY_TEMP" ]; then
              hyprctl hyprsunset identity >/dev/null
            else
              hyprctl hyprsunset temperature "$temp" >/dev/null
            fi
            hyprctl hyprsunset gamma "$gamma" >/dev/null
          fi
          printf '%s\n' "$sig" > "$LAST_FILE"
        }

        notify() {
          ${scripts.nixos-notify} -u low -e -t 2400 -h string:synchronous:nightlight "$1" "$2"
        }

        current_gamma() {
          local g
          g=$(hyprctl hyprsunset gamma 2>/dev/null | python3 -c 'import re,sys; m=re.search(r"([0-9]+(?:\.[0-9]+)?)", sys.stdin.read()); print(int(round(float(m.group(1)))) if m else 100)' 2>/dev/null || echo 100)
          echo "$g"
        }

        current_temp() {
          local t
          t=$(hyprctl hyprsunset temperature 2>/dev/null | python3 -c 'import re,sys; m=re.search(r"([0-9]+)", sys.stdin.read()); print(int(m.group(1)) if m else 6500)' 2>/dev/null || echo 6500)
          echo "$t"
        }

        ensure_hypr_env

        cmd="''${1:-status}"
        case "$cmd" in
          sync)
            wait_for_hyprsunset || exit 0
            state=$(read_state)
            read -r mode val1 val2 <<<"$state"
            case "$mode" in
              off)
                apply_ctm "$DAY_TEMP" 100
                ;;
              manual)
                apply_ctm "''${val1:-$NIGHT_TEMP}" "''${val2:-100}"
                ;;
              *)
                read -r s_temp s_gamma _ _ <<<"$(solar_target)"
                apply_ctm "$s_temp" "$s_gamma"
                ;;
            esac
            ;;
          auto)
            wait_for_hyprsunset || exit 1
            printf 'auto\n' > "$STATE_FILE"
            read -r s_temp s_gamma _ s_phase <<<"$(solar_target)"
            apply_ctm "$s_temp" "$s_gamma" 1
            if [ "$s_temp" -ge "$DAY_TEMP" ]; then
              notify "Night Light · Auto" "''${s_phase} (Identity · ''${DAY_TEMP}K)"
            else
              notify "Night Light · Auto" "''${s_phase} (''${s_temp}K · ''${s_gamma}% gamma)"
            fi
            ;;
          off)
            wait_for_hyprsunset || exit 1
            printf 'off\n' > "$STATE_FILE"
            apply_ctm "$DAY_TEMP" 100 1
            notify "Night Light · Off" "Identity (''${DAY_TEMP}K)"
            ;;
          set)
            wait_for_hyprsunset || exit 1
            target="''${2:?temperature required}"
            # Strip trailing K/k if entered manually
            target="''${target%[Kk]}"
            if ! [[ "$target" =~ ^[0-9]+$ ]]; then
              notify "Night Light" "Invalid temperature: ''${2}"
              exit 1
            fi
            if [ "$target" -lt 1500 ]; then target=1500; fi
            if [ "$target" -gt 6500 ]; then target=6500; fi
            gamma="''${3:-$(current_gamma)}"
            printf 'manual %s %s\n' "$target" "$gamma" > "$STATE_FILE"
            apply_ctm "$target" "$gamma" 1
            notify "Night Light · Manual" "''${target}K · ''${gamma}% gamma"
            ;;
          gamma)
            wait_for_hyprsunset || exit 1
            target_g="''${2:?gamma percent required}"
            target_g="''${target_g%\%}"
            if ! [[ "$target_g" =~ ^[0-9]+$ ]]; then
              notify "Night Light" "Invalid gamma: ''${2}"
              exit 1
            fi
            if [ "$target_g" -lt 40 ]; then target_g=40; fi
            if [ "$target_g" -gt 100 ]; then target_g=100; fi
            temp=$(current_temp)
            printf 'manual %s %s\n' "$temp" "$target_g" > "$STATE_FILE"
            apply_ctm "$temp" "$target_g" 1
            notify "Night Light · Gamma" "''${temp}K · ''${target_g}% gamma"
            ;;
          step)
            wait_for_hyprsunset || exit 1
            delta="''${2:?delta required}"
            temp=$(current_temp)
            gamma=$(current_gamma)
            next=$((temp + delta))
            if [ "$next" -lt 1500 ]; then next=1500; fi
            if [ "$next" -gt "$DAY_TEMP" ]; then next="$DAY_TEMP"; fi
            printf 'manual %s %s\n' "$next" "$gamma" > "$STATE_FILE"
            apply_ctm "$next" "$gamma" 1
            notify "Night Light · Manual" "''${next}K · ''${gamma}% gamma"
            ;;
          status)
            state=$(read_state)
            read -r mode _ _ <<<"$state"
            read -r s_temp s_gamma s_elev s_phase <<<"$(solar_target)"
            cur_t=$(current_temp)
            cur_g=$(current_gamma)
            printf '%s %s %s %s %s %s %s\n' "$mode" "$cur_t" "$cur_g" "$s_temp" "$s_gamma" "$s_elev" "$s_phase"
            ;;
          *)
            echo "Usage: nightlight {sync|auto|off|set <kelvin> [gamma]|gamma <percent>|step <+/-delta>|status}" >&2
            exit 1
            ;;
        esac
      '';
  };
}
