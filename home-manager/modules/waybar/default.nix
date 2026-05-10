{
  lib,
  config,
  scripts,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.waybar;
  theme = systemArgs.theme;
in {
  options.programs.configured.waybar = {
    enable = mkEnableOption "Wayland Statusbar";
  };
  config = mkIf cfg.enable {
    home.file.".config/waybar/style-light.css".text =
      /*
      css
      */
      ''
        @define-color module-background ${theme.backgroundColorLight};
        @define-color main-foreground #000000;
        @define-color ws-active-foreground #000000;

        @import url("/home/${systemArgs.username}/.theme/waybar/colors.css");
        @import url("${builtins.path {path = ./base.css;}}");
      '';
    home.file.".config/waybar/style-dark.css".text =
      /*
      css
      */
      ''
        @define-color module-background ${theme.backgroundColor};
        @define-color main-foreground rgba(214,214,214,1);
        @define-color ws-active-foreground #000000;

        @import url("/home/${systemArgs.username}/.theme/waybar/colors.css");
        @import url("${builtins.path {path = ./base.css;}}");
      '';

    programs.waybar = {
      package = pkgs.waybar;
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "bottom";
          height = 26;
          exclusive = true;
          passthrough = false;
          gtk-layer-shell = true;
          reload_style_on_change = true;

          modules-left = ["group/os-logo" "group/media-and-volume"];
          modules-center = ["group/workspaces-and-privacy"];
          modules-right = ["group/misc" "group/tray-and-battery"];

          "group/os-logo" = {
            orientation = "horizontal";
            modules = [
              "custom/os-logo"
              "hyprland/window"
            ];
          };

          "group/media-and-volume" = {
            orientation = "horizontal";
            modules = [
              "custom/media"
              "pulseaudio"
            ];
          };

          "group/workspaces-and-privacy" = {
            orientation = "horizontal";
            modules = [
              "hyprland/workspaces"
              "privacy"
              "custom/webcam"
            ];
          };

          "group/misc" = {
            orientation = "horizontal";
            modules = [
              "backlight"
              "cpu"
              "memory"
              "disk"
              "custom/caffeinate"
            ];
          };

          "group/tray-and-battery" = {
            orientation = "horizontal";
            modules = [
              "custom/weather"
              "custom/github"
              "custom/gcal"
              "tray"
              "battery"
              "custom/notifications"
              "clock"
            ];
          };

          clock = {
            format = "{:%b %d %H:%M}";
            interval = 60;
            rotate = 0;
            tooltip-format = "<span>{calendar}</span>";
            calendar = {
              mode = "month";
              mode-mon-col = 3;
              on-scroll = 1;
              iso8601 = true;
              format = {
                months = "<span color='${theme.primaryColor.hex}'><b>{}</b></span>";
                weekdays = "<span color='${theme.secondaryColor.hex}'><b>{}</b></span>";
                today = "<span color='#D14D41'><b>{}</b></span>";
              };
            };
            actions = {
              on-click = "mode";
              on-click-right = "mode";
              on-click-middle = "shift_reset";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cpu = {
            interval = 10;
            format = " {usage}%";
            rotate = 0;
          };

          memory = {
            states = {
              c = 90;
              h = 60;
              m = 30;
            };
            interval = 30;
            format = " {avail}GiB";
            rotate = 0;
            format-m = " {avail}GiB";
            format-h = " {avail}GiB";
            format-c = " {avail}GiB";
            max-length = 14;
            tooltip = true;
            tooltip-format = " {percentage}%\n {used:0.1f}GB/{total:0.1f}GB";
          };

          "custom/os-logo" = {
            exec = "echo '  '";
            interval = "once";
            rotate = 0;
            tooltip = false;
            on-click = "${scripts.rofi-launch} search";
            on-click-right = "${scripts.rofi-launch} power";
          };

          "custom/github" = {
            exec = "${scripts.waybar-github}";
            on-click = "${pkgs.xdg-utils}/bin/xdg-open https://github.com/notifications";
            interval = 60;
            format = "{}";
            rotate = 0;
            tooltip = true;
            return-type = "json";
          };

          "custom/media" = {
            exec = "${scripts.mediaplayer-wrapper}";
            format = "{}";
            return-type = "json";
            on-click = "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle";
            on-click-right = "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-next";
            on-click-middle = "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-prev";
            max-length = 52;
            escape = true;
            tooltip = true;
          };

          "custom/notifications" = {
            tooltip = false;
            format = "{icon}";
            format-icons = {
              notification = "<span foreground='${theme.primaryColor.hex}'><sup></sup></span>";
              none = "";
              dnd-notification = "<span foreground='${theme.primaryColor.hex}'><sup></sup></span>";
              dnd-none = "";
              inhibited-notification = "<span foreground='${theme.primaryColor.hex}'><sup></sup></span>";
              inhibited-none = "󰮯";
              dnd-inhibited-notification = "<span foreground='${theme.primaryColor.hex}'><sup></sup></span>";
              dnd-inhibited-none = "󱝁";
            };
            return-type = "json";
            exec = "${pkgs.swaynotificationcenter}/bin/swaync-client -swb";
            on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t -sw";
            on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -d -sw";
            escape = true;
          };

          "custom/webcam" = {
            return-type = "text";
            interval = 2;
            escape = true;
            tooltip = false;
            exec = "${scripts.webcam-privacy}";
          };

          "custom/weather" = {
            format = "{}";
            tooltip = true;
            interval = 1800;
            exec = "${pkgs.wttrbar}/bin/wttrbar --nerd --location Hamburg --custom-indicator \"{ICON} {temp_C}°C\"";
            on-click = "${lib.getExe pkgs.ghostty} --class=ghostty.weather --wait-after-command=true -e ${pkgs.curl}/bin/curl https://wttr.in";
            on-click-right = "${pkgs.xdg-utils}/bin/xdg-open https://www.wetteronline.de/regenradar/hamburg";
            return-type = "json";
          };

          "custom/gcal" = {
            exec = "${scripts.waybar-gcal}";
            on-click = "${pkgs.xdg-utils}/bin/xdg-open https://calendar.google.com/calendar/r";
            interval = 300;
            max-length = 72;
            format = "{}";
            rotate = 0;
            tooltip = true;
            return-type = "json";
          };

          "custom/caffeinate" = {
            exec = "${scripts.caffeinate}";
            format = "{}";
            interval = 5;
            on-click = "${scripts.caffeinate} toggle";
            return-type = "json";
            tooltip = true;
          };

          "hyprland/workspaces" = {
            rotate = 0;
            all-outputs = false;
            active-only = false;
            on-click = "activate";
            disable-scroll = true;
            on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace -1";
            on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace +1";
            persistent-workspaces = {};
          };

          "hyprland/window" = {
            rotate = 0;
            format = "{title}";
            rewrite = {
              "^$" = "";
              "(.*) - YouTube - Brave" = " $1";
              "(.*)YouTube - Brave" = " YouTube";
              "Reddit - (.*) - Brave" = " $1";
              "(.*) - Reddit - Brave" = " $1";
              "(.+) : r/(.+) - Brave" = " r/$2";
              "(.*) / X - Brave" = "󰕄 $1";
              "(.*) / Twitter - Brave" = "󰕄 $1";
              "(.*) - Google Gemini - Brave" = "󰫢 $1";
              "Google Gemini - Brave" = "󰫢 Gemini";
              "(.*) - Gmail - Brave" = "󰊫 $1";
              "Google Calendar - (.*) - Brave" = " $1";
              "Google - Brave" = " Google Search";
              "(.*) - Google Search - Brave" = " $1";
              "Google Maps - Brave" = "󰗵 Google Maps";
              "(.*) - Google Maps - Brave" = "󰗵 $1";
              "(.*) - Wikipedia - Brave" = "󰖬 $1";
              "(.*) - Google Photos - Brave" = " Viewing $1";
              "Nerd Fonts - (.*) - Brave" = " Nerd Fonts";
              "tagesschau.de - (.*) \\\| tagesschau.de - Brave" = " Tagesschau";
              "(.*) \\\| tagesschau.de - Brave" = " $1";
              "NDR.de - (.*) \\\| ndr.de - Brave" = " Norddeutscher Rundfunk";
              "(?!NDR\.de)(.*) \\\| ndr.de - Brave" = " $1";
              "The New York Times - (.*) - Brave" = " The New York Times";
              "(.*) - The New York Times - Brave" = " $1";
              "DER SPIEGEL \\\| Online-Nachrichten - Brave" = " DER SPIEGEL";
              "(.*) - DER SPIEGEL - Brave" = " $1";
              "(.*) \\\| (.+) \\\| online ansehen / LiveTV - Brave" = "󰟴 $1";
              "Wolfram\\\|Alpha: Computational Intelligence - Brave" = "󰧑 Wolfram|Alpha";
              "(.*) - Wolfram\\\|Alpha - Brave" = "󰧑 $1";
              "(.*)Instagram - Brave" = " Instagram";
              "(.*) Instagram • Messages - Brave" = " $1 Messages";
              "ChatGPT - Brave" = "󰙓 ChatGPT";
              "Monkeytype \\\| (.*) - Brave" = "󰌓 monkey see, monkey type";
              "NixOS Search - (.*) - Brave" = " Nix Search: $1";
              "([^/ ]+/[^/ ]+):.* - Brave" = " $1";
              "(.*) · (.+) · ([^/ ]+/[^/ ]+) - Brave" = " $3 - $2";
              "(.+) · ([^/ ]+/[^/ ]+) - Brave" = " $2 - $1";
              "(.*) - Discord" = " $1";
              "(.*) — 1Password" = "󰌋 $1";
              "1Password" = "󰌋 Authorize 1Password";
              "/nix/store/(.+)/(.*)" = "󰊠 $2";
              "^Ghostty$" = "󰊠 Ghostty";
              "Yazi: (.*)" = "󰇥 $1";
              "Volume Control" = " Volume Control";
              "KDE Connect" = " KDE Connect";
              "Shortwave" = " Shortwave";
              "Signal" = "󰭻 Signal";
              "Steam" = " Steam";
              "Bluetooth Devices" = "󰂯 Bluetooth Manager";
              "(.*) - Obsidian (.*)" = "󰂺 $1";
              "WhatsApp Electron :: (.*)" = " $1";
              "^.+$" = "󰁕 $0 ";
              "^(.*) - Brave$" = " $1";
            };
            max-length = 54;
            separate-outputs = true;
            icon = false;
          };

          backlight = {
            device = "intel_backlight";
            rotate = 0;
            format = "{icon} {percent}%";
            format-icons = ["" "" "" "" "" "" "" "" ""];
            on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set 1%+";
            on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 1%-";
            min-length = 6;
          };

          disk = {
            interval = 30;
            format = "󰋊 {free}";
            tooltip = true;
            tooltip-format = "󰋊 {percentage_used}%\n {used}/{total}";
          };

          pulseaudio = {
            format = "{icon}  {volume}";
            rotate = 0;
            format-muted = "";
            on-click = "${pkgs.pavucontrol}/bin/pavucontrol -t 3";
            on-click-right = "${pkgs.pamixer}/bin/pamixer -t";
            on-scroll-up = "${pkgs.pamixer}/bin/pamixer -i 1";
            on-scroll-down = "${pkgs.pamixer}/bin/pamixer -d 1";
            tooltip-format = "{icon} {desc} // {volume}%";
            scroll-step = 5;
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "󰓃";
              car = "";
              default = ["" "" ""];
            };
          };

          privacy = {
            icon-size = 10;
            icon-spacing = 5;
            transition-duration = 250;
            modules = [
              {
                type = "screenshare";
                tooltip = true;
                tooltip-icon-size = 24;
              }
              {
                type = "audio-in";
                tooltip = true;
                tooltip-icon-size = 24;
              }
            ];
            ignore = [
              {
                type = "audio-in";
                name = "cava";
              }
            ];
          };

          tray = {
            icon-size = 14;
            rotate = 0;
            spacing = 5;
            icons = {
              "blueman" = "bluetooth";
              "whatsapp" = "whatsapp";
              "KDE Connect Indicator" = "kdeconnect";
              "whatsapp-electron_status_icon_1" = "whatsapp";
              "steam" = "steam";
              "1password" = "1password";
              "1password-panel" = "1password";
              "1password-locked" = "1password";
              "1password-panel-locked" = "1password";
            };
          };

          battery = {
            states = {
              good = 95;
              warning = 30;
              critical = 20;
            };
            format = "{icon} {capacity}%";
            rotate = 0;
            format-charging = " {capacity}%";
            format-plugged = " {capacity}%";
            format-icons = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          };
        };
      };
    };
  };
}
