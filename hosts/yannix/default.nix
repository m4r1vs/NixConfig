{systemArgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
    ./yannix-packages.nix
    ./yannix-configuration.nix
  ];

  configured = {
    nvidia.enable = false;
    windowManagers = {
      hyprland.enable = true;
      i3.enable = true;
      gamescope.enable = true;
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

  system = {
    nixos.label = systemArgs.hostname + ".dhruva.hamburg";
  };
}
