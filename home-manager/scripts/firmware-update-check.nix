{
  pkgs,
  scripts,
  ...
}: {
  firmware-update-check =
    pkgs.writeShellScript "firmware-update-check"
    # bash
    ''
      # fwupd-refresh.timer keeps the LVFS metadata current, so we only query
      # the running daemon here: no network round-trip and no polkit prompt.
      #
      # Pending updates and an unreachable daemon always notify. "Up to date"
      # only does so with "verbose", which the xdg entry passes: a manual run
      # needs an answer, the Hyprland startup must not add login noise.

      # No fwupdmgr at all means the host simply doesn't run fwupd, which is
      # not a fault worth a notification on every login.
      command -v fwupdmgr > /dev/null || exit 0

      FWUPD_JSON=$(fwupdmgr get-updates --json 2>/dev/null)

      # An unreachable daemon still prints well-formed JSON - {"Error": {...}} -
      # and jq resolves the missing .Devices to a length of 0, which would look
      # exactly like "no updates". So test for the key, not the count.
      if ! echo "$FWUPD_JSON" | ${pkgs.jq}/bin/jq -e 'has("Devices")' > /dev/null 2>&1; then
        FWUPD_ERR=$(echo "$FWUPD_JSON" | ${pkgs.jq}/bin/jq -r '.Error.Message // empty' 2>/dev/null)
        [ -z "$FWUPD_ERR" ] && FWUPD_ERR="Could not reach the fwupd daemon."
        ${scripts.nixos-notify} -u normal -t 10000 \
          "Firmware check failed 󰀪 " "$FWUPD_ERR"
        exit 0
      fi

      FWUPD_COUNT=$(echo "$FWUPD_JSON" | ${pkgs.jq}/bin/jq -r '.Devices | length')

      if [ "$FWUPD_COUNT" -gt 0 ]; then
        FWUPD_LIST=$(echo "$FWUPD_JSON" | ${pkgs.jq}/bin/jq -r \
          '.Devices[] | "• " + (.Name // "Unknown device") + " → " + (.Releases[0].Version // "?")')
        ${scripts.nixos-notify} -u normal -t 15000 \
          "Firmware updates available 󰚰 " "$FWUPD_LIST"
      elif [ "$1" = "verbose" ]; then
        ${scripts.nixos-notify} -u low -t 5000 \
          "Firmware is up to date 󰄬 " "Nothing to install."
      fi

      exit 0
    '';
}
