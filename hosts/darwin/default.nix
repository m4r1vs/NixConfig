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
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };
      casks = [
        "1password"
        "blender"
        "brave-browser"
        "discord"
        "gimp"
        "linearmouse"
        "mediamate"
        "minecraft"
        "raycast"
        "spotify"
        "steam"
        "whatsapp"
      ];
      masApps = {
        PowerPoint = 462062816;
        Word = 462054704;
        Excel = 462058435;
        Flighty = 1358823008;
        DavinciResolve = 571213070;
        Xcode = 497799835;
        GarageBand = 682658836;
        Radio = 6478023685;
      };
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
          expose-group-apps = false;
          largesize = 46;
          launchanim = true;
          magnification = true;
          mineffect = "genie";
          mru-spaces = false;
          orientation = "bottom";
          minimize-to-application = true;
          show-recents = false;
          tilesize = 32;
        };
        trackpad = {
          Clicking = false;
          TrackpadRightClick = true;
          FirstClickThreshold = 0;
          SecondClickThreshold = 2;
        };
        finder = {
          _FXShowPosixPathInTitle = true; # Show full POSIX path
          _FXSortFoldersFirst = true; # Show folders first when sorting
          AppleShowAllExtensions = true; # Show file extensions
          AppleShowAllFiles = true; # Show hidden files by default
          CreateDesktop = false; # Show files in Desktop folder on Desktop
          FXDefaultSearchScope = "SCcf"; # Search current folder
          FXEnableExtensionChangeWarning = false; # Do not warn when changing file extension
          FXPreferredViewStyle = "Nlsv"; # Default to list view
          FXRemoveOldTrashItems = true; # Auto remove trash after 30 days
        };
        NSGlobalDomain = {
          "com.apple.mouse.tapBehavior" = null;
        };
        universalaccess.closeViewScrollWheelToggle = true; # Scroll while holding ctrl to zoom
        screencapture = {
          location = "/Users/${systemArgs.username}/Screencaptures";
          show-thumbnail = false;
          target = "file";
          type = "jpg";
        };
        SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
        controlcenter = {
          AirDrop = false;
          Bluetooth = true;
          Display = false;
          FocusModes = false;
          NowPlaying = false;
          Sound = true;
        };
        CustomUserPreferences = {
          "com.apple.dock" = {
            "workspaces-auto-swoosh" = true;
          };
        };
      };
      startup.chime = false;
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
          enable = false;
          enableAerospaceSwipe = false;
        };
        hammerspoon.enable = false;
        yabai.enable = true;
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
