{
  pkgs,
  systemArgs,
  lib,
  config,
  ...
}:
with lib; let
  isDarwin = config.configured.darwin.enable;
in
  {
    configured = {
      home-manager.enable = true;
    };

    services = {
      openssh.enable = true;
    };

    nix =
      {
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
        settings = {
          trusted-users = [
            "@wheel"
            "@admin"
          ];
          trusted-substituters = [
            "https://nix-community.cachix.org"
            "https://nix-cache.niveri.dev"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nix-cache.niveri.dev:jg3SW6BDJ0sNlPxVu7VzXo3IYa3jKNUutfbYpcKSOB8="
          ];
        };
      }
      // (
        if isDarwin
        then {
          gc = {
            automatic = true;
            interval = {
              Hour = 3;
              Minute = 15;
              Weekday = 7;
            };
            options = "--delete-older-than 10d";
          };
          optimise = {
            automatic = true;
            interval = {
              Hour = 3;
              Minute = 15;
              Weekday = 0;
            };
          };
        }
        else {
          optimise = {
            automatic = true;
          };
          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 10d";
          };
        }
      );

    programs = {
      zsh.enable = true;
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
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
        ripgrep
        unzip
        wget
      ];
    };
  }
  // lib.optionalAttrs (lib.options ? boot) {
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
