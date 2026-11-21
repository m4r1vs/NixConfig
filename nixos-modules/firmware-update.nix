{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}: let
  cfg = config.services.configured.firmware-update;

  helper = pkgs.writeShellApplication {
    name = "firmware-update-apply";
    runtimeInputs = [config.services.fwupd.package];
    text = ''
      if [ "$#" -ne 0 ]; then
        echo "Usage: firmware-update-apply (takes no arguments)" >&2
        exit 1
      fi

      # Installs every pending LVFS update without asking. Device safety checks
      # (battery level, AC power) stay on; the reboot is left to the caller, so
      # fwupd must not trigger one itself. Exit code 2 means nothing to do.
      exec fwupdmgr update \
        --assume-yes \
        --no-reboot-check \
        --no-unreported-check \
        --no-device-prompt
    '';
  };
in {
  options.services.configured.firmware-update = {
    enable = lib.mkEnableOption "Passwordless root helper that installs pending fwupd firmware updates";
    helper = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = helper;
      description = "Locked-down root helper that installs all pending LVFS firmware updates without rebooting.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.fwupd.enable;
        message = "services.configured.firmware-update requires services.fwupd.enable = true.";
      }
    ];

    security.sudo.extraRules = [
      {
        users = [systemArgs.username];
        commands = [
          {
            command = "${cfg.helper}/bin/firmware-update-apply";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };
}
