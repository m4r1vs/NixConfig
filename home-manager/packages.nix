{
  pkgs,
  osConfig,
  scripts,
  systemArgs,
  ...
}: let
  isDesktop = osConfig.configured ? desktop && osConfig.configured.desktop.enable;
  isWayland = osConfig.configured ? desktop && !osConfig.configured.desktop.x11;
  isDarwin = systemArgs.system == "aarch64-darwin";
  isX86 = systemArgs.system == "x86_64-linux";
  isGraphical = isDarwin || isDesktop;
in {
  home.packages = with pkgs;
    [
      # Install on every system:
      astroterm # show stars in terminal
      fastfetch # new neofetch
      kubectl # kubernetes CLI
      golazo # show soccer scores in terminal
      pastel # manipulate colors and palettes
      xdg-utils # xdg-open, etc.
    ]
    ++ lib.optionals isDarwin [
      # Install on MacOS only:
      (writeShellScriptBin "random-album-of-the-day" scripts.random-album-of-the-day)
      clippy-darwin # cli to copy/paste files (used by yazi plugin)
      comma # run programs not installed but in nixpkgs
    ]
    ++ lib.optionals isGraphical [
      # Install on MacOS and NixOS Desktop
      android-tools # android studio and emulator
      atai # openai wrapper to write in the terminal for me
      dbeaver-bin # database explorer (postgres, mysql, etc.)
      gemini-cli # vibecoding
      obsidian # notes
      prismlauncher # minecraft mod launcher
      yt-dlp # youtube downloader
      zathura # pdf viewer
    ]
    ++ lib.optionals isDesktop ([
        # Install on NixOS Desktop only
        amberol # fancy mp3 player
        diebahn # deutsche bahn arrivals/departures/delays
        gimp-with-plugins # maxxed out gimp
        shortwave # Web Radio
        whatsapp-electron # whatsapp
        signal-desktop # Signal messenger
        gnome-chess # chess
        gnome-clocks # alarms, timers, etc.
        gnome-decoder # qr code generator
        gnome-network-displays # airplay, chromecast, miracast
        gnome-weather # weather forecast
        inkscape-with-extensions # maxxed out inkscape
        jetbrains.idea # intellij idea ultimate
        kdePackages.kwalletmanager # view keychain
        libnotify # send notifications from terminal
        nautilus # file browser
        networkmanagerapplet # show wifi/ethernet in sys. tray
        pavucontrol # sound manager
        polkit_gnome # policy agent
        stockfish # chess engine to play against computer
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
          swayimg # image viewer
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
      ));
}
