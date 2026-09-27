{
  host,
  pkgs,
  systemArgs,
  ...
}: {
  nixos-notify =
    pkgs.writeShellScript "nixos-notify"
    (
      if host.isDarwin
      then
        # bash
        ''
          # Accept notify-send's arguments: skip options (and their values),
          # the first positional is the summary, the second the body.
          pos=()
          while [ "$#" -gt 0 ]; do
            case "$1" in
              -u | -t | -a | -i | -c | -h | -A | -r | --urgency | --expire-time | --app-name | --icon | --category | --hint | --action | --replace-id)
                shift 2
                ;;
              --*=* | -e | -p | -w | --transient | --print-id | --wait)
                shift
                ;;
              --)
                shift
                pos+=("$@")
                break
                ;;
              *)
                pos+=("$1")
                shift
                ;;
            esac
          done

          # Values are passed as argv, so quotes in them need no escaping
          /usr/bin/osascript - "''${pos[0]:-${systemArgs.hostname}}" "''${pos[1]:-}" <<'APPLESCRIPT'
          on run argv
            if item 2 of argv is "" then
              display notification (item 1 of argv) with title "${systemArgs.hostname}"
            else
              display notification (item 2 of argv) with title (item 1 of argv)
            end if
          end run
          APPLESCRIPT
        ''
      else
        #bash
        ''
          ${pkgs.libnotify}/bin/notify-send --app-name="${systemArgs.hostname}" "$@"
        ''
    );
}
