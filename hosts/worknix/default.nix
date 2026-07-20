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
      resolution = "1920x1200";
    };
    system-sounds.enable = true;
  };

  /*
  We use the TPM to auto-unlock the LUKS encrypted drive on boot.
  Enabled by running once: `sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0,7 /dev/sda2`
  */
  boot.initrd.luks.devices."rootfs" = {
    device = "a22eaea7-c464-4e2f-b8f6-c9eaead986f2";
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
