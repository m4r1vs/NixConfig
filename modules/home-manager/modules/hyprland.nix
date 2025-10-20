{
  lib,
  config,
  scripts,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.hyprland;
in {
  options.programs.configured.hyprland = {
    enable = mkEnableOption "Tiling Wayland Window Manager";
  };
  config = mkIf cfg.enable {
    services.configured = {
      cliphist.enable = true;
      hypridle.enable = true;
      swaync.enable = true;
    };
    wayland.windowManager.hyprland = {
      enable = true;
      plugins = with pkgs; [
        hyprlandPlugins.hypr-dynamic-cursors
        hyprlandPlugins.hyprfocus
      ];
      settings = {
        exec-once = [
          "${pkgs.waybar}/bin/waybar"
          "${pkgs._1password-gui}/bin/1password --silent --ozone-platform-hint=x11"
          "${scripts.volume-change-notify}"
          "${scripts.brightness-change-notify}"
        ];
        cursor = {
          inactive_timeout = 3;
          use_cpu_buffer = 1;
        };
        # exec = "${pkgs.hyprland}/bin/hyprctl setcursor Bibata-Modern-Ice 20";
        env = [
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
        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
          workspace_swipe_forever = true;
          workspace_swipe_direction_lock = false;
        };
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
          hyprfocus = {
            enabled = true;
            animate_floating = true;
            animate_workspacechange = true;
            focus_animation = "flash";
            bezier = "realsmooth, 0.28,0.29,0.69,1.08";
            flash = {
              flash_opacity = 0.96;
              in_bezier = "realsmooth";
              in_speed = 0.3;
              out_bezier = "realsmooth";
              out_speed = 0.6;
            };
          };
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
          rounding = 5;
          rounding_power = 3;
          dim_inactive = true;
          dim_strength = 0.10;
          inactive_opacity = 0.96;
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
            size = 5;
            vibrancy = 0.35;
            passes = 4;
            new_optimizations = true;
            ignore_opacity = true;
            xray = false;
          };
        };
        animations = {
          enabled = true;
          first_launch_animation = false;
          bezier = [
            "smooth, 0.05, 0.9, 0.1, 1"
          ];
          animation = [
            "windows, 1, 1.5, smooth, popin 75%"
            "windowsIn, 1, 1.5, smooth, popin 75%"
            "windowsOut, 1, 1.5, smooth, popin 75%"
            "windowsMove, 1, 1.5, smooth, slide"
            "layers, 1, 3.3, smooth, fade"
            "fade, 1, 3.3, smooth"
            "workspaces, 1, 1.5, smooth, slide"
            "specialWorkspace, 1, 2, smooth, slidefadevert 6%"
          ];
        };
        windowrulev2 = [
          "noblur,class:^()$,title:^()$"

          "float,initialClass:^(ghostty.yazi)$"
          "size 1400 700, initialClass:^(ghostty.yazi)$"

          "float,initialClass:^(ghostty.spotify_player)$"
          "size 1600 900, initialClass:^(ghostty.spotify_player)$"
          "workspace special:spotify_player silent,initialClass:^(ghostty.spotify_player)$"

          "float,initialClass:^(ghostty.obsidian)$"
          "size 1600 900, initialClass:^(ghostty.obsidian)$"
          "workspace special:obsidian_nvim silent,initialClass:^(ghostty.obsidian)$"

          "float,initialClass:^(obsidian)$"
          "size 1600 900, initialClass:^(obsidian)$"
          "workspace special:obsidian silent,initialClass:^(obsidian)$"
        ];
        monitor = [
          "eDP-1,1920x1080@60.01,0x0, 1" # Internal
          ", highres, auto-up, 1"
          # "DP-1,3440x1440@99.98,-760x-1440, 1" # Ultrawide WQHD
          # "DP-1,2560x1440@144,-320x-1440, 1" # 16:9 WQHD
          "HDMI-A-1, 2560x1440@99.95,-320x-1440, 1" # 16:9 WQHD
        ];
        binds.movefocus_cycles_fullscreen = false;
        bind =
          [
            "SUPER, q, killactive"

            "SUPER, Tab, cyclenext"
            "SUPER, Tab, bringactivetotop"

            "SUPER+Shift, Tab, cyclenext, prev"
            "SUPER+Shift, Tab, bringactivetotop"

            "SUPER, h, movefocus, l"
            "SUPER, l, movefocus, r"
            "SUPER, k, movefocus, u"
            "SUPER, j, movefocus, d"

            "SUPER, h, bringactivetotop, l"
            "SUPER, l, bringactivetotop, r"
            "SUPER, k, bringactivetotop, u"
            "SUPER, j, bringactivetotop, d"

            "SUPER, t, togglesplit"
            "SUPER+Shift, N, movecurrentworkspacetomonitor, +1"

            "SUPER, F, fullscreen,"
            "SUPER+Shift, F, fullscreenstate, 2,"
            "SUPER+Shift, Space, togglefloating"

            "SUPER, Return, exec, ${pkgs.ghostty}/bin/ghostty"
            "SUPER+Shift, Return, exec, ${pkgs.writeShellScript "rofi-ssh" ''
              ${pkgs.rofi}/bin/rofi -show ssh -theme-str "entry{placeholder:\"SSH into a Remote...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 38% 42%;}"
            ''}"
            "SUPER, d, exec, ${pkgs.rofi}/bin/rofi -theme-str \"entry {placeholder: \\\"Launch a Program...\\\";}entry{padding: 10 10 0 12;}\" -combi-modi search:${scripts.rofi-search},drun -show combi"
            "SUPER, s, exec, ${scripts.screenshot}"
            "SUPER, E, exec, ${pkgs.ghostty}/bin/ghostty --class=ghostty.yazi -e EDITOR=nvim ${pkgs.yazi}/bin/yazi ~/Downloads/"
            "SUPER, m, exec, ${pkgs.rofimoji}/bin/rofimoji --selector-args=\"-theme-str \\\"listview{dynamic:true;columns:12;layout:vertical;flow:horizontal;reverse:false;lines:10;}element-text{enabled:false;}element-icon{size:32px;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 24;}\\\"\" --use-icons --typer wtype --clipboarder wl-copy --skin-tone neutral --selector rofi --max-recent 0 --action clipboard"
            "SUPER, SPACE, exec, ${scripts.switch-kb-layout}"
            "SUPER, c, exec, ${pkgs.rofi}/bin/rofi -modi calculator:${scripts.rofi-calculator} -show calculator -theme-str \"entry {placeholder:\\\"Ask a Question...\\\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}\""
            "SUPER, p, exec, ${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle"

            "SUPER, backslash, exec, ${pkgs.pamixer}/bin/pamixer -t"

            ",F1, togglespecialworkspace, spotify_player"
            ",F1, exec, pgrep spotify_player || ${pkgs.ghostty}/bin/ghostty --class=ghostty.spotify_player -e ${pkgs.spotify-player}/bin/spotify_player"

            ",F7, exec, ${scripts.wireless-screen}"

            ",F11, togglespecialworkspace, obsidian_nvim"
            ",F11, exec, ${scripts.launch-once {
              command = "${pkgs.obsidian}/bin/obsidian";
              grep = "initialClass: obsidian";
              useHypr = true;
            }}"
            ",F11, exec, ${scripts.launch-once {
              command = "${pkgs.ghostty}/bin/ghostty --class=ghostty.obsidian -e ${config.programs.neovim.finalPackage}/bin/nvim \"~/Documents/Marius\\\'\\\ Remote\\\ Vault\"";
              grep = "ghostty\\\.obsidian";
              useHypr = true;
            }}"
            "Shift, F11, exec, ${scripts.launch-once {
              command = "${pkgs.obsidian}/bin/obsidian";
              grep = "initialClass: obsidian";
              useHypr = true;
            }}"
            "Shift, F11, togglespecialworkspace, obsidian"

            ",F12, exec, ${pkgs.spotify-player}/bin/spotify_player like && ${scripts.nixos-notify} -e -t 1800 \"Liked currentry playing Track on Spotify\""
            "Shift, F12, exec, ${scripts.random-album-of-the-day}"

            "SUPER+Shift, s, exec, ${scripts.screenshot} edit"
            "SUPER+Shift, c, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client -t"
            "SUPER+Shift, d, exec, ${pkgs.darkman}/bin/darkman toggle"
            "SUPER+Shift, w, exec, ${scripts.random-wallpaper ../wallpaper}"
            "SUPER+Shift, z, exec, ${scripts.toggle-zen}"
            "SUPER+Shift, P, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a"
            "SUPER+Shift, q, exec,  ${pkgs.rofi}/bin/rofi -show power-menu -modi power-menu:${scripts.rofi-power-menu} -theme-str \"entry {placeholder:\\\"Power Menu...\\\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 38% 44%;}\""
            "SUPER+Shift, b, exec,  ${scripts.rofi-bluetooth}"
            "SUPER+Shift, i, exec, ${pkgs._1password-gui}/bin/1password --quick-access --ozone-platform-hint=x11"
            "SUPER+Shift, v, exec, ${scripts.rofi-cliphist}"

            # bound to mousewheel left/right
            "SUPER+Ctrl, Left, workspace, m-1"
            "SUPER+Ctrl, Right, workspace, m+1"
          ]
          ++ (
            builtins.concatLists (builtins.genList (
                i: let
                  ws = i + 1;
                in [
                  "SUPER, code:1${toString i}, workspace, ${toString ws}"
                  "SUPER+Shift, code:1${toString i}, movetoworkspace, ${toString ws}"
                ]
              )
              9)
          );
        bindle = [
          "SUPER, bracketright, exec, ${pkgs.pamixer}/bin/pamixer -i 5"
          "SUPER, slash, exec, ${pkgs.pamixer}/bin/pamixer -d 5"
        ];
        bindm = [
          "SUPER, mouse:272, movewindow"
          "SUPER, mouse:273, resizewindow"
          "SUPER, X, resizewindow"
          "SUPER, Y, movewindow"
          "SUPER, Z, movewindow"
        ];
        "$moveactivewindow" = "grep -q \"true\" <<< $(${pkgs.hyprland}/bin/hyprctl activewindow -j | jq -r .floating) && ${pkgs.hyprland}/bin/hyprctl dispatch moveactive";
        binde = [
          "SUPER+Shift, bracketright, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%+"
          "SUPER+Shift, slash, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%-"

          "SUPER+Shift, h,exec, $moveactivewindow -30 0 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow l"
          "SUPER+Shift, l,exec, $moveactivewindow 30 0 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow r"
          "SUPER+Shift, k,exec, $moveactivewindow  0 -30 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow u"
          "SUPER+Shift, j,exec, $moveactivewindow 0 30 || ${pkgs.hyprland}/bin/hyprctl dispatch movewindow d"

          "SUPER+alt, l, resizeactive, 30 0"
          "SUPER+alt, h, resizeactive, -30 0"
          "SUPER+alt, k, resizeactive, 0 -30"
          "SUPER+alt, j, resizeactive, 0 30"
        ];
      };
    };
  };
}
