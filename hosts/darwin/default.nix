{
  lib,
  config,
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
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };
      brews = [
        /*
        CLI apps to install using brew
        */
        "ghidra" # Disassembler and reverse engineering tool
        "mole" # CLI to free up disk space
        "zig" # zig programming language
      ];
      casks = [
        /*
        GUI apps to install using brew
        */
        "1password" # Password manager
        "affinity" # Photoshot alternative
        "android-studio" # Android IDE
        "brave-browser" # Web browser
        "discord" # Team chat
        "finetune" # Music Mixer
        "google-drive" # Cloud storage
        "iriunwebcam" # Use phone as webcam
        "keycastr" # Show keystrokes on screen
        "linearmouse" # Smooth mouse acceleration
        "lm-studio" # Run LLMs locally
        "macs-fan-control" # View and control fan speeds
        "mediamate" # Better volume UI
        "obs" # Screen recording and streaming
        "raycast" # Spotlight replacement
        "signal" # Encrypted messaging
        "spotify" # Music streaming
        "steam" # Game Library
        "utm" # VMs
      ];
      masApps = {
        /*
        App Store apps to install by their numeric ID.
        Find apps by sharing them from the App Store and looking at the URL.
        */
        DavinciResolve = 571213070; # Video editing software
        Excel = 462058435; # Spreadsheet software
        GarageBand = 682658836; # Music creation software
        PowerPoint = 462062816; # Presentation software
        Remarkable = 1276493162; # reMarkable tablet companion app
        WhatsApp = 310633997; # WhatsApp
        Word = 462054704; # Word processor
        Xcode = 497799835; # Apple IDE
      };
    };

    power = {
      restartAfterFreeze = true;
      sleep = {
        allowSleepByPowerButton = true;
        computer = 15;
        display = 10;
      };
    };

    system = {
      configurationRevision = self.rev or self.dirtyRev or null;
      stateVersion = 6;
      primaryUser = systemArgs.username;
      defaults = {
        LaunchServices.LSQuarantine = false; # Disable "This file was downloaded from the internet" warning
        WindowManager = {
          AppWindowGroupingBehavior = true;
          EnableStandardClickToShowDesktop = false;
          EnableTilingByEdgeDrag = false;
          EnableTilingOptionAccelerator = false;
          EnableTopTilingByEdgeDrag = false;
          GloballyEnabled = false; # Disable macOS's built in tiling, since it conflicts with yabai
          StandardHideDesktopIcons = true;
          StandardHideWidgets = false;
        };
        dock = {
          appswitcher-all-displays = true;
          autohide = true;
          autohide-delay = 0.0;
          expose-group-apps = false;
          largesize = 48;
          launchanim = true;
          magnification = true;
          mineffect = "genie";
          minimize-to-application = true;
          mru-spaces = false;
          orientation = "bottom";
          show-recents = false;
          showAppExposeGestureEnabled = false;
          showDesktopGestureEnabled = false;
          showLaunchpadGestureEnabled = false;
          showMissionControlGestureEnabled = true;
          static-only = false;
          tilesize = 38;
          wvous-bl-corner = 1; # Hot corner (bottom left) -- disable
          wvous-br-corner = 1; # Hot corner (bottom right) -- disable
          wvous-tl-corner = 1; # Hot corner (top left) -- disable
          wvous-tr-corner = 1; # Hot corner (top right) -- disable
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
          _FXEnableColumnAutoSizing = true; # Resize columns to fit filenames
          AppleShowAllExtensions = true; # Show file extensions
          AppleShowAllFiles = true; # Show hidden files by default
          CreateDesktop = true; # When no window is focus, focus Finder (if false, yabai breaks a bit)
          FXDefaultSearchScope = "SCcf"; # Search current folder
          FXEnableExtensionChangeWarning = false; # Do not warn when changing file extension
          FXPreferredViewStyle = "Nlsv"; # Default to list view
          FXRemoveOldTrashItems = true; # Auto remove trash after 30 days
          ShowPathbar = true; # Show path breadcrumbs in finder windows
          ShowStatusBar = true; # Show status bar at bottom of finder windows with item/disk space stats
        };
        NSGlobalDomain = {
          _HIHideMenuBar = false;
          "com.apple.keyboard.fnState" = true;
          "com.apple.mouse.tapBehavior" = null;
          "com.apple.swipescrolldirection" = true;
          KeyRepeat = 2;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = true;
          NSAutomaticInlinePredictionEnabled = true;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = true;
          NSAutomaticSpellingCorrectionEnabled = false;
          NSAutomaticWindowAnimationsEnabled = true;
          NSDocumentSaveNewDocumentsToCloud = false;
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
          NSScrollAnimationEnabled = true;
          NSStatusItemSelectionPadding = 4;
          NSStatusItemSpacing = 10;
          NSTableViewDefaultSizeMode = 1;
          NSUseAnimatedFocusRing = true;
          NSWindowResizeTime = 0.1;
          NSWindowShouldDragOnGesture = true;
          PMPrintingExpandedStateForPrint = true;
          PMPrintingExpandedStateForPrint2 = true;
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
          BatteryShowPercentage = false;
          Bluetooth = true;
          Display = false;
          FocusModes = false;
          NowPlaying = false;
          Sound = true;
        };
        CustomUserPreferences = {
          "com.apple.dock" = {
            "workspaces-auto-swoosh" = true; # Force automatic space switching when cmd-tabbing
          };
          # Disable press-and-hold action in these apps
          "md.obsidian" = {
            "ApplePressAndHoldEnabled" = false;
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
