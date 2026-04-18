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
        i3.enable = true;
        gamescope.enable = true;
      };
    };
    limine = {
      memtest = true;
      secureboot = true;
      resolution = "1920x1080";
    };
    system-sounds.enable = true;
  };

  services = {
    /*
    Blinking ThinkPad LED
    */
    thinkmorse = {
      message = "Hallo Welt";
      enable = true;
    };

    # TODO: Add fingerpint support either by installing a different sensor or packaging https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libfprint-goodixtls-55x4

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
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
