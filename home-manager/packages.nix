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
  isGraphical = isDarwin || isDesktop;
in {
  home.packages = with pkgs;
    [
      fastfetch
      kubectl
      xdg-utils
    ]
    ++ lib.optionals isDarwin [
      clippy-darwin
      comma
      podman
      (writeShellScriptBin "random-album-of-the-day" scripts.random-album-of-the-day)
    ]
    ++ lib.optionals isGraphical [
      blender
      dbeaver-bin
      obsidian
      prismlauncher
      vscode
      zathura
      gemini-cli
      yt-dlp
    ]
    ++ lib.optionals isDesktop ([
        amberol
        diebahn
        discord
        gimp-with-plugins
        gnome-chess
        gnome-clocks
        gnome-decoder
        gnome-network-displays
        inkscape-with-extensions
        jetbrains.idea-ultimate
        kdePackages.kwalletmanager
        libnotify
        nautilus
        networkmanagerapplet
        pavucontrol
        polkit_gnome
        scripts.artkube
        spotify
        stockfish
        wireplumber
      ]
      ++ (
        if isWayland
        then [
          hyprcursor
          hyprpicker
          hyprshot
          hyprutils
          swayimg
        ]
        else [
          arandr
          feh
        ]
      ));
}
