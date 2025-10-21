{
  lib,
  config,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.rofi;
  theme = systemArgs.theme;
in {
  options.programs.configured.rofi = {
    enable = mkEnableOption "DMENU and DRUN replacement";
  };
  config = mkIf cfg.enable {
    home.file."./.theme/rofi/dark.rasi".text =
      /*
      rasi
      */
      ''
        mainbox {
          background-color: transparent;
        }
        window {
          background-color: rgba(0, 0, 0, 0.24);
        }
        entry {
          text-color: #EFE7DD;
          placeholder-color: #b5afa7;
        }
        element {
          text-color: #EFE7DD;
        }
        element selected {
          background-color: rgba(${theme.secondaryColor.rgb}, 0.48);
          border-radius: 5px;
        }
      '';
    home.file."./.theme/rofi/light.rasi".text =
      /*
      rasi
      */
      ''
        mainbox {
          background-color: transparent;
        }
        window {
          background-color: rgba(245, 230, 204, 0.24);
        }
        entry {
          text-color: #000000;
          placeholder-color: #121212;
        }
        element {
          text-color: #000000;
        }
        element selected {
          background-color: rgba(${theme.secondaryColor.rgb}, 0.48);
          border-radius: 5px;
        }
      '';
    programs.rofi = {
      enable = true;
      package = pkgs.rofi;
      terminal = "${pkgs.ghostty}/bin/ghostty";
      extraConfig = {
        display-drun = "";
        display-dmenu = "";
        font = "JetBrainsMono NF SemiBold 12";
        location = 0;
        icon-theme = "Papirus";
        show-icons = true;
        kb-remove-to-eol = "";
        kb-mode-complete = "";
        kb-move-end = "";
        kb-accept-entry = "Return,KP_Enter";
        kb-remove-char-back = "BackSpace,Shift+BackSpace";
        kb-row-up = ["Control+k" "Alt+k"];
        kb-row-down = ["Control+j" "Alt+j"];
        kb-row-right = ["Control+l" "Alt+l"];
        kb-row-left = ["Control+h" "Alt+h"];
        kb-page-prev = ["Control+y" "Alt+y"];
        kb-page-next = ["Control+e" "Alt+e"];
      };
      theme = toString (pkgs.writeText "style.rasi"
        /*
        rasi
        */
        ''
          * {
            separatorcolor:     transparent;
            border-color:       transparent;
          }

          window {
            background-color: transparent;
            transparency: "real";
            fullscreen: true;
            orientation: vertical;
            padding: 27.5% 31.5%;
          }

          mainbox {
            border-radius: 4px;
          }

          icon-current-entry {
            background-color: transparent;
            size: 22 px;
            background-color: transparent;
            padding: 11 6 11 14;
            alignment: vertical;
          }

          element {
            background-color: transparent;
            padding: 4 12;
          }

          element-text {
            background-color: transparent;
            text-color: inherit;
          }

          element-icon {
            size: 24 px;
            background-color: transparent;
            padding: 0 6 0 0;
            alignment: vertical;
          }

          listview {
            background-color: transparent;
            columns: 1;
            padding: 8 0;
            fixed-height: true;
            fixed-columns: true;
            fixed-lines: true;
            border: 0 10 6 10;
          }

          entry {
            cursor-width: 0;
            blink: false;
            background-color: transparent;
            padding: 10 10 0 0;
            margin: 0 -2 0 0;
          }

          inputbar {
            background-color: transparent;
            padding: 0 0 0 8;
            margin: 0 0 0 0;
            children: [icon-current-entry, entry];
          }

          prompt {
            background-color: transparent;
            enabled: false;
          }

          @import "${config.home.homeDirectory}/.theme/rofi/current.rasi"
        '');
    };
  };
}
