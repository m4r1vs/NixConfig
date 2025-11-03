{
  pkgs,
  systemArgs,
  lib,
  config,
  ...
}: {
  configured = {
    home-manager.enable = true;
  };

  services = {
    openssh.enable = true;
  };

  virtualisation = {
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 10d";
    };
    settings = {
      auto-optimise-store = true;
      trusted-substituters = [
        "https://nix-community.cachix.org"
        "https://nix-cache.niveri.dev"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nix-cache.niveri.dev:jg3SW6BDJ0sNlPxVu7VzXo3IYa3jKNUutfbYpcKSOB8="
      ];
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
    zsh.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    nix-index-database.comma.enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      curl
      exiftool
      ffmpeg
      fzf
      htop-vim
      imagemagick
      jq
      libsecret
      podman-tui
      psmisc
      ripgrep
      sbctl
      unzip
      wget
    ];
    pathsToLink = ["/share/zsh"];
  };

  system = {
    stateVersion = "24.11";
  };
}
