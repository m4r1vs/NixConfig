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
      kubernetes-helm
      w3m-full
      xdg-utils
      yt-dlp
      pkgs.gemini-cli-bin
    ]
    ++ lib.optionals isDarwin [
      podman
      comma
      clippy-darwin
      vscode
    ]
    ++ lib.optionals isGraphical [
      blender
      dbeaver-bin
      obsidian
      zathura
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
