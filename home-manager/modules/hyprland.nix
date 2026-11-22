{
  host,
  lib,
  config,
  scripts,
  pkgs,
  osConfig,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.hyprland;
  browsers = config.programs.configured.browser.resolved;
  browser = browsers.default;
  sideBrowser = browsers.side;
  geminiClass = "${browser.appClassPrefix}-gemini.google.com__-${browsers.personalProfile}";
  npuDictate = lib.getExe config.programs.npu-dictate.package;
  # pamixer stops at 100% unless it is told to boost
  boost = cfg.maxVolume > 100;
  volumeUp = "${pkgs.pamixer}/bin/pamixer ${optionalString boost "--allow-boost --set-limit ${toString cfg.maxVolume} "}-i 5";
  volumeDown = "${pkgs.pamixer}/bin/pamixer ${optionalString boost "--allow-boost "}-d 5";
  has1Password = osConfig.programs._1password-gui.enable;
  startupCommand =
    if any (app: app.command != null) cfg.startupApps
    then "${scripts.hyprland-startup-workspaces}"
    else lib.getExe pkgs.waybar;
  # Startup apps that a window rule recognises stay on their workspace for good
  pinnedApps = let
    numberedFirst = a: b: isInt a.workspace && (!isInt b.workspace || a.workspace < b.workspace);
  in
    sort numberedFirst (filter (app: app.match != null && app.workspace != null) cfg.startupApps);

  inherit (lib.generators) mkLuaInline;
  toLua = lib.generators.toLua {};
  inherit (systemArgs) theme;
  darkBgHex = lib.removePrefix "#" theme.backgroundColor;
  lightBgHex = lib.removePrefix "#" theme.backgroundColorLight;

  mkBind = keys: description: action: opts: {
    _args = [
      keys
      (mkLuaInline action)
      (opts // {inherit description;})
    ];
  };

  bindd = keys: description: action: mkBind keys description action {};
  bindde = keys: description: action: mkBind keys description action {repeating = true;};
  binddle = keys: description: action:
    mkBind keys description action {
      locked = true;
      repeating = true;
    };
  binddrint = keys: description: action:
    mkBind keys description action {
      release = true;
      ignore_mods = true;
      non_consuming = true;
      transparent = true;
    };
  exec = cmd: "hl.dsp.exec_cmd(${toLua cmd})";
  moveOrTile = dir: x: y: ''
    function()
      local w = hl.get_active_window()
      if w ~= nil and w.floating then
        hl.dispatch(hl.dsp.window.move({ x = ${toString x}, y = ${toString y}, relative = true }))
      else
        hl.dispatch(hl.dsp.window.move({ direction = ${toLua dir} }))
      end
    end'';
  # fullscreen_state has no "keep current" client mode, so pass the window's current one
  toggleFakeFullscreen = ''
    function()
      local w = hl.get_active_window()
      if w ~= nil then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 2, client = w.fullscreen_client, action = "toggle" }))
      end
    end'';
  toggleWorkspaceFloating = ''
    function()
      local ws = hl.get_active_workspace()
      if ws ~= nil then
        local action = #hl.get_windows({ workspace = ws, floating = false }) > 0 and "enable" or "disable"
        for _, w in ipairs(hl.get_windows({ workspace = ws })) do
          hl.dispatch(hl.dsp.window.float({ window = w, action = action }))
        end
      end
    end'';
in {
  options.programs.configured.hyprland = {
    enable = mkEnableOption "Tiling Wayland Window Manager";
    startupApps = mkOption {
      type = types.listOf (types.submodule {
        options = {
          command = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "What to start at login. Null starts nothing and only keeps matching windows on the workspace.";
          };
          workspace = mkOption {
            type = types.nullOr (types.either types.int types.str);
            default = null;
            example = "name:0";
            description = "The workspace the app opens on: a number, or a name such as name:0 or special:music.";
          };
          match = mkOption {
            type = types.nullOr (types.attrsOf types.str);
            default = null;
            example = {initial_class = "^(signal)$";};
            description = "How to recognise the app's windows (the match of a window rule). With it they always open on the workspace, not only at login.";
          };
        };
      });
      default = [
        {
          command = "${getExe pkgs.signal-desktop} --ozone-platform-hint=auto";
          workspace = 9;
          match.initial_class = "^(signal)$";
        }
        {
          command = "${getExe pkgs.whatsapp-electron} --ozone-platform-hint=auto";
          workspace = 9;
          match.initial_title = "^(WhatsApp Electron)(.*)$";
        }
        {
          # Started on the work machine only, kept on its workspace everywhere
          command =
            if systemArgs.useWorkProfileByDefault
            then getExe pkgs.slack
            else null;
          workspace = 4;
          match.initial_class = "^(slack)$";
        }
        {
          command = "${getExe pkgs.obsidian} --ozone-platform-hint=auto";
          workspace = 3;
          match.initial_class = "^(md.obsidian.Obsidian)$";
        }
        {
          command =
            if meta.availableOn pkgs.stdenv.hostPlatform pkgs.spotify
            then "${getExe pkgs.spotify} --ozone-platform-hint=auto"
            else null;
          workspace = 6;
          match.initial_class = "^(spotify)$";
        }
        {
          command = getExe pkgs.ghostty;
          workspace = 2;
          match.initial_class = "^(ghostty.default)$";
        }
        {
          command = concatStringsSep " " ([browser.exe "--profile-directory=Default"] ++ browser.args);
          workspace = 1;
          match.initial_class = "^(${browser.windowClass})$";
        }
      ];
      description = ''
        The apps that hyprland-startup-workspaces opens at login, in this
        order, after Waybar. A host that sets this replaces the whole list;
        an empty list starts Waybar alone.
      '';
    };
    umlautBinds = mkOption {
      type = types.bool;
      default = true;
      description = "Type German umlauts from a US layout with CTRL or SUPER plus ; ' [ and -. Turn off on a German layout, where they take CTRL+minus away from the apps.";
    };
    maxVolume = mkOption {
      type = types.ints.between 100 150;
      default = 100;
      description = "How far the volume keys and the Waybar scroll wheel may raise the volume, in percent.";
    };
    powerMenuExit = mkEnableOption "a power menu entry that ends the Hyprland session and returns to the login screen";
    hyprtasking = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable macOS Mission Control-style workspace overview via Hyprtasking (3-finger swipe up/down).";
      };
    };
  };
  config = mkIf cfg.enable {
    home.activation.copyWallpapers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p "$HOME/Pictures/Wallpapers"
      run cp -rn ${../wallpaper}/* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
      run chmod u+w -R "$HOME/Pictures/Wallpapers" 2>/dev/null || true
      # Link the copy in ~/Pictures, not the store path, so it survives garbage collection
      if [ ! -L "$HOME/.active_wallpaper.jpg" ]; then
        run ln -s "$HOME/Pictures/Wallpapers/Birch_Trunks.jpg" "$HOME/.active_wallpaper.jpg"
      fi
    '';
    services.configured = {
      cliphist.enable = true;
      hypridle.enable = true;
      hyprsunset.enable = mkDefault true;
      swaync.enable = true;
    };
    /*
    Swallowing (misc.enable_swallow below) only finds a terminal that is a
    parent process of the new window, which it is not inside tmux. These take
    the place of the real programs on PATH and cover the terminal instead
    */
    home.packages = let
      overlaid = class: program:
        hiPrio (pkgs.writeShellScriptBin (baseNameOf program) ''exec ${scripts.terminal-overlay} ${class} ${program} "$@"'');
    in [
      (overlaid "mpv" "${config.programs.mpv.finalPackage}/bin/mpv")
      (overlaid "org.pwmt.zathura" "${pkgs.zathura}/bin/zathura")
    ];
    wayland.windowManager.hyprland = {
      configType = "lua";
      enable = true;
      settings = {
        env = map (pair: {_args = pair;}) (
          [
            ["QT_WAYLAND_DISABLE_WINDOWDECORATION" "1"]
          ]
          ++ lib.optionals osConfig.configured.nvidia.enable [
            ["LIBVA_DRIVER_NAME" "nvidia"]
            ["GBM_BACKEND" "nvidia-drm"]
            ["__GLX_VENDOR_LIBRARY_NAME" "nvidia"]
            ["__NV_PRIME_RENDER_OFFLOAD" "1"]
            ["__GL_GSYNC_ALLOWED" "1"]
            ["__GL_VRR_ALLOWED" "1"]
            ["WLR_DRM_NO_ATOMIC" "1"]
            ["__VK_LAYER_NV_optimus" "NVIDIA_only"]
            ["NVD_BACKEND" "direct"]
          ]
          # AMD graphics; libva finds the Intel driver by itself
          ++ lib.optionals (!osConfig.configured.nvidia.enable && host.isX86 && builtins.elem "kvm-amd" osConfig.boot.kernelModules) [
            ["LIBVA_DRIVER_NAME" "radeonsi"]
          ]
        );
        curve = [
          {
            _args = [
              "smooth"
              {
                type = "bezier";
                points = [
                  [0.05 0.9]
                  [0.1 1]
                ];
              }
            ];
          }
        ];
        animation = [
          {
            leaf = "windows";
            enabled = true;
            speed = 2;
            bezier = "smooth";
            style = "popin 75%";
          }
          {
            leaf = "windowsIn";
            enabled = true;
            speed = 2;
            bezier = "smooth";
            style = "popin 75%";
          }
          {
            leaf = "windowsOut";
            enabled = true;
            speed = 2;
            bezier = "smooth";
            style = "popin 75%";
          }
          {
            leaf = "windowsMove";
            enabled = true;
            speed = 2;
            bezier = "smooth";
            style = "slide";
          }
          {
            leaf = "layers";
            enabled = true;
            speed = 3.3;
            bezier = "smooth";
            style = "fade";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 3.3;
            bezier = "smooth";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 2;
            bezier = "smooth";
            style = "slide";
          }
          {
            leaf = "specialWorkspace";
            enabled = true;
            speed = 2.5;
            bezier = "smooth";
            style = "slidefadevert 6%";
          }
        ];
        config = {
          cursor =
            {
              inactive_timeout = 3;
              use_cpu_buffer =
                if osConfig.configured.nvidia.enable
                then 1
                else 0;
            }
            # Zoomed view moves continuously with the pointer (macOS "Continuously with Pointer")
            // lib.optionalAttrs host.isDev {
              zoom_detached_camera = false;
              zoom_rigid = false;
            };
          input = {
            kb_layout = "us,de";
            kb_options = "caps:escape";
            touchpad = {
              natural_scroll = true;
              scroll_factor = 0.2;
            };
            follow_mouse = 1;
            sensitivity = 0.2;
            force_no_accel = false;
            accel_profile = "adaptive";
            numlock_by_default = true;
          };
          misc = {
            vrr = 1;
            disable_hyprland_logo = true;
            animate_manual_resizes = true;
            enable_swallow = true;
            swallow_regex = "^ghostty\\.(.+)$";
            disable_splash_rendering = true;
            initial_workspace_tracking = 0;
            force_default_wallpaper = 0;
          };
          render = {
            direct_scanout = 2;
            ctm_animation =
              if osConfig.configured.nvidia.enable
              then 0
              else 1;
          };
          xwayland = {
            force_zero_scaling = true;
          };
          opengl = {
            nvidia_anti_flicker = false;
          };
          general = {
            border_size = 0;
            # Used by Hyprtasking workspace tiles (regular windows stay borderless)
            col = {
              active_border = "rgba(ffffffcc)";
              inactive_border = "rgba(ffffff24)";
            };
            gaps_in = 4;
            gaps_out = 8;
            allow_tearing = true;
            layout = "dwindle";
          };
          ecosystem = {
            no_update_news = true;
          };
          dwindle = {
            preserve_split = true;
          };
          decoration = {
            rounding = 6;
            rounding_power = 4;
            dim_inactive = true;
            dim_strength = 0.06;
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
          };
          binds = {
            movefocus_cycles_fullscreen = false;
          };
        };
        layer_rule = [
          {
            match.namespace = "keypress-visualizer";
            order = 1;
            blur = true;
            ignore_alpha = 0.69;
          }
          {
            match.namespace = "hyprpicker"; # Top Layer
            order = 2;
            no_anim = true;
          }
          {
            match.namespace = "swaync-notification-window";
            order = 3;
            blur = true;
            ignore_alpha = 0.65;
            above_lock = 1;
          }
          {
            match.namespace = "rofi";
            order = 4;
            blur = true;
          }
          {
            match.namespace = "waybar";
            order = 5;
          }
          {
            match.namespace = "swaync-control-center"; # Bottom Layer
            order = 6;
            blur = true;
            ignore_alpha = 0.65;
            dim_around = true;
          }
        ];
        gesture = [
          {
            fingers = 5;
            direction = "swipe";
            action = "move";
          }
          {
            fingers = 4;
            direction = "swipe";
            action = "resize";
          }
          {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          }
          {
            fingers = 3;
            direction = "pinch";
            action = "fullscreen";
          }
        ];
        window_rule =
          [
            {
              match = {
                class = "^()$";
                title = "^()$";
              };
              no_blur = true;
            }
          ]
          ++ map (app: {inherit (app) match workspace;}) pinnedApps
          ++ [
            {
              match.initial_class = "^(${geminiClass})$";
              float = true;
              size = "1790 1144";
              center = true;
            }
            {
              match.initial_class = "^(ghostty.yazi)$";
              float = true;
              size = "1400 700";
            }
            {
              match.initial_class = "^(ghostty.fastfetch)$";
              float = true;
              size = "1220 740";
            }
            {
              match.initial_class = "^(ghostty.weather)$";
              float = true;
              size = "1200 800";
            }
            {
              match.initial_class = "^(ghostty.asciiquarium)$";
              float = true;
              size = "1200 800";
            }
            {
              match.initial_class = "^(ghostty.astroterm)$";
              float = true;
              size = "1200 800";
            }
            {
              match.initial_class = "^(ghostty.spotify_player)$";
              float = true;
              size = "1600 1160";
              workspace = "special:spotify_player silent";
            }
            {
              match.initial_class = "^(ghostty.obsidian)$";
              float = true;
              size = "1600 900";
              workspace = "special:obsidian_nvim silent";
            }
          ]
          # hey-computer's long answers (Marker, app id set by its viewer
          # command): a column for reading, over whatever is open
          ++ optionals config.programs.configured.hey-computer.enable [
            {
              match.initial_class = "^(hey-computer\\.answer)$";
              float = true;
              size = "1000 1100";
              center = true;
            }
          ]
          ++ optionals (sideBrowser != null) [
            {
              match.initial_class = "^(${sideBrowser.windowClass})$";
              workspace = "special:${sideBrowser.name} silent";
            }
          ];
        monitor = [
          {
            output = "eDP-1"; # Internal
            mode = "2880x1800@120.00";
            position = "0x0";
            scale = 1.25;
          }
          {
            output = "Virtual-1"; # For Extending Screen wirelessly
            mode = "3024x1890@60.00";
            position = "0x0";
            scale = 1.5;
          }
          {
            output = "desc:Samsung Electric Company LS27D70xE HK2YA02261"; # External Office Meetovo
            mode = "3840x2160@60.00";
            position = "auto-up";
            scale = 1.5;
          }
          {
            output = "desc:LG Electronics 27GL850 912NTVSCD959"; # External LG at home
            mode = "2560x1440@144.00";
            position = "auto-up";
            scale = 1;
          }
          {
            output = ""; # Everything Else Auto
            mode = "highres";
            position = "auto-up";
            scale = 1;
          }
        ];
        on = [
          {
            _args = [
              "hyprland.start"
              (mkLuaInline ''
                function()
                  hl.exec_cmd(${toLua "${scripts.hyprland-session-lock}"})
                  ${optionalString has1Password "hl.exec_cmd(${toLua "${pkgs._1password-gui}/bin/1password --silent"})"}
                  hl.exec_cmd(${toLua startupCommand})
                  hl.exec_cmd(${toLua "${scripts.firmware-update-check}"})
                  hl.exec_cmd(${toLua "${scripts.volume-change-notify}"})
                  hl.exec_cmd(${toLua "${scripts.brightness-change-notify}"})
                  ${optionalString host.hasPowerProfiles "hl.exec_cmd(${toLua "${scripts.powermode} apply"})"}
                  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 20")
                end'')
            ];
          }
        ];
        bind =
          [
            (bindd "SUPER + q" "Kill active window" "hl.dsp.window.close()")

            (bindd "SUPER + Tab" "Cycle next window" (exec "${scripts.cycle-windows "next"}"))
            (bindd "SUPER + SHIFT + Tab" "Cycle previous window" (exec "${scripts.cycle-windows "prev"}"))

            (bindd "SUPER + h" "Move focus left" ''hl.dsp.focus({ direction = "l" })'')
            (bindd "SUPER + l" "Move focus right" ''hl.dsp.focus({ direction = "r" })'')
            (bindd "SUPER + k" "Move focus up" ''hl.dsp.focus({ direction = "u" })'')
            (bindd "SUPER + j" "Move focus down" ''hl.dsp.focus({ direction = "d" })'')

            (bindd "SUPER + h" "Bring active to top left" "hl.dsp.window.bring_to_top()")
            (bindd "SUPER + l" "Bring active to top right" "hl.dsp.window.bring_to_top()")
            (bindd "SUPER + k" "Bring active to top up" "hl.dsp.window.bring_to_top()")
            (bindd "SUPER + j" "Bring active to top down" "hl.dsp.window.bring_to_top()")

            (bindd "SUPER + t" "Toggle split vertical/horizontal" ''hl.dsp.layout("togglesplit")'')

            (bindd "SUPER + Return" "Open Ghostty Terminal Emulator" (exec (lib.getExe pkgs.ghostty)))
            (bindd "SUPER + F" "Toggle fullscreen" "hl.dsp.window.fullscreen()")
            (bindd "SUPER + g" "Toggle Hyprland zoomed out mode" (exec "${scripts.toggle-hypr-zoomed-out}"))
            (bindd "SUPER + d" "Rofi search" (exec "${scripts.rofi-launch} search"))
            (bindd "SUPER + s" "Simple Screenshot" (exec "${scripts.screenshot}"))
          ]
          ++ lib.optionals host.isDev [
            (bindd "SUPER + SHIFT + x" "Open Linear ticket from clipboard" (exec "${scripts.open-linear-ticket}"))
          ]
          ++ [
            (bindd "SUPER + E" "Open file manager" (exec "${scripts.launch-once {
              command = "${lib.getExe pkgs.ghostty} --class=ghostty.yazi -e ${pkgs.yazi}/bin/yazi ~/Downloads/";
              grep = "ghostty.yazi";
              useHypr = true;
              toggle = true;
            }}"))
            (bindd "SUPER + m" "Emoji Picker" (exec "${scripts.rofi-launch} emoji"))
            (bindd "SUPER + SPACE" "Switch keyboard layout" (exec "${scripts.switch-kb-layout}"))
            (bindd "ALT + d" "Open Google Gemini" (exec "${scripts.launch-once {
              command = "${browser.exe} --app=https://gemini.google.com --profile-directory=${browsers.personalProfile}";
              grep = geminiClass;
              useHypr = true;
              toggle = true;
            }}"))
            (bindd "SUPER + c" "Query Wolfram|Alpha with ChatGPT fallback" (exec "${scripts.rofi-launch} calc"))

            (bindd "F8" "Toggle Spotify Workspace" ''hl.dsp.workspace.toggle_special("spotify_player")'')
            (bindd "F8" "Launch Spotify if not running" (exec "pgrep spotify_player || ${lib.getExe pkgs.ghostty} --font-size=12 --class=ghostty.spotify_player -e ${pkgs.spotify-player}/bin/spotify_player"))

            (bindd "SUPER + F8" "Like current track on Spotify" (exec "${scripts.spotify-like}"))
            (bindd "SHIFT + F8" "Play a random album of the day" (exec "${scripts.random-album-of-the-day}"))

            (bindd "F7" "Wireless virtual Screen" (exec "${scripts.wireless-screen}"))

            (bindd "F11" "Toggle Obsidian Neovim Workspace" ''hl.dsp.workspace.toggle_special("obsidian_nvim")'')
            (bindd "F11" "Launch Obsidian if not launched" (exec "${scripts.launch-once {
              command = "${pkgs.obsidian}/bin/obsidian";
              grep = "initialTitle:.*Obsidian.*";
              useHypr = true;
            }}"))
            (bindd "F11" "Launch Neovim in Obsidian Vault" (exec "${scripts.launch-once {
              command = "${lib.getExe pkgs.ghostty} --class=ghostty.obsidian -e ${config.programs.neovim.finalPackage}/bin/nvim \"~/Documents/Marius\\\'\\\ Remote\\\ Vault\"";
              grep = "ghostty\\\.obsidian";
              useHypr = true;
            }}"))
            (bindd "SHIFT + F11" "Launch Obsidian if not launched" (exec "${scripts.launch-once {
              command = "${pkgs.obsidian}/bin/obsidian";
              grep = "initialClass: obsidian";
              useHypr = true;
            }}"))
            (bindd "SHIFT + F11" "Toggle Obsidian Workspace" ''hl.dsp.workspace.toggle_special("obsidian")'')
          ]
          ++ lib.optionals (sideBrowser != null) [
            (bindd "F12" "Toggle ${sideBrowser.title} Workspace" ''hl.dsp.workspace.toggle_special("${sideBrowser.name}")'')
            (bindd "F12" "Launch ${sideBrowser.title} if not running" (exec "${scripts.launch-once {
              inherit (sideBrowser) command;
              grep = sideBrowser.windowClass;
              useHypr = true;
            }}"))
          ]
          ++ [
            (bindd "SUPER + SHIFT + Return" "SSH Session Selection" (exec "${scripts.rofi-launch} ssh"))
          ]
          ++ lib.optionals host.isDev [
            (bindd "SUPER + SHIFT + G" "GitLab MR search" (exec "${scripts.rofi-launch} gitlab"))
          ]
          ++ [
            (bindd "SUPER + SHIFT + Space" "Toggle active window floating" ''hl.dsp.window.float({ action = "toggle" })'')
            (bindd "SUPER + ALT + Space" "Toggle workspace floating" toggleWorkspaceFloating)
            (bindd "SUPER + SHIFT + s" "Take Screenshot and then edit it" (exec "${scripts.screenshot} edit"))
            (bindd "SUPER + SHIFT + F" "Toggle fake fullscreen" toggleFakeFullscreen)
            (bindd "SUPER + SHIFT + N" "Move current workspace to next monitor" ''hl.dsp.workspace.move({ monitor = "+1" })'')
            (bindd "SUPER + SHIFT + t" "Open Rofi Translation Menu" (exec "${scripts.rofi-launch} translate"))
            (bindd "SUPER + SHIFT + c" "Toggle Notification Center" (exec "${pkgs.swaynotificationcenter}/bin/swaync-client -t"))
            (bindd "SUPER + SHIFT + d" "Toggle Dark Mode" (exec "${pkgs.darkman}/bin/darkman toggle"))
            (bindd "SUPER + SHIFT + w" "Change Wallpaper" (exec "${scripts.rofi-launch} wallpaper"))
            (bindd "SUPER + SHIFT + z" "Toggle zen mode" (exec "${scripts.toggle-zen}"))
            (bindd "SUPER + SHIFT + P" "Color picker" (exec "${pkgs.hyprpicker}/bin/hyprpicker -a"))
            (bindd "SUPER + SHIFT + q" "Power Menu" (exec "${scripts.rofi-launch} power"))
          ]
          ++ lib.optionals has1Password [
            (bindd "SUPER + SHIFT + i" "1Password quick access" (exec "${pkgs._1password-gui}/bin/1password --quick-access"))
          ]
          ++ [
            (bindd "SUPER + SHIFT + v" "Rofi Clipboard History" (exec "${scripts.rofi-launch} cliphist"))
            (bindd "SUPER + SHIFT + o" "Obsidian Search" (exec "${scripts.rofi-launch} obsidian"))

            (bindd "SUPER + CTRL + s" "Copy text from screen using OCR" (exec "${scripts.ocr-screenshot}"))

            # bound to mousewheel left/right
            (bindd "CTRL + SHIFT + Left" "Previous workspace" ''hl.dsp.focus({ workspace = "m-1" })'')
            (bindd "CTRL + SHIFT + Right" "Next workspace" ''hl.dsp.focus({ workspace = "m+1" })'')
          ]
          ++ (
            builtins.concatLists (builtins.genList (
                i: let
                  ws = i + 1;
                in [
                  (bindd "SUPER + ${toString ws}" "Switch to workspace ${toString ws}" ''hl.dsp.focus({ workspace = ${toString ws} })'')
                  (bindd "SUPER + SHIFT + ${toString ws}" "Move to workspace ${toString ws}" ''hl.dsp.window.move({ workspace = ${toString ws} })'')
                  (bindd "SUPER + CTRL + ${toString ws}" "Move to workspace ${toString ws} silently" ''hl.dsp.window.move({ workspace = ${toString ws}, follow = false })'')
                ]
              )
              9)
          )
          ++ lib.optionals config.services.blueman-applet.enable [
            (bindd "SUPER + SHIFT + b" "Rofi Bluetooth" (exec "${scripts.rofi-launch} bluetooth"))
          ]
          ++ lib.optionals config.programs.configured.npu-dictate.enable [
            (bindd "SUPER + v" "Dictate (hold to talk)" (exec "${npuDictate} start"))
            # On key release (r flag), ignore mods (i) and bubble through (n).
            # Transparent (t): releasing anything else while v is held (Super first,
            # a mouse click) shadows an ordinary release bind, and the stop is never sent.
            (binddrint "v" "Dictate (transcribe)" (exec "${npuDictate} stop"))
          ]
          ++ [
            # Allow on lockscreen (locked) and allow repeat (repeating)
            (binddle "XF86AudioRaiseVolume" "Increase volume" (exec volumeUp))
            (binddle "XF86AudioLowerVolume" "Decrease volume" (exec volumeDown))
            (binddle "XF86AudioMute" "Mute audio" (exec "${pkgs.pamixer}/bin/pamixer -t"))
            (binddle "XF86AudioMicMute" "Mute microphone" (exec "${pkgs.pamixer}/bin/pamixer --default-source -t"))
            (binddle "XF86AudioPlay" "Toggle media playback" (exec "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle"))
            (binddle "XF86AudioPause" "Toggle media playback" (exec "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle"))
            (binddle "XF86AudioNext" "Next track" (exec "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-next"))
            (binddle "XF86AudioPrev" "Previous track" (exec "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-prev"))
            (binddle "XF86MonBrightnessUp" "Increase brightness" (exec "${pkgs.brightnessctl}/bin/brightnessctl set 5%+"))
            (binddle "XF86MonBrightnessDown" "Decrease brightness" (exec "${pkgs.brightnessctl}/bin/brightnessctl set 5%-"))
            (binddle "SUPER + bracketright" "Increase volume" (exec volumeUp))
            (binddle "SUPER + slash" "Decrease volume" (exec volumeDown))
            (binddle "SUPER + p" "Toggle media playback (play/pause)" (exec "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle"))
            (binddle "SUPER + backslash" "Mute audio" (exec "${pkgs.pamixer}/bin/pamixer -t"))
            (binddle "SUPER + SHIFT + bracketright" "Increase brightness" (exec "${pkgs.brightnessctl}/bin/brightnessctl set 5%+"))
            (binddle "SUPER + SHIFT + slash" "Decrease brightness" (exec "${pkgs.brightnessctl}/bin/brightnessctl set 5%-"))

            # A drag/resize ends at the next key or mouse-button event: in practice releasing
            # the button, X/Y/Z or SUPER
            (bindd "SUPER + mouse:272" "Move window" "hl.dsp.window.drag()")
            (bindd "SUPER + mouse:273" "Resize window" "hl.dsp.window.resize()")
            (bindd "SUPER + X" "Resize window" "hl.dsp.window.resize()")
            (bindd "SUPER + Y" "Move window" "hl.dsp.window.drag()")
            (bindd "SUPER + Z" "Move window" "hl.dsp.window.drag()")

            # Allow repeat (repeating = true)
            (bindde "SUPER + SHIFT + h" "Move window left" (moveOrTile "l" (-30) 0))
            (bindde "SUPER + SHIFT + l" "Move window right" (moveOrTile "r" 30 0))
            (bindde "SUPER + SHIFT + k" "Move window up" (moveOrTile "u" 0 (-30)))
            (bindde "SUPER + SHIFT + j" "Move window down" (moveOrTile "d" 0 30))

            (bindde "SUPER + ALT + l" "Resize window right" ''hl.dsp.window.resize({ x = 30, y = 0, relative = true })'')
            (bindde "SUPER + ALT + h" "Resize window left" ''hl.dsp.window.resize({ x = -30, y = 0, relative = true })'')
            (bindde "SUPER + ALT + k" "Resize window up" ''hl.dsp.window.resize({ x = 0, y = -30, relative = true })'')
            (bindde "SUPER + ALT + j" "Resize window down" ''hl.dsp.window.resize({ x = 0, y = 30, relative = true })'')
          ]
          ++ lib.optionals cfg.umlautBinds [
            (bindde "CTRL + semicolon" "Type ö" (exec "${pkgs.wtype}/bin/wtype ö"))
            (bindde "CTRL + apostrophe" "Type ä" (exec "${pkgs.wtype}/bin/wtype ä"))
            (bindde "CTRL + bracketleft" "Type ü" (exec "${pkgs.wtype}/bin/wtype ü"))
            (bindde "CTRL + minus" "Type ß" (exec "${pkgs.wtype}/bin/wtype ß"))

            (bindde "CTRL + SHIFT + semicolon" "Type Ö" (exec "${pkgs.wtype}/bin/wtype Ö"))
            (bindde "CTRL + SHIFT + apostrophe" "Type Ä" (exec "${pkgs.wtype}/bin/wtype Ä"))
            (bindde "CTRL + SHIFT + bracketleft" "Type Ü" (exec "${pkgs.wtype}/bin/wtype Ü"))

            (bindde "SUPER + semicolon" "Type ö" (exec "${pkgs.wtype}/bin/wtype ö"))
            (bindde "SUPER + apostrophe" "Type ä" (exec "${pkgs.wtype}/bin/wtype ä"))
            (bindde "SUPER + bracketleft" "Type ü" (exec "${pkgs.wtype}/bin/wtype ü"))
            (bindde "SUPER + minus" "Type ß" (exec "${pkgs.wtype}/bin/wtype ß"))

            (bindde "SUPER + SHIFT + semicolon" "Type Ö" (exec "${pkgs.wtype}/bin/wtype Ö"))
            (bindde "SUPER + SHIFT + apostrophe" "Type Ä" (exec "${pkgs.wtype}/bin/wtype Ä"))
            (bindde "SUPER + SHIFT + bracketleft" "Type Ü" (exec "${pkgs.wtype}/bin/wtype Ü"))
          ];
      };
      extraConfig =
        # lua
        ''
          -- Loaded by the config rather than home-manager's `plugins` (a one-off `hyprctl plugin load`
          -- on hyprland.start), so a rebuild that changes the store path swaps the loaded plugin. After a
          -- Hyprland bump the new build refuses the still-running compositor until Hyprland restarts
          hl.plugin.load("${pkgs.hyprlandPlugins.hypr-dynamic-cursors}/lib/libhypr-dynamic-cursors.so")

          -- The plugin is loaded after this file has run and then reloads the config. Its options exist
          -- only while it is loaded; setting them otherwise is an unknown-key error
          if hl.get_config("plugin.dynamic_cursors.enabled") ~= nil then
            hl.config({
              plugin = {
                dynamic_cursors = {
                  enabled = true,
                  threshold = 1,
                  mode = "tilt",
                  shake = {
                    enabled = false,
                  },
                },
              },
            })
          end
        ''
        # macOS Tahoe / Mission Control-style workspace overview (3-finger swipe up/down)
        + lib.optionalString cfg.hyprtasking.enable
        # lua
        ''

          hl.plugin.load("${pkgs.hyprlandPlugins.hyprtasking}/lib/libhyprtasking.so")

          if hl.get_config("plugin.hyprtasking.layout") ~= nil then
            local theme_mode = "dark"
            local mode_file = io.open((os.getenv("HOME") or "") .. "/.theme/mode", "r")
            if mode_file ~= nil then
              local raw = mode_file:read("*l")
              mode_file:close()
              if raw == "light" then
                theme_mode = "light"
              end
            end

            local is_light = theme_mode == "light"
            hl.config({
              general = {
                col = {
                  active_border = is_light and "rgba(${darkBgHex}99)" or "rgba(ffffffcc)",
                  inactive_border = is_light and "rgba(${darkBgHex}22)" or "rgba(ffffff24)",
                },
              },
              plugin = {
                hyprtasking = {
                  layout = "linear",
                  bg_color = is_light and 0xa8${lightBgHex} or 0x94${darkBgHex},
                  gap_size = 12,
                  border_size = 2,
                  exit_on_hovered = true,
                  warp_on_move_window = 1,
                  close_overview_on_reload = true,
                  gestures = {
                    enabled = false,
                    open_distance = 180,
                  },
                  linear = {
                    top = true,
                    height = 170,
                    scroll_speed = 1.0,
                    blur = true,
                    workspace_margin = 24,
                    workspace_scale = 0.0,
                    workspace_dim = 0.0,
                    workspace_blur = false,
                  },
                },
              },
            })
          end
        ''
        # Continuous macOS-like screen zoom on CTRL + scroll. Takes CTRL + scroll away from
        # applications (e.g. page zoom in browsers), hence only on dev hosts
        + lib.optionalString host.isDev
        # lua
        ''

          hl.plugin.load("${pkgs.hyprlandPlugins.macos-zoom}/lib/macos-zoom.so")

          if hl.get_config("plugin.macos_zoom.raw_scroll") ~= nil then
            hl.config({
              plugin = {
                macos_zoom = {
                  raw_scroll = true,
                  modifier = "CTRL",
                  consume_scroll = true,
                  sensitivity = 0.01,
                  max_factor = 40.0,
                  independent_displays = true,
                  -- the touchpad scrolls naturally; zoom in when the fingers move up, as on macOS
                  invert_touchpad = true,
                  -- keep zooming and slow down after the fingers lift
                  momentum = true,
                  momentum_decay = 300.0,
                },
              },
            })
          end
        '';
    };
  };
}
