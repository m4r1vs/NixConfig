{
  systemArgs,
  lib,
  ...
}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
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
      message = "Hallo Welt";
      enable = true;
    };

    # TODO: Add fingerpint support either by installing a different sensor or packaging https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libfprint-goodixtls-55x4

    /*
    Limit CPU when on battery
    */
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 60;
      };
    };

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
