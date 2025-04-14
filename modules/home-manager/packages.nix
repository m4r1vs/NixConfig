{
  pkgs,
  osConfig,
  ...
}: let
  isDesktop = osConfig.configured.desktop.enable;
  isWayland = !osConfig.configured.desktop.x11;
in {
  home.packages = with pkgs;
    [
      fastfetch
      yt-dlp
      xdg-utils
    ]
    ++ lib.optionals isDesktop ([
        amberol
        blender
        dbeaver-bin
        diebahn
        discord
        gimp-with-plugins
        gnome-chess
        gnome-clocks
        gnome-decoder
        gnome-network-displays
        inkscape-with-extensions
        kdePackages.kwalletmanager
        libnotify
        nautilus
        networkmanagerapplet
        obsidian
        pavucontrol
        polkit_gnome
        slack
        stockfish
        wireplumber
        zathura
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
