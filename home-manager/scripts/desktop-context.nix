/*
Desktop context CLI for hey-computer (`selection`, `clipboard`, `capture`, `copy`, `paste`).
Exposed on the agent's PATH via `programs.hey-computer.extraPackages` so voice
(`SUPER+v` / `SUPER+ALT+v`) and typed (`SUPER+a`) requests can read selection,
clipboard text or images, capture a screen region/window/monitor as a PNG for
`read_file`, and copy or paste results back into the active window.
*/
{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  desktop-context = helpers.mkScript {
    name = "desktop-context";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.grim
      pkgs.hyprland
      pkgs.hyprpicker
      pkgs.jq
      pkgs.slurp
      pkgs.systemd
      pkgs.wl-clipboard
    ];
    text =
      # bash
      ''
        max_bytes=65536
        capture_dir="''${XDG_RUNTIME_DIR:-/tmp}/hey-computer-captures"

        die() {
          printf '%s\n' "$*" >&2
          exit 1
        }

        use_live_instance() {
          local instances sig
          instances=$(hyprctl instances -j 2>/dev/null) || die "Cannot list running Hyprland instances."
          sig=$(jq -r --arg sig "''${HYPRLAND_INSTANCE_SIGNATURE:-}" --arg wl "''${WAYLAND_DISPLAY:-}" \
            '(map(select(.instance == $sig)) + map(select(.wl_socket == $wl)) + .)[0].instance // empty' <<<"$instances")
          [ -n "$sig" ] || die "Hyprland is not running."
          export HYPRLAND_INSTANCE_SIGNATURE="$sig"
        }

        ensure_capture_dir() {
          mkdir -p "$capture_dir"
          chmod 700 "$capture_dir"
        }

        prune_captures() {
          ensure_capture_dir
          find "$capture_dir" -maxdepth 1 -type f -mmin +10 -delete 2>/dev/null || true
          find "$capture_dir" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null \
            | sort -rn | tail -n +6 | cut -d' ' -f2- | xargs -r rm -f -- 2>/dev/null || true
        }

        emit_bounded_text() {
          local tag="$1"
          local file="$2"
          local size
          size=$(wc -c < "$file")
          printf '<%s>\n' "$tag"
          if [ "$size" -gt "$max_bytes" ]; then
            head -c "$max_bytes" "$file"
            printf '\n[truncated: showing first %s of %s bytes]\n' "$max_bytes" "$size"
          else
            cat "$file"
            printf '\n'
          fi
          printf '</%s>\n' "$tag"
        }

        read_selection() {
          local types tmp
          types=$(wl-paste --primary --list-types 2>/dev/null || true)
          [ -n "$types" ] || die "Primary selection is empty."

          tmp=$(mktemp "''${XDG_RUNTIME_DIR:-/tmp}/hey-sel.XXXXXX")
          chmod 600 "$tmp"
          trap 'rm -f "$tmp"' RETURN

          wl-paste --primary --no-newline > "$tmp" 2>/dev/null || true
          [ -s "$tmp" ] || die "Primary selection is empty."
          emit_bounded_text "untrusted_selection" "$tmp"
        }

        read_clipboard() {
          local types img_mime ext out tmp
          types=$(wl-paste --list-types 2>/dev/null || true)
          [ -n "$types" ] || die "Clipboard is empty."

          if ! printf '%s\n' "$types" | grep -q '^text/plain'; then
            img_mime=""
            ext=""
            if printf '%s\n' "$types" | grep -qx 'image/png'; then
              img_mime="image/png"
              ext="png"
            elif printf '%s\n' "$types" | grep -qx 'image/jpeg'; then
              img_mime="image/jpeg"
              ext="jpg"
            elif printf '%s\n' "$types" | grep -qx 'image/webp'; then
              img_mime="image/webp"
              ext="webp"
            fi

            if [ -n "$img_mime" ]; then
              prune_captures
              out="$capture_dir/clipboard-$(date +%Y%m%d-%H%M%S)-$$.$ext"
              wl-paste --type "$img_mime" > "$out" 2>/dev/null || {
                rm -f "$out"
                die "Failed to read image from clipboard."
              }
              [ -s "$out" ] || {
                rm -f "$out"
                die "Clipboard image is empty."
              }
              chmod 600 "$out"
              printf 'IMAGE_PATH: %s\n' "$out"
              return 0
            fi
          fi

          tmp=$(mktemp "''${XDG_RUNTIME_DIR:-/tmp}/hey-clip-read.XXXXXX")
          chmod 600 "$tmp"
          trap 'rm -f "$tmp"' RETURN

          wl-paste --no-newline > "$tmp" 2>/dev/null || true
          [ -s "$tmp" ] || die "Clipboard is empty."
          emit_bounded_text "untrusted_clipboard" "$tmp"
        }

        capture_region() {
          use_live_instance
          prune_captures
          local out picker_pid=""
          out="$capture_dir/region-$(date +%Y%m%d-%H%M%S)-$$.png"

          cleanup_picker() {
            if [ -n "$picker_pid" ]; then
              kill "$picker_pid" 2>/dev/null || true
              wait "$picker_pid" 2>/dev/null || true
              picker_pid=""
            fi
          }
          trap cleanup_picker EXIT INT TERM HUP

          hyprpicker -r -z >/dev/null 2>&1 &
          picker_pid=$!
          sleep 0.2

          local geom=""
          if ! geom=$(timeout 40 slurp -d 2>/dev/null) || [ -z "$geom" ]; then
            cleanup_picker
            trap - EXIT INT TERM HUP
            die "Screenshot cancelled by user."
          fi

          if ! grim -g "$geom" "$out" 2>/dev/null; then
            rm -f "$out"
            cleanup_picker
            trap - EXIT INT TERM HUP
            die "Failed to capture screen region."
          fi

          cleanup_picker
          trap - EXIT INT TERM HUP
          [ -s "$out" ] || {
            rm -f "$out"
            die "Captured screenshot is empty."
          }
          chmod 600 "$out"
          printf 'IMAGE_PATH: %s\n' "$out"
        }

        capture_window() {
          use_live_instance
          prune_captures
          local active monitors geom out
          active=$(hyprctl -j activewindow 2>/dev/null) || die "Cannot query active window."
          monitors=$(hyprctl -j monitors 2>/dev/null) || die "Cannot query monitors."

          geom=$(jq -rn --argjson win "$active" --argjson mons "$monitors" '
            if ($win.address // "") == "" or ($win.size[0] // 0) <= 0 or ($win.size[1] // 0) <= 0 then
              empty
            else
              ($mons | map({
                x0: .x,
                y0: .y,
                x1: (.x + (if (.transform % 2 == 0) then (.width / .scale) else (.height / .scale) end | round)),
                y1: (.y + (if (.transform % 2 == 0) then (.height / .scale) else (.width / .scale) end | round))
              })) as $bounds |
              ($bounds | map(.x0) | min) as $min_x |
              ($bounds | map(.y0) | min) as $min_y |
              ($bounds | map(.x1) | max) as $max_x |
              ($bounds | map(.y1) | max) as $max_y |
              ([$win.at[0], $min_x] | max) as $x0 |
              ([$win.at[1], $min_y] | max) as $y0 |
              ([($win.at[0] + $win.size[0]), $max_x] | min) as $x1 |
              ([($win.at[1] + $win.size[1]), $max_y] | min) as $y1 |
              if ($x1 - $x0) > 0 and ($y1 - $y0) > 0 then
                "\($x0),\($y0) \($x1 - $x0)x\($y1 - $y0)"
              else
                empty
              end
            end
          ')
          [ -n "$geom" ] || die "No focused window to capture."

          out="$capture_dir/window-$(date +%Y%m%d-%H%M%S)-$$.png"
          grim -g "$geom" "$out" 2>/dev/null || {
            rm -f "$out"
            die "Failed to capture active window."
          }
          [ -s "$out" ] || {
            rm -f "$out"
            die "Captured screenshot is empty."
          }
          chmod 600 "$out"
          printf 'IMAGE_PATH: %s\n' "$out"
        }

        capture_screen() {
          use_live_instance
          prune_captures
          local mon out
          mon=$(hyprctl -j monitors 2>/dev/null | jq -r '(map(select(.focused)) + .)[0].name // empty')
          [ -n "$mon" ] || die "Cannot determine focused monitor."

          out="$capture_dir/screen-$(date +%Y%m%d-%H%M%S)-$$.png"
          grim -o "$mon" "$out" 2>/dev/null || {
            rm -f "$out"
            die "Failed to capture monitor $mon."
          }
          [ -s "$out" ] || {
            rm -f "$out"
            die "Captured screenshot is empty."
          }
          chmod 600 "$out"
          printf 'IMAGE_PATH: %s\n' "$out"
        }

        COPIED_CHARS=0
        copy_stdin() {
          local tmp
          tmp=$(mktemp "''${XDG_RUNTIME_DIR:-/tmp}/hey-clip-write.XXXXXX")
          chmod 600 "$tmp"
          cat > "$tmp"
          if [ ! -s "$tmp" ]; then
            rm -f "$tmp"
            die "Nothing to copy (empty input)."
          fi
          COPIED_CHARS=$(wc -m < "$tmp")
          # Run wl-copy inside a transient user scope so its background clipboard
          # owner outlives both the agent's shell command and daemon restarts,
          # and never holds stdout/stderr open.
          systemd-run --user --scope --quiet --collect -- \
            sh -c '${pkgs.wl-clipboard}/bin/wl-copy < "$1" >/dev/null 2>&1; rm -f "$1"' _ "$tmp"
          ${helpers.playSound "clipboard"}
        }

        paste_stdin() {
          copy_stdin
          use_live_instance
          local active addr win_class win_title
          active=$(hyprctl -j activewindow 2>/dev/null || printf '{}')
          addr=$(jq -r '.address // empty' <<<"$active")
          if [ -z "$addr" ] || [ "$addr" = "0x0" ]; then
            printf 'Copied %s characters to clipboard (no focused window to paste into).\n' "$COPIED_CHARS"
            return 0
          fi

          sleep 0.08
          ${scripts.paste-string}
          win_class=$(jq -r '.class // .initialClass // "window"' <<<"$active")
          win_title=$(jq -r '.title // ""' <<<"$active")
          if [ -n "$win_title" ]; then
            printf 'Pasted %s characters into %s (%s).\n' "$COPIED_CHARS" "$win_class" "$win_title"
          else
            printf 'Pasted %s characters into %s.\n' "$COPIED_CHARS" "$win_class"
          fi
        }

        case "''${1:-}" in
        selection)
          read_selection
          ;;
        clipboard)
          read_clipboard
          ;;
        capture)
          case "''${2:-region}" in
          region) capture_region ;;
          window) capture_window ;;
          screen|monitor) capture_screen ;;
          *) die "Usage: desktop-context capture [region|window|screen]" ;;
          esac
          ;;
        copy)
          copy_stdin
          printf 'Copied %s characters to clipboard.\n' "$COPIED_CHARS"
          ;;
        paste)
          paste_stdin
          ;;
        *)
          die "Usage: desktop-context {selection|clipboard|capture [region|window|screen]|copy|paste}"
          ;;
        esac
      '';
  };
}
