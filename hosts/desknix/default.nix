{
  config,
  systemArgs,
  ...
}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
  ];

  configured = {
    nvidia.enable = true;
    razer.enable = true;
    desktop = {
      enable = true;
      windowManagers = {
        hyprland.enable = true;
        i3.enable = true;
        gamescope.enable = true;
      };
    };
    limine = {
      secureboot = true;
      resolution = "2560x1440";
      memtest = true;
      wallpapers = [
        ../../home-manager/wallpaper/New_York_Garden.jpg
        ../../home-manager/wallpaper/New_York_Subway.jpg
        ../../home-manager/wallpaper/Staten_Island_Ferry.jpg
        ../../home-manager/wallpaper/New_York_Chinatown.jpg
        ../../home-manager/wallpaper/New_York_from_Staten_Island.jpg
        ../../home-manager/wallpaper/Northern_Manhattan_Forest.jpg
      ];
      windowsPartUUID = "bf2df441-4059-45e1-886a-6cf5e8def333";
    };
    system-sounds.enable = true;
  };

  /*
  We use the TPM to auto-unlock the LUKS encrypted drive on boot.
  Enabled by running once: `sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0,7 /dev/sda2`
  */
  boot.initrd.luks.devices."rootfs" = {
    device = "94f0f658-8423-4091-8103-92a5a6fec954";
  };

  services = {
    /*
    B-Tree FS
    */
    btrfs = {
      autoScrub = {
        enable = true;
        interval = "weekly";
        fileSystems = ["/"];
      };
    };
  };

  /*
  Extra Nvidia Settings
  */
  hardware = {
    nvidia = {
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };
  };

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
