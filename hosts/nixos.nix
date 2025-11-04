{
  pkgs,
  systemArgs,
  lib,
  config,
  ...
}:
with lib; {
  imports = [
    ../nixos-modules
  ];

  virtualisation = {
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  boot = {
    tmp.cleanOnBoot = true;
    loader = {
      timeout = lib.mkForce 1;
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = systemArgs.hostname;
    networkmanager.enable = true;
    firewall = {
      enable = true;
    };
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  users = {
    users.${systemArgs.username} = {
      isNormalUser = true;
      extraGroups =
        [
          "audio"
          "networkmanager"
          "wheel"
        ]
        ++ lib.optionals config.virtualisation.podman.enable [
          "podman"
        ]
        ++ lib.optionals config.virtualisation.docker.enable [
          "docker"
        ]
        ++ lib.optionals config.virtualisation.libvirtd.enable [
          "libvirtd"
        ];
      openssh.authorizedKeys.keys = [
        # Allmighty SSH key
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN6sMTjk1LAXVX9qRKsB3VgsfqCfcJSeosgoYWTgSHW"
      ];
    };
    defaultUserShell = pkgs.zsh;
  };

  programs = {
    nix-index-database.comma.enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      libsecret
      podman-tui
      psmisc
      sbctl
    ];
    pathsToLink = ["/share/zsh"];
  };

  system = {
    stateVersion = "24.11";
  };
}
