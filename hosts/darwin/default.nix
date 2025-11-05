{
  lib,
  config,
  pkgs,
  systemArgs,
  self,
  ...
}:
with lib; let
  cfg = config.configured.darwin;
in {
  imports = [
    ./modules
  ];
  options.configured.darwin = {
    enable = mkEnableOption "Enable darwin specific stuff.";
  };
  config = mkIf cfg.enable {
    users.users.mn.home = "/Users/mn";
    nix.enable = true;

    configured = {
      home-manager.enable = true;
    };

    services = {
      openssh.enable = true;
    };

    homebrew = {
      enable = true;
      caskArgs.no_quarantine = true;
      casks = [
        "blender"
        "discord"
        "gimp"
        "hammerspoon"
        "mediamate"
        "raycast"
        "spotify"
        "steam"
        "whatsapp"
      ];
    };

    system = {
      configurationRevision = self.rev or self.dirtyRev or null;
      stateVersion = 6;
      primaryUser = systemArgs.username;
      defaults = {
        LaunchServices.LSQuarantine = false;
        dock = {
          autohide = true;
          autohide-delay = 0.0;
          static-only = false;
        };
        finder = {
          CreateDesktop = false;
          AppleShowAllFiles = true;
        };
        SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
      };
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
        swapLeftCtrlAndFn = true;
      };
    };

    programs = {
      nix-index.enable = true;
      _1password.enable = true; # CLI only, GUI is best installed directly from 1pw
    };

    services = {
      configured = {
        aerospace = {
          enable = true;
          enableAerospaceSwipe = true;
        };
        hammerspoon.enable = true;
      };
    };

    /*
    Enable auth for sudo using TouchID (also inside TMUX by reattaching)
    */
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };
  };
}
