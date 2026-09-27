{
  pkgs,
  systemArgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (config.configured) host;
in {
  imports = [
    ../nixos-modules
  ];

  # Servers run containerd (kubenix) or docker (gitlab-runner) instead
  virtualisation = mkIf host.isDev {
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    containers.containersConf.settings.containers.dns_servers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  boot = {
    tmp.cleanOnBoot = true;
    loader = {
      timeout = lib.mkDefault 1;
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = lib.mkDefault 20;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = systemArgs.hostname;
    # Servers use static networking (nixos-modules/server/networking.nix)
    networkmanager.enable = mkDefault (host.isDesktop || host.isISO);
    firewall = {
      enable = true;
    };
  };

  services.openssh.settings = {
    PasswordAuthentication = lib.mkDefault false;
    KbdInteractiveAuthentication = lib.mkDefault false;
    # Plain priority on purpose: the installer profile sets mkDefault "yes",
    # and two mkDefaults with different values would conflict in the ISO.
    PermitRootLogin = "no";
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_DK.UTF-8";
  i18n.extraLocaleSettings.LC_MONETARY = "de_DE.UTF-8";

  users = {
    users.${systemArgs.username} = {
      isNormalUser = true;
      extraGroups =
        [
          "audio"
          "wheel"
        ]
        ++ lib.optionals config.networking.networkmanager.enable [
          "networkmanager"
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
    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = host.flakePath;
    };
  };

  nix.settings.accept-flake-config = true;

  environment = {
    systemPackages = with pkgs;
      [
        coreutils-full
        psmisc
      ]
      ++ optionals config.virtualisation.podman.enable [podman-tui]
      # sbctl enrolls secure boot keys, also from the installer
      ++ optionals (host.isDesktop || host.isISO) [sbctl]
      ++ optionals host.isDesktop [libsecret];
    pathsToLink = ["/share/zsh"];
  };

  system = {
    stateVersion = "24.11";
    nixos.distroName = "NixOS configured by Marius";
  };
}
