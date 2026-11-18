{
  pkgs,
  helpers,
  ...
}: {
  /*
  terminal-overlay <window class> <command> [args...]

  Runs a GUI program so that its window covers the terminal it was started
  from, the way swayimg's overlay mode does. It fills two gaps in Hyprland's
  swallowing: it looks for the terminal among the parent processes of the new
  window, which inside tmux lead to the tmux server instead, and it opens the
  new window tiled even when the swallowed terminal was floating.
  */
  terminal-overlay = helpers.mkScript {
    name = "terminal-overlay";
    runtimeInputs = [pkgs.hyprland pkgs.jq pkgs.procps];
    text = ''
      class=$1
      shift

      # Registers the window rule; fails whenever there is nothing to cover
      cover() {
        local regex terminal terminals pid geometry

        # Started from a terminal, inside a Hyprland session that swallows
        [ -t 0 ] && [ -n "''${HYPRLAND_INSTANCE_SIGNATURE-}" ] || return 1
        [ "$(hyprctl getoption misc:enable_swallow | sed -n 's/^bool: //p')" = true ] || return 1
        # Not -j: hyprctl prints the regex's backslashes as invalid JSON
        regex=$(hyprctl getoption misc:swallow_regex | sed -n 's/^str: //p')
        [ -n "$regex" ] && [ "$regex" != "[[EMPTY]]" ] || return 1

        # The terminal the user is typing in
        terminal=$(hyprctl -j activewindow | jq -ce --arg regex "$regex" 'select(.class | test($regex))') || return 1

        # With a terminal among our parents Hyprland swallows it by itself.
        # It puts our window in the terminal's tile, but a floating terminal
        # (the SUPER+E yazi) has none, so cover that one anyway
        if [ "$(jq -r .floating <<<"$terminal")" != true ]; then
          terminals=$(hyprctl -j clients | jq -r --arg regex "$regex" '.[] | select(.class | test($regex)) | .pid')
          pid=$$
          while [ "''${pid:-0}" -gt 1 ]; do
            if grep -qxF "$pid" <<<"$terminals"; then
              return 1
            fi
            pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
          done
        fi

        # Window rules position relative to the monitor
        geometry=$(hyprctl -j monitors | jq -re --argjson terminal "$terminal" '
          .[] | select(.id == $terminal.monitor)
          | "move = { \($terminal.at[0] - .x), \($terminal.at[1] - .y) }, size = { \($terminal.size[0]), \($terminal.size[1]) }"
        ') || return 1

        # Hyprland can't match a rule by pid, so the rule covers the whole
        # class until our own window (we exec below, so it has our pid) is open
        hyprctl eval "
          terminal_overlay_owner = $$
          local rule = hl.window_rule({ name = 'terminal-overlay', match = { class = '$class' }, float = true, $geometry })
          local opened
          local function done()
            if opened:is_active() then opened:remove() end
            -- a later launch may have taken the rule over
            if terminal_overlay_owner == $$ then rule:set_enabled(false) end
          end
          opened = hl.on('window.open', function(window)
            if window.pid == $$ then done() end
          end)
          -- the program may never open a window (mpv playing music)
          hl.timer(done, { timeout = 15000, type = 'oneshot' })
        " >/dev/null
      }

      cover || true
      exec "$@"
    '';
  };
}
