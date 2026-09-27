{
  pkgs,
  scripts,
  host,
  ...
}: let
  inherit (host) isDarwin isDesktop isGraphical isWayland isX86;
in {
  # Drop packages not built for this platform (e.g. slack/postman on aarch64 virtnix)
  home.packages = with pkgs;
    lib.filter (lib.meta.availableOn stdenv.hostPlatform) ([
        # Install on every system:
        (writeShellScriptBin "date-trivia" scripts.date-trivia)
        (writeShellScriptBin "ls-git" scripts.ls-git)
        (writeShellScriptBin "rebuild" scripts.rebuild)
        pastel # manipulate colors and palettes
        tlrc # Simplified manpages
      ]
      ++ lib.optionals host.isDev [
        # Install on dev machines (desktops, macOS, WSL):
        astroterm # show stars in terminal
        gh # GitHub CLI
        golazo # show soccer scores in terminal
        kubectl # kubernetes CLI
      ]
      ++ lib.optionals (host.isDesktop || host.isDarwin) [
        (writeShellScriptBin "auto-upgrade" scripts.auto-upgrade)
      ]
      ++ lib.optionals isDarwin [
        # Install on MacOS only:
        (writeShellScriptBin "random-album-of-the-day" scripts.random-album-of-the-day)
        (writeShellScriptBin "random-wallpaper" (scripts.random-wallpaper ./wallpaper))
        (writeShellScriptBin "spotify-like" scripts.spotify-like)
        clippy-darwin # cli to copy/paste files (used by yazi plugin)
        comma # run programs not installed but in nixpkgs
        tesseract # Enable OCR
      ]
      ++ lib.optionals isGraphical [
        # Install on MacOS and NixOS Desktop
        android-tools # android studio and emulator
        atai # openai wrapper to write in the terminal for me
        d2 # dot alternative (create beautiful graphs)
        dbeaver-bin # database explorer (postgres, mysql, etc.)
        gcalcli # Google Calendar CLI
        obsidian # notes
        prismlauncher # minecraft mod launcher
        yt-dlp # youtube downloader
        zathura # pdf viewer
      ]
      ++ lib.optionals isDesktop ([
          # Install on NixOS Desktop only
          amberol # fancy mp3 player
          apostrophe # Markdown Viewer
          diebahn # deutsche bahn arrivals/departures/delays
          gaphor # UML and SysML Editor
          gimp-with-plugins # maxxed out gimp
          gnome-chess # chess
          gnome-clocks # alarms, timers, etc.
          gnome-decoder # qr code generator
          gnome-font-viewer # View Fonts
          gnome-network-displays # airplay, chromecast, miracast
          gnome-weather # weather forecast
          gradia # Screenshot annotation tool
          inkscape-with-extensions # maxxed out inkscape
          jetbrains.idea # intellij idea ultimate
          libnotify # send notifications from terminal
          xdg-utils # xdg-open, etc.
          loupe # Gnome Image Viewer
          nautilus # file browser
          networkmanagerapplet # show wifi/ethernet in sys. tray
          pavucontrol # sound manager
          polkit_gnome # policy agent
          postman # API Inspection
          shortwave # Web Radio
          signal-desktop # Signal messenger
          slack # Work Communications
          stockfish # chess engine to play against computer
          supertuxkart # Mario Kart Linux
          whatsapp-electron # whatsapp
          wireplumber # pipewire manager
        ]
        ++ (
          if isWayland
          then [
            # Install on Wayland only
            hyprcursor # fancy cursor
            hyprpicker # color picker
            hyprshot # screenshot tool
            hyprutils # hyprland stuff
            nwg-displays # monitor manager
          ]
          else [
            # Install on X11 only
            arandr # x11 monitor manager (resolution, position, etc.)
            feh # set wallpaper on x11
          ]
        )
        ++ (
          if isX86
          then [
            # Install on x86 only
            discord # discord
            spotify # spotify
          ]
          else [
            # Install on arm64 only
            legcord # discord alternative
          ]
        )));
}
