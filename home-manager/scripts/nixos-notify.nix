{
  pkgs,
  systemArgs,
  ...
}: {
  nixos-notify =
    pkgs.writeShellScript "nixos-notify"
    (
      if systemArgs.system == "aarch64-darwin"
      then
        # bash
        ''
          message=""

          # Parse arguments manually to find -e
          while [ "$#" -gt 0 ]; do
            case "$1" in
              -e)
                # Check if there is a next argument
                if [ -n "$2" ]; then
                  message="$2"
                  shift 2 # Consume -e and its argument
                else
                  echo "Error: -e flag requires an argument." >&2
                  exit 1
                fi
                ;;
              *)
                shift # Ignore all other flags/arguments
                ;;
            esac
          done

          # Use a default message if -e was not provided
          if [ -z "$message" ]; then
            message="Error Parsing nixos-notify"
          fi

          message=$(echo "$message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

          osascript -e "display notification \"$message\" with title \"NixBook\""
        ''
      else
        #bash
        ''
          ${pkgs.libnotify}/bin/notify-send --app-name="${systemArgs.hostname}" "$@"
        ''
    );
}
