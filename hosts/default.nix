{
  pkgs,
  systemArgs,
  lib,
  ...
}:
with lib; let
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  imports = [
    ../home-manager
  ];

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

  fonts =
    {
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        ubuntu_font_family
        eb-garamond
        open-sans
      ];
    }
    // optionalAttrs (!isDarwin) {
      enableDefaultPackages = true;
      fontconfig = {
        defaultFonts = {
          serif = ["EB Garamond 08"];
          sansSerif = ["Ubuntu"];
          monospace = ["JetBrainsMono Nerd Font Propo"];
          emoji = ["Apple Color Emoji"];
        };
      };
      packages = with pkgs; [
        (stdenv.mkDerivation {
          name = "Apple Color Emoji Font";
          src = fetchurl {
            url = "https://github.com/samuelngs/apple-emoji-linux/releases/download/v18.4/AppleColorEmoji.ttf";
            hash = "sha256-pP0He9EUN7SUDYzwj0CE4e39SuNZ+SVz7FdmUviF6r0=";
          };
          dontUnpack = true;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/fonts/truetype
            cp $src $out/share/fonts/truetype/AppleColorEmoji.ttf

            runHook postInstall
          '';
        })
        (stdenv.mkDerivation {
          name = "Samsung Classic Clock Font";
          src = ../assets/fonts/samsung/samsung-clock-classic.ttf;
          dontUnpack = true;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/fonts/truetype
            cp $src $out/share/fonts/truetype/SamsungClockClassic.ttf

            runHook postInstall
          '';
        })
      ];
      fontDir.enable = true;
    };
}
