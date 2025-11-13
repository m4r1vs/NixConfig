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
          top_padding = 4;
          bottom_padding = 6;
          left_padding = 6;
          right_padding = 6;
          window_gap = 6;
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
              sleep 60
            done
          '';
        enableScriptingAddition = true;
      };
    };

    environment.systemPackages = [pkgs.skhd-zig];
    home-manager.users.${systemArgs.username}.home.file = {
      ".config/skhd/skhdrc".text = ''
        .blacklist [
          "vmware fusion"
        ]

        lcmd - q : yabai -m window --close
        lcmd + shift - q : kill $(osascript -e 'tell application "System Events" to get unix id of first application process whose frontmost is true')

        lcmd - 0x2C : osascript -e 'set volume output volume ((output volume of (get volume settings)) - 5)'
        lcmd - 0x1E : osascript -e 'set volume output volume ((output volume of (get volume settings)) + 5)'

        lcmd + shift - 0x2C : skhd -k "f14" # brightness down
        lcmd + shift - 0x1E : skhd -k "f15" # brightness up

        fn - h : skhd -k "left"
        fn - k : skhd -k "up"
        fn - j : skhd -k "down"
        fn - l : skhd -k "right"

        f1 : skhd -k "f14" # brightness down
        f2 : skhd -k "f15" # brightness up

        f10 : osascript -e 'set volume output muted not (output muted of (get volume settings))'
        f11 : osascript -e 'set volume output volume ((output volume of (get volume settings)) - 5)'
        f12 : osascript -e 'set volume output volume ((output volume of (get volume settings)) + 5)'

        lcmd - f1 : ${pkgs.ghostty}/bin/ghostty -e zsh -c "export TERM=xterm-256color; ssh -J 2niveri@rzssh1.informatik.uni-hamburg.de 2niveri@sppc13.informatik.uni-hamburg.de"
        lcmd - f2 : ${pkgs.ghostty}/bin/ghostty -e ssh mn@nixner.niveri.dev
        lcmd - f3 : ${pkgs.ghostty}/bin/ghostty -e ssh -p 422 mn@falkenberg.kubenix.niveri.dev
        lcmd - f4 : ${pkgs.ghostty}/bin/ghostty -e ssh -p 422 mn@stadeln.kubenix.niveri.dev
        lcmd - f5 : ${pkgs.ghostty}/bin/ghostty -e ssh -p 422 mn@ronhof.kubenix.niveri.dev

        lcmd - f6 : open -a ScreenSaverEngine

        lcmd - h: yabai -m window --focus west || yabai -m display --focus west
        lcmd - j: yabai -m window --focus south || yabai -m display --focus south
        lcmd - k: yabai -m window --focus north || yabai -m display --focus north
        lcmd - l: yabai -m window --focus east || yabai -m display --focus east

        lcmd + ctrl - h : yabai -m window --resize left:-20:0 || yabai -m window --resize right:-20:0
        lcmd + ctrl - j : yabai -m window --resize bottom:0:20 || yabai -m window --resize top:0:20
        lcmd + ctrl - k : yabai -m window --resize top:0:-20 || yabai -m window --resize bottom:0:-20
        lcmd + ctrl - l : yabai -m window --resize right:20:0 || yabai -m window --resize left:20:0

        lcmd + shift - h : yabai -m window --warp west \
          || yabai -m window --display west && yabai -m display --focus west

        lcmd + shift - j : yabai -m window --warp south \
          || yabai -m window --display south && yabai -m display --focus south

        lcmd + shift - k : yabai -m window --warp north \
          || yabai -m window --display north && yabai -m display --focus north

        lcmd + shift - l : yabai -m window --warp east \
          || yabai -m window --display east && yabai -m display --focus east

        lcmd + lshift - space: yabai -m window --toggle float

        lcmd + lshift - f: yabai -m window --toggle zoom-fullscreen
        lcmd + ctrl - f: yabai -m window --toggle native-fullscreen

        lcmd + lshift - n: yabai -m space --move next

        f8: ${pkgs.scratchpad-rs}/bin/scratchpad --toggle spotify
        lcmd - e: ${pkgs.scratchpad-rs}/bin/scratchpad --toggle yazi

        lcmd - f8 : random-album-of-the-day

        lcmd - 1 : yabai -m space --focus 1
        lcmd - 2 : yabai -m space --focus 2
        lcmd - 3 : yabai -m space --focus 3
        lcmd - 4 : yabai -m space --focus 4
        lcmd - 5 : yabai -m space --focus 5
        lcmd - 6 : yabai -m space --focus 6
        lcmd - 7 : yabai -m space --focus 7
        lcmd - 8 : yabai -m space --focus 8
        lcmd - 9 : yabai -m space --focus 9

        lcmd + shift - 1 : yabai -m window --space 1 && yabai -m space --focus 1
        lcmd + shift - 2 : yabai -m window --space 2 && yabai -m space --focus 2
        lcmd + shift - 3 : yabai -m window --space 3 && yabai -m space --focus 3
        lcmd + shift - 4 : yabai -m window --space 4 && yabai -m space --focus 4
        lcmd + shift - 5 : yabai -m window --space 5 && yabai -m space --focus 5
        lcmd + shift - 6 : yabai -m window --space 6 && yabai -m space --focus 6
        lcmd + shift - 7 : yabai -m window --space 7 && yabai -m space --focus 7
        lcmd + shift - 8 : yabai -m window --space 8 && yabai -m space --focus 8
        lcmd + shift - 9 : yabai -m window --space 9 && yabai -m space --focus 9

        lcmd + ctrl - 1 : yabai -m space --focus 10
        lcmd + ctrl - 2 : yabai -m space --focus 11
        lcmd + ctrl - 3 : yabai -m space --focus 12
        lcmd + ctrl - 4 : yabai -m space --focus 13
        lcmd + ctrl - 5 : yabai -m space --focus 14
        lcmd + ctrl - 6 : yabai -m space --focus 15
        lcmd + ctrl - 7 : yabai -m space --focus 16
        lcmd + ctrl - 8 : yabai -m space --focus 17
        lcmd + ctrl - 9 : yabai -m space --focus 18

        lcmd + ctrl + shift - 1 : yabai -m window --space 10 && yabai -m space --focus 10
        lcmd + ctrl + shift - 2 : yabai -m window --space 12 && yabai -m space --focus 11
        lcmd + ctrl + shift - 3 : yabai -m window --space 13 && yabai -m space --focus 12
        lcmd + ctrl + shift - 4 : yabai -m window --space 14 && yabai -m space --focus 13
        lcmd + ctrl + shift - 5 : yabai -m window --space 15 && yabai -m space --focus 14
        lcmd + ctrl + shift - 6 : yabai -m window --space 16 && yabai -m space --focus 15
        lcmd + ctrl + shift - 7 : yabai -m window --space 17 && yabai -m space --focus 16
        lcmd + ctrl + shift - 8 : yabai -m window --space 18 && yabai -m space --focus 17
        lcmd + ctrl + shift - 9 : yabai -m window --space 19 && yabai -m space --focus 18
      '';

      ".config/scratchpad/config.toml".text =
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
  };
}
