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
}
