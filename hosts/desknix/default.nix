{
  config,
  lib,
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
      ];
      windowsPartUUID = "bf2df441-4059-45e1-886a-6cf5e8def333";
    };
    system-sounds.enable = true;
  };

  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable = lib.mkForce false;

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
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
  };

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
