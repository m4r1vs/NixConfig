{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.boot.configured.secureboot;
in {
  options.boot.configured.secureboot = {
    enable = mkEnableOption "Enable secureboot using Limine.";
    configLimit = mkOption {
      type = types.int;
      default = 5;
      description = "How many boot entries to show.";
    };
    windowsPartUUID = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The PARTUUID of the Windows EFI partition.";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      loader = {
        systemd-boot.enable = mkForce false;
        limine = {
          enable = true;
          efiSupport = true;
          secureBoot.enable = true;
          enrollConfig = true;
          maxGenerations = cfg.configLimit;
          extraConfig = ''
            TIMEOUT=10

            ${optionalString (cfg.windowsPartUUID != null) ''
              /Microslop Windows 11
                  protocol: efi
                  path: guid(${cfg.windowsPartUUID}):/EFI/Microsoft/Boot/bootmgfw.efi
                  comment: League of Legends works there, be warned
            ''}
          '';
          style = {
            wallpapers = [../home-manager/wallpaper/Artemis_II_Earthset.jpg];
            wallpaperStyle = "stretched";
            interface = {
              branding = "Moin, ${systemArgs.username}@${systemArgs.hostname} :)";
              brandingColor = 2;
              helpHidden = true;
            };
            graphicalTerminal = {
              background = "BB15130F";
              foreground = "e6e5df";
              palette = "100f0f;d14d41;879a39;d0a215;4385be;ce5d97;3aa99f;878580";
              brightPalette = "575653;af3029;66800b;ad8301;205ea6;a02f6f;24837b;e6e5df";
              margin = 0;
              font = {
                scale = "2x2";
                spacing = 1;
              };
            };
          };
        };
      };
    };
  };
}
