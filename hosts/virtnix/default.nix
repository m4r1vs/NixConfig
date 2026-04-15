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
    desktop = {
      enable = true;
      x11 = false;
    };
  };

  specialisation = {
    "i3 Tiling Window Manager".configuration = {
      configured.desktop.x11 = lib.mkForce true;
    };
  };

  networking = {
    useDHCP = lib.mkForce false;
    dhcpcd.enable = lib.mkForce false;
    nameservers = lib.mkForce ["8.8.8.8"];
  };

  environment.etc."resolv.conf".text = ''
    search localdomain
    nameserver 8.8.8.8
    options edns0
  '';

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

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
