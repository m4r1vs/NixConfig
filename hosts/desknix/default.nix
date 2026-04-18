{
  config,
  systemArgs,
  lib,
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
      x11 = false;
    };
    limine = {
      secureboot = true;
      resolution = "2560x1440";
      memtest = true;
      wallpapers = [
        ../../home-manager/wallpaper/New_York_Garden.jpg
        ../../home-manager/wallpaper/New_York_Subway.jpg
      ];
      windowsPartUUID = "bf2df441-4059-45e1-886a-6cf5e8def333";
    };
    system-sounds.enable = true;
  };

  specialisation = {
    "i3 Tiling Window Manager".configuration = {
      configured.desktop.x11 = lib.mkForce true;
    };
    "Steam Big Picture".configuration = {
      configured.desktop.gamescope = lib.mkForce true;
    };
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
