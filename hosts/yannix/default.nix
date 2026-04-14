{
  systemArgs,
  lib,
  ...
}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
    ./yannix-packages.nix
    ./yannix-configuration.nix
  ];

  configured = {
    nvidia.enable = false;
    desktop = {
      enable = true;
      x11 = false;
    };
  };

  specialisation = {
    x11.configuration = {
      configured.desktop.x11 = lib.mkForce true;
    };
  };

  services = {
    /*
    Blinking ThinkPad LED
    */
    thinkmorse = {
      message = systemArgs.hostname;
      enable = true;
    };

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

  /*
  Enable Secure Boot
  */
  boot.configured.secureboot = {
    enable = false;
  };

  system = {
    nixos.label = systemArgs.hostname + ".dhruva.hamburg";
  };
}
