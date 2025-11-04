{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.services.configured.dunst;
  theme = systemArgs.theme;
in {
  options.services.configured.dunst = {
    enable = mkEnableOption "Simple X11 notification daemon.";
  };
  config = mkIf cfg.enable {
    services.dunst = {
      enable = true;
      package = pkgs.dunst;
      settings = {
        global = {
          # Display
          monitor = 0;
          follow = "keyboard";

          # Geometry
          width = "(420, 1200)";
          height = "(0, 300)";
          origin = "top-right";
          offset = "(0, 12)";
          scale = 0;
          notification_limit = 0;

          # Progress bar
          progress_bar = true;
          progress_bar_height = 12;
          progress_bar_frame_width = 0;
          progress_bar_corner_radius = 3;
          progress_bar_min_width = 408;
          progress_bar_max_width = 1188;

          # Other display settings
          indicate_hidden = true;
          transparency = 0;
          separator_height = 2;
          padding = 8;
          horizontal_padding = 8;
          text_icon_padding = 0;
          frame_width = 0;
          gap_size = 5;
          sort = true;

          # Text
          font = "JetBrainsMono Nerd Font 10";
          line_height = 2;
          markup = "full";
          format = "<b>%s</b>\\n%b";
          alignment = "left";
          vertical_alignment = "center";
          show_age_threshold = 60;
          ellipsize = "middle";
          ignore_newline = false;
          stack_duplicates = true;
          hide_duplicate_count = false;
          show_indicators = true;

          # Icons
          enable_recursive_icon_lookup = true;
          icon_theme = "Papirus, Adwaita";
          icon_position = "left";
          min_icon_size = 22;
          max_icon_size = 64;

          # History
          sticky_history = true;
          history_length = 20;

          # Misc/Advanced
          dmenu = "${pkgs.rofi}/bin/rofi -dmenu";
          browser = "${pkgs.xdg-utils}/bin/xdg-open";
          always_run_script = true;
          title = "Dunst";
          class = "Dunst";
          corner_radius = 4;
          corners = "left";
          ignore_dbusclose = false;

          # Mouse
          mouse_left_click = "do_action, close_current";
          mouse_middle_click = "close_current";
          mouse_right_click = "context";
        };

        experimental = {
          per_monitor_dpi = false;
        };

        nixpad = {
          appname = "nixpad";
          default_icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/apps/element4l.svg";
        };

        urgency_low = {
          background = "${theme.backgroundColor}";
          foreground = "${theme.backgroundColorLight}";
          highlight = "${theme.secondaryColor.hex}";
          timeout = 5;
        };

        urgency_normal = {
          background = "${theme.backgroundColor}";
          foreground = "${theme.backgroundColorLight}";
          highlight = "${theme.secondaryColor.hex}";
          timeout = 5;
        };
      };
    };
  };
}
