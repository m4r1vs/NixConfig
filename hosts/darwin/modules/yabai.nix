{
  lib,
  config,
  pkgs,
  systemArgs,
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
          top_padding = 4;
          bottom_padding = 6;
          left_padding = 6;
          right_padding = 6;
          window_gap = 6;
          window_animation_duration = 0.15;
        };
        extraConfig =
          # bash
          ''
            yabai -m rule --add app="^Riot Client$" manage=off
            yabai -m rule --add app="^System Settings$" manage=off
            yabai -m rule --add app="^League of Legends$" manage=off
            yabai -m rule --add app="^Raycast$" manage=off

            yabai -m space 1 --label one
            yabai -m space 2 --label two
            yabai -m space 3 --label three
            yabai -m space 4 --label four
            yabai -m space 5 --label five
            yabai -m space 6 --label six
            yabai -m space 7 --label six
            yabai -m space 8 --label six
            yabai -m space 9 --label nine

            TARGET_SPACES=9
            CURRENT_SPACES=$(yabai -m query --spaces | jq 'length')
            if [ "$CURRENT_SPACES" -lt "$TARGET_SPACES" ]; then
              SPACES_TO_CREATE=$((TARGET_SPACES - CURRENT_SPACES))
              for ((i=0; i<SPACES_TO_CREATE; i++)); do
                yabai -m space --create
              done
            fi

            while true; do
              yabai -m config focus_follows_mouse autoraise
              sleep 20
            done
          '';
        enableScriptingAddition = true;
      };
      skhd = {
        package = pkgs.skhd;
        enable = true;
        skhdConfig = ''
          cmd - return : ${pkgs.ghostty}/bin/ghostty

          cmd - q : yabai -m window --close
          cmd + shift - q : kill $(osascript -e 'tell application "System Events" to get unix id of first application process whose frontmost is true')

          cmd - 0x2C : osascript -e 'set volume output volume ((output volume of (get volume settings)) - 5)'
          cmd - 0x1E : osascript -e 'set volume output volume ((output volume of (get volume settings)) + 5)'

          cmd + shift - 0x2C : skhd -k "f14" # brightness down
          cmd + shift - 0x1E : skhd -k "f15" # brightness up

          rcmd - a : skhd -k "left"
          rcmd - w : skhd -k "up"
          rcmd - s : skhd -k "down"
          rcmd - d : skhd -k "right"

          rcmd - h : skhd -k "left"
          rcmd - k : skhd -k "up"
          rcmd - j : skhd -k "down"
          rcmd - l : skhd -k "right"

          f1 : skhd -k "f14" # brightness down
          f2 : skhd -k "f15" # brightness up

          f10 : osascript -e 'set volume output muted not (output muted of (get volume settings))'
          f11 : osascript -e 'set volume output volume ((output volume of (get volume settings)) - 5)'
          f12 : osascript -e 'set volume output volume ((output volume of (get volume settings)) + 5)'

          cmd - f1 : ${pkgs.ghostty}/bin/ghostty -e zsh -c "export TERM=xterm-256color; ssh -J 2niveri@rzssh1.informatik.uni-hamburg.de 2niveri@sppc13.informatik.uni-hamburg.de"

          cmd - f6 : open -a ScreenSaverEngine

          ctrl + cmd - h : skhd -k "ctrl + cmd - left"
          ctrl + cmd - l : skhd -k "ctrl + cmd - right"

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
          cmd + ctrl - f: yabai -m window --toggle native-fullscreen

          cmd + lshift - n: yabai -m space --move next

          f8: ${pkgs.scratchpad-rs}/bin/scratchpad --toggle spotify
          cmd - e: ${pkgs.scratchpad-rs}/bin/scratchpad --toggle yazi

          cmd - f8 : random-album-of-the-day

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

          cmd + ctrl - 1 : yabai -m space --focus 10
          cmd + ctrl - 2 : yabai -m space --focus 11
          cmd + ctrl - 3 : yabai -m space --focus 12
          cmd + ctrl - 4 : yabai -m space --focus 13
          cmd + ctrl - 5 : yabai -m space --focus 14
          cmd + ctrl - 6 : yabai -m space --focus 15
          cmd + ctrl - 7 : yabai -m space --focus 16
          cmd + ctrl - 8 : yabai -m space --focus 17
          cmd + ctrl - 9 : yabai -m space --focus 18

          cmd + ctrl + shift - 1 : yabai -m window --space 10 && yabai -m space --focus 10
          cmd + ctrl + shift - 2 : yabai -m window --space 12 && yabai -m space --focus 11
          cmd + ctrl + shift - 3 : yabai -m window --space 13 && yabai -m space --focus 12
          cmd + ctrl + shift - 4 : yabai -m window --space 14 && yabai -m space --focus 13
          cmd + ctrl + shift - 5 : yabai -m window --space 15 && yabai -m space --focus 14
          cmd + ctrl + shift - 6 : yabai -m window --space 16 && yabai -m space --focus 15
          cmd + ctrl + shift - 7 : yabai -m window --space 17 && yabai -m space --focus 16
          cmd + ctrl + shift - 8 : yabai -m window --space 18 && yabai -m space --focus 17
          cmd + ctrl + shift - 9 : yabai -m window --space 19 && yabai -m space --focus 18
        '';
      };
    };

    home-manager.users.${systemArgs.username}.home.file.".config/scratchpad/config.toml".text =
      # toml
      ''
        scratchpad_space = 9
        launch_timeout = 5

        [[scratchpad]]
        name = "spotify"
        target_type = "title"
        target = "spotify_scratchpad"
        position = [288, 128]
        size = [1240, 754]
        launch_type = "app_with_arg"
        launch_command = ["/Users/${systemArgs.username}/Applications/Home Manager Apps/Ghostty.app", "--title=spotify_scratchpad", "-e", "zsh", "-c", "${pkgs.spotify-player}/bin/spotify_player"]

        [[scratchpad]]
        name = "yazi"
        target_type = "title"
        target = "yazi_scratchpad"
        position = [288, 128]
        size = [1240, 754]
        launch_type = "app_with_arg"
        launch_command = ["/Users/${systemArgs.username}/Applications/Home Manager Apps/Ghostty.app", "--title=yazi_scratchpad", "-e", "zsh", "-c", "${pkgs.yazi}/bin/yazi"]
      '';
  };
}
