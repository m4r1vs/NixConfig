{
  lib,
  config,
  scripts,
  pkgs,
  osConfig,
  ...
}:
with lib; let
  cfg = config.programs.configured.hyprland;
in {
  options.programs.configured.hyprland = {
    enable = mkEnableOption "Tiling Wayland Window Manager";
  };
  config = mkIf cfg.enable {
    home.activation.copyWallpapers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p $HOME/Pictures/Wallpapers
      $DRY_RUN_CMD cp -rn ${../wallpaper}/* $HOME/Pictures/Wallpapers/ 2>/dev/null || true
      $DRY_RUN_CMD chmod u+w -R $HOME/Pictures/Wallpapers 2>/dev/null || true
      $DRY_RUN_CMD [ ! -L "$HOME/.active_wallpaper.jpg" ] && ln -s ${../wallpaper/Birch_Trunks.jpg} $HOME/.active_wallpaper.jpg
    '';
    services.configured = {
      cliphist.enable = true;
      hypridle.enable = true;
      swaync.enable = true;
    };
    wayland.windowManager.hyprland = {
      enable = true;
      plugins = with pkgs; [
        hyprlandPlugins.hypr-dynamic-cursors
      ];
      settings = {
        exec-once = [
          "${lib.getExe pkgs.hyprlock} || hyprctl dispatch exit"
          "${pkgs.waybar}/bin/waybar"
          "${pkgs._1password-gui}/bin/1password --silent"
          "${scripts.hyprland-startup-workspaces}"
          "${scripts.volume-change-notify}"
          "${scripts.brightness-change-notify}"
        ];
        cursor = {
          inactive_timeout = 3;
          use_cpu_buffer = 1;
        };
        env =
          [
            "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
          ]
          ++ lib.optionals osConfig.configured.nvidia.enable [
            "LIBVA_DRIVER_NAME,nvidia"
            "GBM_BACKEND,nvidia-drm"
            "__GLX_VENDOR_LIBRARY_NAME,nvidia"
            "__NV_PRIME_RENDER_OFFLOAD,1"
            "__GL_GSYNC_ALLOWED,1"
            "__GL_VRR_ALLOWED,1"
            "WLR_DRM_NO_ATOMIC,1"
            "__VK_LAYER_NV_optimus,NVIDIA_only"
            "NVD_BACKEND,direct"
          ];
        input = {
          kb_layout = "us,de";
          kb_options = "caps:escape";
          touchpad = {
            natural_scroll = true;
          };
          follow_mouse = 1;
          sensitivity = 0.6;
          force_no_accel = false;
          accel_profile = "flat";
          numlock_by_default = true;
        };
        misc = {
          vrr = 2;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = 0;
        };
        layerrule = [
          "unset,waybar"
          "blur,rofi"
          "dimaround,swaync-control-center"
          "noanim,hyprpicker"
        ];
        gesture = [
          "3, horizontal, workspace"
          "4, horizontal, move"
          "4, down, close"
          "3, up, fullscreen"
        ];
        opengl = {
          nvidia_anti_flicker = false;
        };
        general = {
          border_size = 0;
          gaps_in = 4;
          gaps_out = 8;
          allow_tearing = true;
          layout = "dwindle";
        };
        ecosystem = {
          no_update_news = true;
        };
        plugin = {
          dynamic-cursors = {
            enabled = true;
            threshold = 1;
            mode = "tilt";
            shake = {
              enabled = false;
            };
          };
        };
        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };
        decoration = {
          rounding = 6;
          rounding_power = 4;
          dim_inactive = true;
          dim_strength = 0.12;
          inactive_opacity = 0.94;
          dim_special = 0.2;
          dim_around = 0.2;
          shadow = {
            enabled = true;
            range = 24;
            scale = 0.99;
            offset = "0 3";
            render_power = 3;
            color = "0x90000000";
            color_inactive = "0x62000000";
          };
          blur = {
            special = true;
            enabled = true;
            size = 2;
            vibrancy = 0.25;
            passes = 3;
            new_optimizations = true;
            ignore_opacity = true;
            xray = false;
          };
        };
        animations = {
          enabled = true;
          bezier = [
            "smooth, 0.05, 0.9, 0.1, 1"
          ];
          animation = [
            "windows, 1, 2, smooth, popin 75%"
            "windowsIn, 1, 2, smooth, popin 75%"
            "windowsOut, 1, 2, smooth, popin 75%"
            "windowsMove, 1, 2, smooth, slide"
            "layers, 1, 3.3, smooth, fade"
            "fade, 1, 3.3, smooth"
            "workspaces, 1, 2, smooth, slide"
            "specialWorkspace, 1, 2.5, smooth, slidefadevert 6%"
          ];
        };
        windowrulev2 = [
          "noblur,class:^()$,title:^()$"

          "workspace 1, initialClass:^(brave-browser)$"
          "workspace 2, initialClass:^(ghostty.startup_workspace_2)$"
          "workspace 3, initialTitle:^(.*)( - Obsidian)(.*)$"
          "workspace 9, initialClass:^(signal)$"
          "workspace 9, initialTitle:^(WhatsApp Electron)(.*)$"

          "float,initialClass:^(ghostty.yazi)$"
          "size 1400 700, initialClass:^(ghostty.yazi)$"

          "float,initialClass:^(ghostty.fastfetch)$"
          "size 1000 600, initialClass:^(ghostty.fastfetch)$"

          "float,initialClass:^(ghostty.weather)$"
          "size 1200 800, initialClass:^(ghostty.weather)$"

          "float,initialClass:^(ghostty.asciiquarium)$"
          "size 1200 800, initialClass:^(ghostty.asciiquarium)$"

          "float,initialClass:^(ghostty.astroterm)$"
          "size 1200 800, initialClass:^(ghostty.astroterm)$"

          "float,initialClass:^(ghostty.spotify_player)$"
          "size 1600 900, initialClass:^(ghostty.spotify_player)$"
          "workspace special:spotify_player silent,initialClass:^(ghostty.spotify_player)$"

          "float,initialClass:^(ghostty.obsidian)$"
          "size 1600 900, initialClass:^(ghostty.obsidian)$"
          "workspace special:obsidian_nvim silent,initialClass:^(ghostty.obsidian)$"
        ];
        monitor = [
          "eDP-1,1920x1080@60.01,0x0, 1" # Internal
          "Virtual-1,3024x1890@60.00,0x0, 1.5" # Internal
          # "DP-1,3440x1440@99.98,-760x-1440, 1" # Ultrawide WQHD
          # "DP-1,2560x1440@144,-320x-1440, 1" # 16:9 WQHD
          # "HDMI-A-1, 2560x1440@99.95,-320x-1440, 1" # 16:9 WQHD
          ", highres, auto-up, 1" # Everything Else Auto
        ];
        binds.movefocus_cycles_fullscreen = false;
        bindd =
          [
            "SUPER, q, Kill active window, killactive"

            "SUPER, Tab, Cycle next window, exec, ${scripts.cycle-windows "next"}"
            "SUPER+Shift, Tab, Cycle previous window, exec, ${scripts.cycle-windows "prev"}"

            "SUPER, h, Move focus left, movefocus, l"
            "SUPER, l, Move focus right, movefocus, r"
            "SUPER, k, Move focus up, movefocus, u"
            "SUPER, j, Move focus down, movefocus, d"

            "SUPER, h, Bring active to top left, bringactivetotop, l"
            "SUPER, l, Bring active to top right, bringactivetotop, r"
            "SUPER, k, Bring active to top up, bringactivetotop, u"
            "SUPER, j, Bring active to top down, bringactivetotop, d"

            "SUPER, t, Toggle split vertical/horizontal, togglesplit"
            "SUPER+Shift, N, Move current workspace to next monitor, movecurrentworkspacetomonitor, +1"

            "SUPER, F, Toggle fullscreen, fullscreen,"
            "SUPER+Shift, F, Toggle fake fullscreen, fullscreenstate, 2,"
            "SUPER+Shift, Space, Toggle active window floating, togglefloating"

            "SUPER, Return, Open Ghostty Terminal Emulator, exec, ${lib.getExe pkgs.ghostty}"
            "SUPER+Shift, Return, SSH Session Selection, exec, ${scripts.rofi-launch} ssh"
            "SUPER, d, Rofi search, exec, ${scripts.rofi-launch} search"
            "SUPER, s, Simple Screenshot, exec, ${scripts.screenshot}"
            "SUPER, E, Open file manager, exec, ${lib.getExe pkgs.ghostty} --class=ghostty.yazi -e ${pkgs.yazi}/bin/yazi ~/Downloads/"
            "SUPER, m, Emoji Picker, exec, ${scripts.rofi-launch} emoji"
            "SUPER, SPACE, Switch keyboard layout, exec, ${scripts.switch-kb-layout}"
            "SUPER, c, Query Wolfram|Alpha with ChatGPT fallback, exec, ${scripts.rofi-launch} calc"

            ",F8, Toggle Spotify Workspace, togglespecialworkspace, spotify_player"
            ",F8, Launch Spotify if not running, exec, pgrep spotify_player || ${lib.getExe pkgs.ghostty} --class=ghostty.spotify_player -e ${pkgs.spotify-player}/bin/spotify_player"

            "SUPER, F8, Like current track on Spotify, exec, ${scripts.spotify-like}"
            "Shift, F8, Play a random album of the day, exec, ${scripts.random-album-of-the-day}"

            ",F7, Wireless virtual Screen, exec, ${scripts.wireless-screen}"

            ",F11, Toggle Obsidian Neovim Workspace, togglespecialworkspace, obsidian_nvim"
            ",F11, Launch Obsidian if not launched, exec, ${scripts.launch-once {
              command = "${pkgs.obsidian}/bin/obsidian";
              grep = "initialTitle:.*Obsidian.*";
              useHypr = true;
            }}"
            ",F11, Launch Neovim in Obsidian Vault, exec, ${scripts.launch-once {
              command = "${lib.getExe pkgs.ghostty} --class=ghostty.obsidian -e ${config.programs.neovim.finalPackage}/bin/nvim \"~/Documents/Marius\\\'\\\ Remote\\\ Vault\"";
              grep = "ghostty\\\.obsidian";
              useHypr = true;
            }}"
            "Shift, F11, Launch Obsidian if not launched, exec, ${scripts.launch-once {
              command = "${pkgs.obsidian}/bin/obsidian";
              grep = "initialClass: obsidian";
              useHypr = true;
            }}"
            "Shift, F11, Toggle Obsidian Workspace, togglespecialworkspace, obsidian"

            "SUPER+Shift, s, Take Screenshot and then edit it, exec, ${scripts.screenshot} edit"
            "SUPER+Shift, c, Toggle Notification Center, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client -t"
            "SUPER+Shift, d, Toggle Dark Mode, exec, ${pkgs.darkman}/bin/darkman toggle"
            "SUPER+Shift, w, Change Wallpaper, exec, ${scripts.rofi-launch} wallpaper"
            "SUPER+Shift, z, Toggle zen mode, exec, ${scripts.toggle-zen}"
            "SUPER, g, Toggle Hyprland zoomed out mode, exec, ${scripts.toggle-hypr-zoomed-out}"
            "SUPER+Shift, g, Toggle workspace floating, workspaceopt, allfloat"
            "SUPER+Shift, P, Color picker, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a"
            "SUPER+Shift, q, Power Menu, exec, ${scripts.rofi-launch} power"
            "SUPER+Shift, b, Rofi Bluetooth, exec, ${scripts.rofi-launch} bluetooth"
            "SUPER+Shift, i, 1Password quick access, exec, ${pkgs._1password-gui}/bin/1password --quick-access"
            "SUPER+Shift, v, Rofi Clipboard History, exec, ${scripts.rofi-launch} cliphist"
            "SUPER+Shift, o, Obsidian Search, exec, ${scripts.rofi-launch} obsidian"

            # bound to mousewheel left/right
            "Ctrl+Shift, Left, Previous workspace, workspace, m-1"
            "Ctrl+Shift, Right, Next workspace, workspace, m+1"
          ]
          ++ (
            builtins.concatLists (builtins.genList (
                i: let
                  ws = i + 1;
                in [
                  "SUPER, ${toString ws}, Switch to workspace ${toString ws}, workspace, ${toString ws}"
                  "SUPER+Shift, ${toString ws}, Move to workspace ${toString ws}, movetoworkspace, ${toString ws}"
                  "SUPER+CTRL, ${toString ws}, Move to workspace ${toString ws} silently, movetoworkspacesilent, ${toString ws}"
                ]
              )
              9)
          );
        binddle = [
          # Allow on lockscreen (l flag) and allow repeat (e flag)
          "SUPER, bracketright, Increase volume, exec, ${pkgs.pamixer}/bin/pamixer -i 5"
          "SUPER, slash, Decrease volume, exec, ${pkgs.pamixer}/bin/pamixer -d 5"
          "SUPER, p, Toggle media playback (play/pause), exec, ${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle"
          "SUPER, backslash, Mute audio, exec, ${pkgs.pamixer}/bin/pamixer -t"
          "SUPER+Shift, bracketright, Increase brightness, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%+"
          "SUPER+Shift, slash, Decrease brightness, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%-"
        ];
        binddm = [
          # Bind Mouse (m flag)
          "SUPER, mouse:272, Move window, movewindow"
          "SUPER, mouse:273, Resize window, resizewindow"
          "SUPER, X, Resize window, resizewindow"
          "SUPER, Y, Move window, movewindow"
          "SUPER, Z, Move window, movewindow"
        ];
        bindde = [
          # Allow repeat (e flag)
          "SUPER+Shift, h, Move window left, exec, $moveactivewindow -30 0 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow l"
          "SUPER+Shift, l, Move window right, exec, $moveactivewindow 30 0 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow r"
          "SUPER+Shift, k, Move window up, exec, $moveactivewindow  0 -30 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow u"
          "SUPER+Shift, j, Move window down, exec, $moveactivewindow 0 30 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow d"

          "SUPER+alt, l, Resize window right, resizeactive, 30 0"
          "SUPER+alt, h, Resize window left, resizeactive, -30 0"
          "SUPER+alt, k, Resize window up, resizeactive, 0 -30"
          "SUPER+alt, j, Resize window down, resizeactive, 0 30"
        ];
        "$moveactivewindow" = "grep -q \"true\" <<< $(${pkgs.hyprland}/bin/hyprctl activewindow -j | jq -r .floating) && ${pkgs.hyprland}/bin/hyprctl dispatch moveactive";
      };
    };
  };
}
