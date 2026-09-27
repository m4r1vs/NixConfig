{
  pkgs,
  scripts,
  systemArgs,
  ...
}: {
  rofi-obsidian =
    pkgs.writeShellScript "rofi-obsidian"
    # bash
    ''
      VAULT_NAME="${systemArgs.obsidianVault or "Obsidian Vault"}"
      VAULT_PATH="$HOME/Documents/$VAULT_NAME"

      if [ $# -eq 0 ]; then
        if [ ! -d "$VAULT_PATH" ]; then
          ${scripts.nixos-notify} -e "Vault not found:" "$VAULT_PATH"
          exit 0
        fi
        cd "$VAULT_PATH"
        find . -name "*.md" -not -path '*/.*' -printf "%P\n" | sed 's/\.md$//' | sort
      else
        NOTE="$*"
        ENCODED_NOTE=$(${pkgs.jq}/bin/jq -rn --arg q "$NOTE" '$q|@uri|gsub("%2F"; "/")')
        ENCODED_VAULT=$(${pkgs.jq}/bin/jq -rn --arg q "$VAULT_NAME" '$q|@uri')

        ${pkgs.xdg-utils}/bin/xdg-open "obsidian://open?vault=$ENCODED_VAULT&file=$ENCODED_NOTE" &>/dev/null &
        ${scripts.nixos-notify} -u low -t 1200 -h string:synchronous:rofi-obsidian -e "Opened in Obsidian:" "$NOTE"
      fi
      exit 0
    '';
}
