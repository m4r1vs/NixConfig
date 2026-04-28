{
  lib,
  config,
  pkgs,
  scripts,
  systemArgs,
  osConfig,
  ...
}:
with lib; let
  cfg = config.configured.xdg;
  theme = systemArgs.theme;
  hasPowerProfiles = osConfig.services.power-profiles-daemon.enable or false;
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
          "text/html" = ["brave-browser.desktop"];
          "text/plain" = ["nvim.desktop"];
          "text/x-markdown" = ["org.gnome.gitlab.somas.Apostrophe.desktop"];
          "image/svg+xml" = ["org.gnome.Loupe.desktop"];
          "image/jpeg" = ["org.gnome.Loupe.desktop"];
          "image/png" = ["org.gnome.Loupe.desktop"];
          "image/gif" = ["org.gnome.Loupe.desktop"];
          "image/heic" = ["org.gnome.Loupe.desktop"];
          "video/mp4" = ["mpv.desktop"];
          "video/webm" = ["mpv.desktop"];
          "video/quicktime" = ["mpv.desktop"];
          "video/mpeg" = ["mpv.desktop"];
          "audio/mpeg" = ["io.bassi.Amberol.desktop"];
          "audio/wav" = ["io.bassi.Amberol.desktop"];
          "audio/ogg" = ["io.bassi.Amberol.desktop"];
          "audio/flac" = ["io.bassi.Amberol.desktop"];
          "audio/aac" = ["io.bassi.Amberol.desktop"];
          "audio/webm" = ["io.bassi.Amberol.desktop"];
          "audio/mp4" = ["io.bassi.Amberol.desktop"];
        };
      };
      desktopEntries = {
        yazi = {
          name = "Yazi";
          icon = "duckstation";
          genericName = "Terminal File Manager";
          comment = "Blazing fast terminal file manager written in Rust, based on async I/O";
          terminal = false;
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.yazi -e ${pkgs.yazi}/bin/yazi %u";
          type = "Application";
          mimeType = ["inode/directory"];
          categories = ["Utility" "Core" "System" "FileTools" "FileManager"];
        };
        fastfetch = {
          name = "About this Computer";
          genericName = "Systeminfo";
          comment = "Fastfetch Information about this Computer";
          icon = "glxinfo";
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.fastfetch --wait-after-command=true -e ${pkgs.fastfetch}/bin/fastfetch";
          type = "Application";
          categories = ["Utility" "System" "Settings"];
        };
        hyprland-which-key = lib.mkIf osConfig.programs.hyprland.enable {
          name = "Keyboard Shortcuts and Commands";
          icon = "preferences-desktop-keyboard-shortcuts";
          exec = "${lib.getExe pkgs.hyprland-which-key} --accent-color \"${theme.secondaryColor.hex}\" --accent-color-light \"${theme.primaryColor.hex}\" --background-color \"${theme.backgroundColor}\" --background-color-light \"${theme.backgroundColorLight}\"";
          type = "Application";
          categories = ["Utility" "System"];
        };
        weather = {
          name = "Weather";
          genericName = "from wttr.in";
          comment = "Weather forecast from wttr.in";
          icon = "sunflower";
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.weather --wait-after-command=true -e ${pkgs.curl}/bin/curl https://wttr.in";
          type = "Application";
          categories = ["Utility"];
        };
        golazo = {
          name = "Golazo";
          genericName = "Soccer Scores";
          comment = "Keep track of soccer matches";
          icon = "football";
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.golazo -e ${pkgs.golazo}/bin/golazo";
          type = "Application";
          categories = ["Utility"];
        };
        screenshot_simple = {
          name = "Take Screenshot";
          genericName = "SUPER+S";
          icon = "gnome-screenshot";
          exec = "${scripts.screenshot}";
          type = "Application";
          categories = ["Utility"];
        };
        screenshot_edit = {
          name = "Take Screenshot and Edit";
          genericName = "SUPER+Shift+S";
          icon = "com.github.phase1geo.annotator";
          exec = "${scripts.screenshot} edit";
          type = "Application";
          categories = ["Utility"];
        };
        asciiquarium = {
          name = "Asciiquarium";
          genericName = "Fish.. and more!";
          comment = "Show and Aquarium -- but ASCII";
          icon = "cuttlefish";
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.asciiquarium -e ${pkgs.asciiquarium-transparent}/bin/asciiquarium -t";
          type = "Application";
          categories = ["Utility"];
        };
        astroterm = {
          name = "Astroterm";
          genericName = "Star Map";
          icon = "kstars";
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.astroterm -e ${pkgs.astroterm}/bin/astroterm";
          type = "Application";
          categories = ["Utility"];
        };
        darkman = {
          name = "Toggle Darkmode";
          genericName = "Shortcut: Super+Shift+D";
          exec = "${pkgs.darkman}/bin/darkman toggle";
          icon = "com.github.coslyk.MoonPlayer";
          type = "Application";
          noDisplay = false;
          categories = ["Settings"];
        };
        spotify_player = {
          name = "Spotify TUI";
          genericName = "Play Music in the Terminal!";
          exec = "${lib.getExe pkgs.ghostty} --class=ghostty.spotify_player -e ${pkgs.spotify-player}/bin/spotify_player";
          icon = "spotify-client";
          type = "Application";
          categories = ["Music" "X-Spotify"];
          noDisplay = true;
        };
        spotify-like = {
          name = "Like Currently Playing";
          genericName = "SUPER+F8";
          comment = "Like the currently playing track on Spotify";
          icon = "spotify-client";
          exec = "${scripts.spotify-like}";
          type = "Application";
          categories = ["Music" "X-Spotify"];
          noDisplay = false;
        };
        nvim = {
          name = "NeoVim";
          genericName = "New Improved Vim - Text Editor";
          icon = "vim";
          type = "Application";
          exec = "${lib.getExe pkgs.ghostty} -e nvim %u";
          settings = {
            Keywords = "Text;editor";
          };
          startupNotify = false;
          terminal = false;
          categories = ["Utility" "TextEditor" "Development"];
          mimeType = [
            "text/plain"

            "text/html"
            "text/css"
            "text/javascript"
            "application/javascript"
            "application/typescript"

            "application/json"
            "application/xml"
            "text/xml"
            "text/csv"
            "application/x-yaml"
            "text/yaml"

            "application/x-sh"
            "application/x-shellscript"
            "text/x-shellscript"

            "text/x-python"
            "text/x-csrc"
            "text/x-chdr"
            "text/x-c++src"
            "text/x-java-source"
            "text/x-go"
            "text/x-nix"
            "text/x-rust"
            "text/x-lua"

            "text/x-rst"
            "text/x-tex"
          ];
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
          genericName = "${osConfig.system.nixos.distroName} on ${systemArgs.hostname}";
          icon = "element4l";
          type = "Application";
          categories = ["Settings"];
          noDisplay = true;
        };
        update = {
          name = "Update System Packages";
          genericName = "Fetch latest from nixpkgs";
          icon = "builder";
          exec = "${lib.getExe pkgs.ghostty} --wait-after-command=true -e \"${lib.getExe pkgs.nix} flake update --flake ~/NixConfig\"";
          type = "Application";
          categories = ["Utility"];
        };
        rebuild = {
          name = "Rebuild System Configuration";
          comment = "Rebuild NixOS system Config";
          icon = "builder";
          exec = "${lib.getExe pkgs.ghostty} --wait-after-command=true -e ${scripts.rebuild}";
          type = "Application";
          categories = ["Utility"];
        };
        settings = {
          name = "Open and Edit System Configuration";
          comment = "Edit NixOS system config";
          icon = "mateconf-editor";
          exec = "${lib.getExe pkgs.ghostty} -e nvim \"/home/${systemArgs.username}/NixConfig/\"";
          type = "Application";
          categories = ["Utility" "Settings"];
        };
        brave-browser = {
          name = "Personal Browser";
          exec = ''${pkgs.brave}/bin/brave --profile-directory=Default --ozone-platform-hint=auto --enable-features=TouchpadOverscrollHistoryNavigation --password-store=gnome-libsecret %U'';
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
        caffeinate = {
          name = "Toggle Caffeination";
          genericName = "Cannot sleep on coffee";
          icon = "io.github.java_decompiler.jd-gui";
          exec = "${scripts.caffeinate} toggle";
          type = "Application";
          categories = ["Utility"];
        };
        cleartext-wifi = {
          name = "Show Wi-Fi Password";
          genericName = "Will also be copied";
          icon = "wifi-radar";
          exec = "${scripts.cleartext-wifi}";
          type = "Application";
          categories = ["Utility"];
        };
        rofi-ssh = {
          name = "SSH Launcher";
          genericName = "SUPER+Shift+Enter";
          comment = "Launch SSH session via Rofi";
          icon = "network-server";
          exec = "${scripts.rofi-launch} ssh";
          type = "Application";
          categories = ["Network" "Utility"];
        };
        rofi-obsidian = {
          name = "Search Obsidian Notes";
          genericName = "SUPER+Shift+O";
          comment = "Search Obsidian Notes using rofi";
          icon = "obsidian";
          exec = "${scripts.rofi-launch} obsidian";
          type = "Application";
          categories = ["Utility"];
        };
        rofi-emoji = {
          name = "Emoji Picker";
          genericName = "SUPER+M";
          comment = "Pick and copy emojis";
          icon = "it.mijorus.smile";
          exec = "${scripts.rofi-launch} emoji";
          type = "Application";
          categories = ["Utility"];
        };
        rofi-calc = {
          name = "Wolfram|Alpha Query with ChatGPT Fallback";
          genericName = "SUPER+C";
          comment = "Rofi based calculator";
          icon = "wolfram-language";
          exec = "${scripts.rofi-launch} calc";
          type = "Application";
          categories = ["Utility"];
        };
        rofi-wallpaper = {
          name = "Wallpaper Selector";
          genericName = "SUPER+Shift+W";
          comment = "Change desktop wallpaper";
          icon = "background";
          exec = "${scripts.rofi-launch} wallpaper";
          type = "Application";
          categories = ["Settings"];
        };
        rofi-power = {
          name = "Power Menu";
          genericName = "SUPER+Shift+Q";
          comment = "System power options";
          icon = "system-shutdown";
          exec = "${scripts.rofi-launch} power";
          type = "Application";
          categories = ["System"];
        };
        rofi-bluetooth = {
          name = "Bluetooth Manager";
          genericName = "SUPER+Shift+B";
          comment = "Manage bluetooth connections";
          icon = "bluetooth";
          exec = "${scripts.rofi-launch} bluetooth";
          type = "Application";
          categories = ["Settings" "Network"];
        };
        rofi-cliphist = {
          name = "Clipboard History";
          genericName = "SUPER+Shift+V";
          comment = "Browse clipboard history";
          icon = "xclipboard";
          exec = "${scripts.rofi-launch} cliphist";
          type = "Application";
          categories = ["Utility"];
        };
        random-album = {
          name = "Random Album of the Day";
          genericName = "SUPER+Shift+F8";
          comment = "Query bandcamp for a random daily album to play on Spotify";
          icon = "spotify-client";
          exec = "${scripts.random-album-of-the-day}";
          type = "Application";
          categories = ["Music" "X-Spotify"];
        };
        rofi-powermode = mkIf hasPowerProfiles {
          name = "Select Performance Mode";
          genericName = "Performance/Auto/Light";
          comment = "Change system power profile";
          icon = "mate-power-manager";
          exec = "${scripts.rofi-launch} powermode";
          type = "Application";
          categories = ["Settings" "System"];
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
