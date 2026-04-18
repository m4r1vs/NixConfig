{
  pkgs,
  scripts,
  ...
}: {
  rofi-obsidian =
    pkgs.writeShellScript "rofi-obsidian"
    # bash
    ''
      VAULT_PATH="$HOME/Documents/Marius' Remote Vault"
      VAULT_NAME="Marius' Remote Vault"

      if [ -z "$@" ]; then
        if [ ! -d "$VAULT_PATH" ]; then
          ${scripts.nixos-notify} -e "Vault not found:" "$VAULT_PATH"
          exit 0
        fi
        cd "$VAULT_PATH"
        find . -name "*.md" -not -path '*/.*' -printf "%P\n" | sed 's/\.md$//' | sort
      else
        NOTE="$@"
        # URL encode spaces and other special characters
        # Using python3 for robust encoding
        ENCODED_NOTE=$(${pkgs.python3}/bin/python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$NOTE")
        ENCODED_VAULT=$(${pkgs.python3}/bin/python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$VAULT_NAME")

        ${pkgs.xdg-utils}/bin/xdg-open "obsidian://open?vault=$ENCODED_VAULT&file=$ENCODED_NOTE" &>/dev/null &
        ${scripts.nixos-notify} -t 1200 -h string:synchronous:rofi-obsidian -e "Opened in Obsidian:" "$NOTE"
      fi
      exit 0
    '';
}
