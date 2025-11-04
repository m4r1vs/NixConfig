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
  };

  specialisation = {
    x11.configuration = {
      configured.desktop.x11 = lib.mkForce true;
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
  Enable Secure Boot
  */
  boot.configured.secureboot = {
    enable = true;
    consoleMode = 4;
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
