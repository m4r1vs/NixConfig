{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.limine;
in {
  options.configured.limine = {
    enable = mkEnableOption "Enable Limine bootloader.";
    secureboot = mkOption {
      type = types.bool;
      default = false;
      description = "Enable secureboot using Limine.";
    };
    configLimit = mkOption {
      type = types.int;
      default = 5;
      description = "How many boot entries to show.";
    };
    resolution = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Resolution to use.";
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
        timeout = 5;
        limine = {
          #TODO: add resolution on update to NixOS 26.05
          enable = true;
          efiSupport = true;
          secureBoot.enable = cfg.secureboot;
          enrollConfig = cfg.secureboot;
          maxGenerations = cfg.configLimit;
          extraEntries = optionalString (cfg.windowsPartUUID != null) ''
            /Microslop Windows 11
                protocol: efi
                path: guid(${cfg.windowsPartUUID}):/EFI/Microsoft/Boot/bootmgfw.efi
                comment: League of Legends works there, be warned!
          '';
          style = {
            wallpapers = [../home-manager/wallpaper/Artemis_II_Earthset.jpg];
            wallpaperStyle = "stretched";
            interface = {
              branding = "Moin, ${systemArgs.username}@${systemArgs.hostname} :)";
              brandingColor = 2;
              helpHidden = true;
              resolution = cfg.resolution;
            };
            graphicalTerminal = {
              background = "AA15130F";
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
