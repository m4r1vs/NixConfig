{
  lib,
  config,
  options,
  ...
}:
with lib; let
  cfg = config.boot.configured.secureboot;
in {
  options.boot.configured.secureboot = {
    enable = mkEnableOption "Enable secureboot using Lanzaboot.";
    consoleMode = mkOption {
      type = types.int;
      default = 2;
      description = "The systemd-boot console mode to use.";
    };
    configLimit = mkOption {
      type = types.int;
      default = 20;
      description = "How many systemd-boot entries to show.";
    };
  };

  # Only evaluate if lanzaboote is imported
  config = optionalAttrs (options.boot ? lanzaboote) (mkIf cfg.enable {
    boot = {
      loader.systemd-boot.enable = mkForce false;
      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
        configurationLimit = cfg.configLimit;
        settings = {
          console-mode = cfg.consoleMode;
          timeout = 10;
        };
      };
    };
  });
}
