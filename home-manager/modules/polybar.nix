{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.services.configured.polybar;
  theme = systemArgs.theme;
in {
  options.services.configured.polybar = {
    enable = mkEnableOption "Enable Polybar Statusbar";
  };
  config = mkIf cfg.enable {
    home.file."./.theme/polybar/dark.ini".text = ''
      background=${theme.backgroundColor}
      foreground=${theme.backgroundColorLight}
      tray-background=${theme.backgroundColor}
      primary=${theme.primaryColor.hex}
      secondary=${theme.secondaryColor.hex}
    '';
    home.file."./.theme/polybar/light.ini".text = ''
      background=${theme.backgroundColorLight}
      foreground=${theme.backgroundColor}
      tray-background=${theme.primaryColor.hex}
      primary=${theme.secondaryColor.hex}
      secondary=${theme.primaryColor.hex}
    '';
    services.polybar = {
      enable = true;
      package = pkgs.polybar;
      script = "sleep infinity"; # Polybar started in i3
      settings = {
        settings = {
          screenchange-reload = "true";
          pseudo-transparency = "false";
        };
        colors = {
          include-file = "${config.home.homeDirectory}/.theme/polybar/current.ini";
        };
        "bar/clock" = {
          override-redirect = true;
          background = "\${colors.background}";
          border-size = "0pt";
          bottom = true;
          cursor-click = "pointer";
          cursor-scroll = "ns-resize";
          enable-ipc = "true";
          font-0 = "JetBrainsMono Nerd Font:style=SemiBold:size=8:antialias=true;2";
          foreground = "\${colors.foreground}";
          height = "22px";
          line-size = "3px";
          modules-center = "clock";
          monitor = "\${env:MONITOR:}";
          offset-x = "6px";
          offset-y = "4px";
          width = "74px";
          wm-restack = "i3";
        };
        "bar/media" = {
          override-redirect = true;
          background = "\${colors.background}";
          border-size = "0pt";
          bottom = true;
          cursor-click = "pointer";
          cursor-scroll = "ns-resize";
          enable-ipc = "true";
          font-0 = "JetBrainsMono Nerd Font:style=SemiBold:size=9:antialias=true;2";
          foreground = "\${colors.foreground}";
          height = "22px";
          line-size = "3px";
          modules-center = "pulseaudio";
          monitor = "\${env:MONITOR:}";
          offset-x = "86px";
          offset-y = "4px";
          width = "60px";
          wm-restack = "i3";
        };
        "bar/workspaces" = {
          override-redirect = true;
          background = "\${colors.background}";
          border-size = "0pt";
          bottom = true;
          cursor-click = "pointer";
          cursor-scroll = "ns-resize";
          enable-ipc = "true";
          font-0 = "JetBrainsMono Nerd Font:style=SemiBold:size=9:antialias=true;2";
          foreground = "\${colors.foreground}";
          height = "22px";
          radius = 4;
          line-size = "3px";
          modules-left = "i3";
          modules-center = "xworkspaces";
          monitor = "\${env:MONITOR:}";
          offset-x = "50%:-116px";
          offset-y = "4px";
          width = "232px";
          wm-restack = "i3";
        };
        "bar/tray" = {
          override-redirect = true;
          background = "\${colors.tray-background}";
          border-size = "0pt";
          bottom = true;
          cursor-click = "pointer";
          cursor-scroll = "ns-resize";
          enable-ipc = "true";
          font-0 = "JetBrainsMono Nerd Font:style=SemiBold:size=9:antialias=true;2";
          foreground = "\${colors.foreground}";
          height = "22px";
          line-size = "3px";
          modules-center = "tray";
          monitor = "\${env:MONITOR:}";
          offset-x = "100%:-458px";
          offset-y = "4px";
          width = "120px";
          wm-restack = "i3";
        };
        "bar/sysinfo" = {
          override-redirect = true;
          background = "\${colors.background}";
          border-size = "0pt";
          bottom = true;
          cursor-click = "pointer";
          cursor-scroll = "ns-resize";
          enable-ipc = "true";
          font-0 = "JetBrainsMono Nerd Font:style=SemiBold:size=9:antialias=true;2";
          foreground = "\${colors.foreground}";
          height = "22px";
          line-size = "3px";
          separator = "\"  \"";
          modules-center = "memory cpu wlan eth battery";
          monitor = "\${env:MONITOR:}";
          offset-x = "100%:-332px";
          offset-y = "4px";
          width = "326px";
          wm-restack = "i3";
        };
        "module/pulseaudio" = {
          type = "internal/pulseaudio";
          use-ui-max = false;
          format-volume = "<ramp-volume> <label-volume>";
          label-volume = "%percentage%%";
          ramp-volume-0 = "󰕿";
          ramp-volume-1 = "󰖀";
          ramp-volume-2 = "󰕾";
          ramp-volume-foreground = "\${colors.secondary}";
          label-muted = "󰖁";
          label-muted-foreground = "\${colors.secondary}";
        };
        "module/i3" = {
          type = "internal/i3";
          format = "<label-mode>";
          label-mode = "\"   \"";
          label-mode-foreground = "\${colors.background}";
          label-mode-background = "\${colors.secondary}";
          pin-workspaces = "true";
        };
        "module/battery" = {
          type = "internal/battery";
          full-at = "98";
          low-at = "20";
          battery = "BAT0";
          adapter = "AC";
          poll-interval = "5";

          format-discharging = "<ramp-capacity> <label-discharging>";
          label-discharging = "%percentage%%";

          format-charging = "<animation-charging> <label-charging>";
          label-charging = "%percentage%%";

          format-full = "<ramp-capacity> <label-full>";
          label-full = "100%";

          format-low = "<ramp-capacity> <label-low>";
          label-low = "%percentage%%";

          ramp-capacity-0 = "󰁻";
          ramp-capacity-1 = "󰁼";
          ramp-capacity-2 = "󰁾";
          ramp-capacity-3 = "󰂁";
          ramp-capacity-4 = "󰁹";
          ramp-capacity-foreground = "\${colors.secondary}";

          animation-charging-0 = "󰁻";
          animation-charging-1 = "󰁼";
          animation-charging-2 = "󰁾";
          animation-charging-3 = "󰂁";
          animation-charging-4 = "󰁹";
          animation-charging-foreground = "\${colors.secondary}";
          animation-charging-framerate = 750;
        };
        "module/xworkspaces" = {
          type = "internal/xworkspaces";
          pin-workspaces = "true";
          group-by-monitor = "true";

          label-active = "%name%";
          label-active-padding = "1";
          label-active-foreground = "\${colors.background}";
          label-active-background = "\${colors.secondary}";

          label-occupied = "%name%";
          label-occupied-padding = "1";
          label-occupied-foreground = "\${colors.foreground}";

          label-urgent = "%name%!";
          label-urgent-padding = "1";
          label-urgent-foreground = "\${colors.foreground}";

          label-empty = "%name%";
          label-empty-padding = "1";
          label-empty-foreground = "\${colors.foreground}";
        };
        "module/tray" = {
          type = "internal/tray";
          format-margin = "0px";
          tray-spacing = "2px";
          tray-foreground = "${theme.backgroundColor}";
        };
        "module/memory" = {
          type = "internal/memory";
          interval = "2";
          format-prefix = " ";
          format-prefix-foreground = "\${colors.secondary}";
          label = "%gb_free%";
        };
        "module/cpu" = {
          type = "internal/cpu";
          interval = "2";
          format-prefix = " ";
          format-prefix-foreground = "\${colors.secondary}";
          label = "%percentage:2%%";
        };
        network-base = {
          type = "internal/network";
          interval = 5;
        };
        "module/wlan" = {
          "inherit" = "network-base";
          interface-type = "wireless";
          interface = "\${env:WLAN_INTERFACE}";

          format-connected = "<ramp-signal> <label-connected>";
          label-connected = "%local_ip%";

          format-disconnected = "<label-disconnected>";
          format-disconnected-prefix = "󰤭";
          label-disconnected = "Disconnected";

          format-packetloss = "<label-packetloss>";
          format-packetloss-prefix = "󰤣";
          label-packetloss = "%local_ip%";

          ramp-signal-0 = "󰤯";
          ramp-signal-1 = "󰤟";
          ramp-signal-2 = "󰤢";
          ramp-signal-3 = "󰤥";
          ramp-signal-4 = "󰤨";
          ramp-signal-5 = "󰤨";
          ramp-signal-foreground = "\${colors.secondary}";
        };
        "module/eth" = {
          "inherit" = "network-base";
          interface-type = "wired";
          interface = "enp0s31f6";
          format-prefix = "󰒍";
          format-prefix-foreground = "\${colors.secondary}";
        };
        "module/clock" = {
          type = "internal/date";
          interval = "1";
          date = "%H:%M:%S";
          label = "%date%";
          label-foreground = "\${colors.foreground}";
        };
      };
    };
  };
}
