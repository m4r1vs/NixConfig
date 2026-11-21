{
  config,
  helpers,
  lib,
  pkgs,
  scripts,
  ...
}: let
  # darwin has neither option, hence the attrByPath
  firmwareUpdate = lib.attrByPath ["services" "configured" "firmware-update"] {enable = false;} config;
  tpmUnlock = lib.attrByPath ["configured" "tpmUnlock"] {enable = false;} config;
  helper = "${firmwareUpdate.helper}/bin/firmware-update-apply";

  # BIOS and dbx updates change PCR 0/7, which the disk key is sealed to
  luksDevice = config.boot.initrd.luks.devices.${tpmUnlock.device}.device;
  tpmNote = "A BIOS or Secure Boot (dbx) update makes the next boot ask for the disk passphrase. Re-enrol the TPM afterwards: sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7 ${luksDevice}";
in {
  firmware-update-check = helpers.mkScript {
    name = "firmware-update-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
    ];
    text =
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

        # get-updates exits 2 when there is nothing to install
        FWUPD_JSON=$(fwupdmgr get-updates --json 2>/dev/null || true)

        # An unreachable daemon still prints well-formed JSON - {"Error": {...}} -
        # and jq resolves the missing .Devices to a length of 0, which would look
        # exactly like "no updates". So test for the key, not the count.
        if ! echo "$FWUPD_JSON" | jq -e 'has("Devices")' > /dev/null 2>&1; then
          FWUPD_ERR=$(echo "$FWUPD_JSON" | jq -r '.Error.Message // empty' 2>/dev/null || true)
          [ -z "$FWUPD_ERR" ] && FWUPD_ERR="Could not reach the fwupd daemon."
          ${scripts.nixos-notify} -u normal -t 10000 \
            "Firmware check failed 󰀪 " "$FWUPD_ERR"
          exit 0
        fi

        FWUPD_COUNT=$(echo "$FWUPD_JSON" | jq -r '.Devices | length')

        if [ "$FWUPD_COUNT" -eq 0 ]; then
          if [ "''${1:-}" = "verbose" ]; then
            ${scripts.nixos-notify} -u low -t 5000 \
              "Firmware is up to date 󰄬 " "Nothing to install."
          fi
          exit 0
        fi

        FWUPD_LIST=$(echo "$FWUPD_JSON" | jq -r \
          '.Devices[] | "• " + (.Name // "Unknown device") + " → " + (.Releases[0].Version // "?")')
      ''
      + (
        if firmwareUpdate.enable
        then
          # bash
          ''
            BODY="$FWUPD_LIST"
            ${lib.optionalString tpmUnlock.enable ''
              BODY+=$'\n\n'${lib.escapeShellArg tpmNote}
            ''}

            # --action blocks until the notification is closed, so it stays
            # until answered rather than vanishing with the button
            RESPONSE="$(
              ${scripts.nixos-notify} -u normal -t 0 \
                --action="update=Update and Restart" \
                "Firmware updates available 󰚰 " "$BODY" || true
            )"

            [[ "$RESPONSE" == *"update"* ]] || exit 0

            ${scripts.nixos-notify} -u normal -t 0 \
              -h string:synchronous:firmware-update \
              "Installing firmware updates 󰚰 " "Don't power off. The system restarts once they are installed."

            STATUS=0
            OUTPUT="$(/run/wrappers/bin/sudo -n ${helper} 2>&1)" || STATUS=$?

            case "$STATUS" in
              0)
                ${scripts.nixos-notify} -u normal -t 0 \
                  -h string:synchronous:firmware-update \
                  "Restarting 󰜉 " "Firmware updates are installed or staged for the restart."
                exec ${scripts.gracefull-run "systemctl reboot"}
                ;;
              2)
                ${scripts.nixos-notify} -u low -t 5000 \
                  -h string:synchronous:firmware-update \
                  "Firmware is up to date 󰄬 " "Nothing to install."
                ;;
              *)
                # fwupdmgr redraws its progress bar with \r, keep the last real lines
                TAIL="$(printf '%s\n' "$OUTPUT" | tr '\r' '\n' | grep -v '^[[:space:]]*$' | tail -n 4 || true)"
                ${scripts.nixos-notify} -u critical -t 0 \
                  -h string:synchronous:firmware-update \
                  "Firmware update failed 󰀪 " "''${TAIL:-fwupdmgr exited with $STATUS.}"
                exit 1
                ;;
            esac
          ''
        else
          # bash
          ''
            ${scripts.nixos-notify} -u normal -t 15000 \
              "Firmware updates available 󰚰 " "$FWUPD_LIST"
          ''
      );
  };
}
