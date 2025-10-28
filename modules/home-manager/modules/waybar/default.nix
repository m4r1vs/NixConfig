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
        @define-color bar-bg rgba(0,0,0,0);
        @define-color main-bg ${theme.backgroundColorLight};
        @define-color main-fg #000000;
        @define-color wb-act-bg ${theme.primaryColor.hex};
        @define-color wb-act-fg rgba(252,252,252,1);
        @define-color wb-hvr-bg rgba(0,0,0,0.1);
        @define-color wb-hvr-fg #000000;

        @import url("${builtins.path {path = ./base.css;}}");
      '';
    home.file.".config/waybar/style-dark.css".text =
      /*
      css
      */
      ''
        @define-color bar-bg rgba(0,0,0,0);
        @define-color main-bg ${theme.backgroundColor};
        @define-color main-fg rgba(214,214,214,1);
        @define-color wb-act-bg ${theme.primaryColor.hex};
        @define-color wb-act-fg rgba(252,252,252,1);
        @define-color wb-hvr-bg rgba(61,61,61,0.4);
        @define-color wb-hvr-fg rgba(214,214,214,0.8);

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

          modules-left = ["group/time-and-sysinfo" "group/media-and-volume"];
          modules-center = ["group/workspaces-and-privacy"];
          modules-right = ["group/misc" "group/tray-and-battery"];

          "group/time-and-sysinfo" = {
            orientation = "horizontal";
            modules = [
              "clock"
              "cpu"
              "custom/cpuinfo"
              "memory"
              "disk"
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
              "network"
              "custom/notifications"
            ];
          };

          "group/tray-and-battery" = {
            orientation = "horizontal";
            modules = [
              "custom/weather"
              "tray"
              "battery"
            ];
          };

          clock = {
            format = "{:%H:%M %p}";
            rotate = 0;
            format-alt = "{:%R 󰃭 %d·%m·%y}";
            tooltip-format = "<span>{calendar}</span>";
            calendar = {
              mode = "month";
              mode-mon-col = 3;
              on-scroll = 1;
              on-click-right = "mode";
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b>{}</b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-click-forward = "tz_up";
              on-click-backward = "tz_down";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cpu = {
            interval = 10;
            format = " {usage}%";
            rotate = 0;
            format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
          };

          memory = {
            states = {
              c = 90;
              h = 60;
              m = 30;
            };
            interval = 30;
            format = " {used}GB";
            rotate = 0;
            format-m = " {used}GB";
            format-h = " {used}GB";
            format-c = " {used}GB";
            max-length = 10;
            tooltip = true;
            tooltip-format = " {percentage}%\n {used:0.1f}GB/{total:0.1f}GB";
          };

          "custom/cpuinfo" = {
            exec = "${scripts.cpu-info}";
            return-type = "json";
            format = "{}";
            rotate = 0;
            interval = 10;
            tooltip = true;
            max-length = 1000;
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
            format = "{}°C";
            tooltip = true;
            interval = 1800;
            exec = "${pkgs.wttrbar}/bin/wttrbar --custom-indicator \"{temp_C}\"";
            return-type = "json";
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
          backlight = {
            device = "intel_backlight";
            rotate = 0;
            format = "{icon} {percent}%";
            format-icons = ["" "" "" "" "" "" "" "" ""];
            on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set 1%+";
            on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 1%-";
            min-length = 6;
          };

          network = {
            tooltip = true;
            rotate = 0;
            tooltip-format = "Network: <big><b>{essid}</b></big>\nSignal strength: <b>{signaldBm}dBm ({signalStrength}%)</b>\nFrequency: <b>{frequency}MHz</b>\nInterface: <b>{ifname}</b>\nIP: <b>{ipaddr}/{cidr}</b>\nGateway: <b>{gwaddr}</b>\nNetmask: <b>{netmask}</b>";
            format-linked = "󰈀 {ifname} (No IP)";
            tooltip-format-disconnected = "Disconnected";
            format = "<span foreground='${theme.primaryColor.hex}'> {bandwidthDownBytes}</span> <span foreground='${theme.secondaryColor.hex}'> {bandwidthUpBytes}</span>";
            interval = 2;
          };

          disk = {
            interval = 30;
            format = "󰋊 {free}";
            tooltip = true;
            tooltip-format = "󰋊 {percentage_used}%\n {used}/{total}";
          };

          pulseaudio = {
            format = "{icon} {volume}";
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
              portable = "";
              car = "";
              default = ["" "" ""];
            };
          };

          # "pulseaudio#microphone = {
          #     "format = "{format_source}";
          #     "rotate = 0;
          #     "format-source = "";
          #     "format-source-muted = "";
          #     "on-click = "pavucontrol -t 4";
          #     "on-click-middle = "volumecontrol.sh -i m";
          #     "on-scroll-up = "volumecontrol.sh -i i";
          #     "on-scroll-down = "volumecontrol.sh -i d";
          #     "tooltip-format = "{format_source} {source_desc} // {source_volume}%";
          #     "scroll-step = 5
          # };

          #    "custom/updates = {
          #        "exec = "systemupdate.sh";
          #        "return-type = "json";
          #        "format = "{}";
          #        "rotate = 0;
          #        "on-click = "hyprctl dispatch exec 'systemupdate.sh up'";
          #        "interval = 86400, // once every day
          #        "tooltip = true;
          #        "signal = 20;
          #    };
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
          };

          tray = {
            icon-size = 14;
            rotate = 0;
            spacing = 5;
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

          "custom/l_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/r_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/sl_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/sr_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/rl_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/rr_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/padd" = {
            format = "  ";
            interval = "once";
            tooltip = false;
          };
        };
      };
    };
  };
}
