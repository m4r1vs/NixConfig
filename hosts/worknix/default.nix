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
      memtest = true;
      secureboot = true;
      resolution = "2880x1800";
    };
    system-sounds.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    tuxedo-drivers.enable = true;

    /*
    Radeon 890M: early KMS so plymouth starts without a mode switch,
    plus ROCm/OpenCL compute
    */
    amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };
  };

  boot = {
    kernelParams = [
      "acpi.ec_no_wakeup=1"
      "amdgpu.gpu_recovery=1"
    ];
  };

  services = {
    /*
    Dynamic CPU/Power modes
    */
    power-profiles-daemon.enable = true;

    /*
    Face unlock via the internal IR camera
    */
    howdy = {
      enable = true;
      settings.video.device_path = "/dev/v4l/by-path/pci-0000:65:00.4-usb-0:1:1.2-video-index0";
    };

    /*
    BIOS/EC updates via LVFS; limine signs fwupd.efi with our sbctl keys
    */
    fwupd.enable = true;

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

  security = {
    /*
    Howdy authenticates sudo and polkit prompts (1Password unlock) on its
    own; every other PAM service keeps password-only auth instead of
    gaining a required second factor.
    */
    pam = {
      howdy.enable = false;
      services = let
        howdy = {
          howdy = {
            enable = true;
            control = "sufficient";
          };
        };
      in {
        sudo = howdy;
        polkit-1 = howdy;
      };
    };
  };

  system = {
    nixos.label = systemArgs.hostname + ".meetovo.de";
  };
}
