{systemArgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
  ];

  configured = {
    nvidia.enable = false;
    desktop = {
      enable = true;
      windowManagers = {
        hyprland.enable = true;
        i3.enable = false;
        gamescope.enable = false;
      };
    };
    limine = {
      memtest = false;
      secureboot = false;
      resolution = "1920x1200";
    };
    system-sounds.enable = true;
  };

  services = {
    fprintd.enable = true;

    /*
    Dynamic CPU/Power modes
    */
    power-profiles-daemon.enable = true;

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

  system = {
    nixos.label = systemArgs.hostname + ".meetovo.de";
  };
}
