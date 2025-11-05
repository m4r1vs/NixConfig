{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.yabai;
in {
  options.services.configured.yabai = {
    enable = mkEnableOption "Enable the Yabai tiling WM for MacOS";
  };

  config = mkIf cfg.enable {
    system.defaults.finder.CreateDesktop = mkForce true;
    services = {
      yabai = {
        enable = true;
        package = pkgs.yabai;
        config = {
          focus_follows_mouse = "autoraise";
          layout = "bsp";
          mouse_follows_focus = "on";
          window_placement = "second_child";
          window_opacity = "on";
          active_window_opacity = 1.0;
          normal_window_opacity = 0.96;
          # top_padding = 8;
          bottom_padding = 8;
          left_padding = 8;
          right_padding = 8;
          window_gap = 8;
          window_animation_duration = 0.2;
        };
        extraConfig = ''
          yabai -m rule --add app="^Riot Client$" manage=off
          yabai -m rule --add app="^League of Legends$" manage=off

          yabai -m space 1 --label one
          yabai -m space 2 --label two
          yabai -m space 3 --label three
          yabai -m space 4 --label four
          yabai -m space 5 --label five
          yabai -m space 6 --label six
          yabai -m space 7 --label six
          yabai -m space 8 --label six
          yabai -m space 9 --label nine
        '';
        enableScriptingAddition = true;
      };
      skhd = {
        package = pkgs.skhd;
        enable = true;
        skhdConfig = ''
          cmd - q : yabai -m window --close

          cmd - h: yabai -m window --focus west || yabai -m display --focus west
          cmd - j: yabai -m window --focus south || yabai -m display --focus south
          cmd - k: yabai -m window --focus north || yabai -m display --focus north
          cmd - l: yabai -m window --focus east || yabai -m display --focus east

          cmd + shift - h : yabai -m window --warp west \
            || yabai -m window --display west && yabai -m display --focus west

          cmd + shift - j : yabai -m window --warp south \
            || yabai -m window --display south && yabai -m display --focus south

          cmd + shift - k : yabai -m window --warp north \
            || yabai -m window --display north && yabai -m display --focus north

          cmd + shift - l : yabai -m window --warp east \
            || yabai -m window --display east && yabai -m display --focus east

          cmd + lshift - space: yabai -m window --toggle float

          cmd + lshift - f: yabai -m window --toggle zoom-fullscreen

          cmd + lshift - n: yabai -m space --move next

          cmd - 1 : yabai -m space --focus 1
          cmd - 2 : yabai -m space --focus 2
          cmd - 3 : yabai -m space --focus 3
          cmd - 4 : yabai -m space --focus 4
          cmd - 5 : yabai -m space --focus 5
          cmd - 6 : yabai -m space --focus 6
          cmd - 7 : yabai -m space --focus 7
          cmd - 8 : yabai -m space --focus 8
          cmd - 9 : yabai -m space --focus 9

          cmd + shift - 1 : yabai -m window --space 1 && yabai -m space --focus 1
          cmd + shift - 2 : yabai -m window --space 2 && yabai -m space --focus 2
          cmd + shift - 3 : yabai -m window --space 3 && yabai -m space --focus 3
          cmd + shift - 4 : yabai -m window --space 4 && yabai -m space --focus 4
          cmd + shift - 5 : yabai -m window --space 5 && yabai -m space --focus 5
          cmd + shift - 6 : yabai -m window --space 6 && yabai -m space --focus 6
          cmd + shift - 7 : yabai -m window --space 7 && yabai -m space --focus 7
          cmd + shift - 8 : yabai -m window --space 8 && yabai -m space --focus 8
          cmd + shift - 9 : yabai -m window --space 9 && yabai -m space --focus 9
        '';
      };
    };
  };
}
