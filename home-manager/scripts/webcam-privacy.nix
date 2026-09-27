{pkgs, ...}: {
  # Long-running waybar module: prints the icon whenever a camera is in use.
  # inotify reports every open/close of /dev/video*; fuser then confirms the
  # state once per burst, instead of polling fuser (which walks /proc) every 2s.
  webcam-privacy =
    pkgs.writeShellScript "webcam-privacy"
    ''
      shopt -s nullglob
      devs=(/dev/video*)
      last="unset"

      emit() {
        local state=""
        if (( ''${#devs[@]} )) && ${pkgs.psmisc}/bin/fuser -s "''${devs[@]}" 2>/dev/null; then
          state=" 󰄀"
        fi
        if [ "$state" != "$last" ]; then
          last=$state
          printf '%s\n' "$state"
        fi
      }

      emit

      # No camera yet: wait for one, then exit so waybar restarts us (restart-interval)
      if (( ''${#devs[@]} == 0 )); then
        exec ${pkgs.inotify-tools}/bin/inotifywait -qq -e create --include 'video[0-9]+$' /dev
      fi

      while read -r _ event; do
        # Camera unplugged: exit so waybar restarts us with the new device list
        [[ "$event" == DELETE_SELF* ]] && exit 0
        # Apps probe devices briefly; drain the burst, then check once
        while read -r -t 0.2 _; do :; done
        emit
      done < <(${pkgs.inotify-tools}/bin/inotifywait -mq -e open,close,delete_self "''${devs[@]}")
    '';
}
