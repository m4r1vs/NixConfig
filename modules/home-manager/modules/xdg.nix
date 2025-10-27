{
  lib,
  config,
  pkgs,
  scripts,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.xdg;
in {
  options.configured.xdg = {
    enable = mkEnableOption "Cross-Desktop-Group";
  };
  config = mkIf cfg.enable {
    home.file."./.config/xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd=${scripts.term-file-chooser}
      default_dir=$HOME
      env=TERMCMD=${pkgs.ghostty}/bin/ghostty
    '';
    home.file."./.config/xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      org.freedesktop.impl.portal.FileChooser=termfilechooser
    '';
    home.file.".icons/default".source = "${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Ice";
    xdg = {
      userDirs = {
        enable = true;
        createDirectories = true;
        extraConfig = {
          XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
        };
      };
      mimeApps = {
        enable = true;
        defaultApplications = {
          "application/pdf" = ["org.pwmt.zathura-pdf-mupdf.desktop"];
          "inode/directory" = ["yazi.desktop"];
        };
      };
      desktopEntries = {
        yazi = {
          name = "Yazi";
          icon = "duckstation";
          comment = "Blazing fast terminal file manager written in Rust, based on async I/O";
          terminal = false;
          exec = "${pkgs.ghostty}/bin/ghostty --class=ghostty.yazi -e EDITOR=nvim ${pkgs.yazi}/bin/yazi %u";
          type = "Application";
          mimeType = ["inode/directory"];
          categories = ["Utility" "Core" "System" "FileTools" "FileManager"];
        };
        darkman = {
          name = "Toggle Darkmode";
          genericName = "Darkman";
          exec = "${pkgs.darkman}/bin/darkman toggle";
          icon = "com.github.coslyk.MoonPlayer";
          type = "Application";
          noDisplay = true;
          categories = ["Settings"];
        };
        spotify_player = {
          name = "Spotify TUI";
          genericName = "Spotify";
          icon = "spotify-client";
          type = "Application";
          categories = ["Music"];
          noDisplay = true;
        };
        blueman = {
          name = "Bluetooth";
          genericName = "Blueman";
          icon = "blueman";
          type = "Application";
          categories = ["Settings"];
          noDisplay = true;
        };
        "${systemArgs.hostname}" = {
          name = "Marius' ${systemArgs.hostname}";
          genericName = "NixOS on ${systemArgs.hostname}";
          icon = "element4l";
          type = "Application";
          categories = ["Settings"];
          noDisplay = true;
        };
        brave-browser = {
          name = "Personal Browser";
          exec = ''${pkgs.brave}/bin/brave --profile-directory=Default --ozone-platform-hint=auto --use-gl=desktop --enable-features=TouchpadOverscrollHistoryNavigation %U'';
          icon = "brave-browser-nightly";
          terminal = false;
          type = "Application";
          categories = ["WebBrowser" "Network"];
          mimeType = [
            "application/pdf"
            "application/rdf+xml"
            "application/rss+xml"
            "application/xhtml+xml"
            "application/xhtml_xml"
            "application/xml"
            "image/gif"
            "image/jpeg"
            "image/png"
            "image/webp"
            "text/html"
            "text/xml"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ];
        };
      };
      portal = {
        enable = true;
        config.common.default = "*";
        extraPortals = [
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-termfilechooser
        ];
      };
    };
  };
}
