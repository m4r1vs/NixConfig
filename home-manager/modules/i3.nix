{
  lib,
  config,
  scripts,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.i3;
  mod = "Mod4";
  terminal = "${pkgs.ghostty}/bin/ghostty";
in {
  options.programs.configured.i3 = {
    enable = mkEnableOption "Tiling X11 Window Manager";
  };
  config = mkIf cfg.enable {
    programs = {
      autorandr.enable = true;
    };
    services = {
      configured = {
        dunst.enable = true;
        picom.enable = true;
        polybar.enable = true;
        flameshot.enable = true;
      };
    };

    home.file."./.config/greenclip.toml".text = ''
      [greenclip]
        blacklisted_applications = []
        enable_image_support = true
        history_file = "${config.home.homeDirectory}/.cache/greenclip.history"
        image_cache_directory = "${config.home.homeDirectory}/.cache/greenclip"
        max_history_length = 75
        max_selection_size_bytes = 0
        static_history = []
        trim_space_from_selection = true
        use_primary_selection_as_input = false
    '';

    xsession.windowManager.i3 = {
      enable = true;
      config = {
        modifier = mod;
        gaps = {
          bottom = 8 + 20;
          inner = 6;
          smartGaps = false;
        };
        bars = [];
        startup = [
          {
            command = "${pkgs.autorandr}/bin/autorandr -c";
            always = true;
            notification = false;
          }
          {
            command = "${pkgs.writeShellScript "launch-polybar" ''
              polybar-msg cmd quit
              sleep 2
              WLAN_INTERFACE=$(ip a | grep wlp | awk -F': ' '{ print $2 }')
              if type "xrandr"; then
                for m in $(xrandr --query | grep " connected" | cut -d " " -f1); do
                  MONITOR=$m polybar --reload clock &
                  MONITOR=$m polybar --reload media &
                  MONITOR=$m polybar --reload workspaces &
                  MONITOR=$m polybar --reload sysinfo &
                done
              else
                polybar --reload clock &
                polybar --reload media &
                polybar --reload workspaces &
                polybar --reload sysinfo &
              fi
              polybar --reload tray &
            ''}";
            always = true;
            notification = false;
          }
          {
            command = "${pkgs.haskellPackages.greenclip}/bin/greenclip daemon";
            always = true;
            notification = false;
          }
          {
            command = "sleep 1 && ${pkgs.feh}/bin/feh --bg-fill --randomize ${builtins.path {path = ../wallpaper;}}/*";
            always = false;
            notification = false;
          }
          {
            command = "${scripts.brightness-change-notify}";
            always = true;
            notification = false;
          }
          {
            command = "${scripts.volume-change-notify}";
            always = true;
            notification = false;
          }
          {
            command = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";
            always = true;
            notification = false;
          }
          {
            command = "${pkgs._1password-gui}/bin/1password --silent --ozone-platform-hint=x11";
            always = true;
            notification = false;
          }
        ];
        terminal = terminal;
        defaultWorkspace = "workspace number 1";
        window = {
          titlebar = false;
          border = 0;
        };
        floating = {
          titlebar = false;
          border = 0;
        };
        modes = {
          resize = {
            "h" = "resize shrink width 10 px or 10 ppt";
            "j" = "resize grow height 10 px or 10 ppt";
            "k" = "resize shrink height 10 px or 10 ppt";
            "l" = "resize grow width 10 px or 10 ppt";

            "Return" = "mode \"default\"";
            "Escape" = "mode \"default\"";
            "${mod}+r" = "mode \"default\"";
          };
        };
        keybindings = {
          "${mod}+Return" = "exec ${terminal}";
          "${mod}+Shift+Return" = "exec ${pkgs.writeShellScript "rofi-ssh" ''
            ${pkgs.rofi}/bin/rofi -show ssh -theme-str "entry{placeholder:\"SSH into a Remote...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 38% 42%;}"
          ''}";

          "${mod}+q" = "kill";

          "${mod}+Shift+q" = "exec --no-startup-id ${pkgs.writeShellScript "rofi-power-menu" ''
            ${pkgs.rofi}/bin/rofi -show power-menu -modi power-menu:${scripts.rofi-power-menu} -theme-str "entry {placeholder:\"Power Menu...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 38% 44%;}"
          ''}";

          "${mod}+d" = "exec --no-startup-id ${pkgs.writeShellScript "rofi-launcher" ''
            ${pkgs.rofi}/bin/rofi -theme-str "entry {placeholder: \"Launch a Program...\";}entry{padding: 10 10 0 12;}" -combi-modi search:${scripts.rofi-search},drun -show combi
          ''}";

          "${mod}+m" = "exec --no-startup-id ${pkgs.writeShellScript "rofi-emoji" ''
            ${pkgs.rofimoji}/bin/rofimoji --selector-args="-theme-str \"listview{dynamic:true;columns:12;layout:vertical;flow:horizontal;reverse:false;lines:10;}element-text{enabled:false;}element-icon{size:32px;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 24;}\"" --use-icons --skin-tone neutral --selector rofi --max-recent 0 --action clipboard
          ''}";

          "${mod}+Shift+v" = "exec --no-startup-id ${pkgs.writeShellScript "rofi-greenclip" ''
            ${pkgs.rofi}/bin/rofi -modi "clipboard:${pkgs.haskellPackages.greenclip}/bin/greenclip print" -show clipboard -run-command '{cmd}' -theme-str "entry{placeholder:\"Search your Clipboard...\";}element{children:[element-text,element-icon];}inputbar{padding: 0 0 0 0;}"
          ''}";

          "${mod}+space" = "exec --no-startup-id ${scripts.switch-kb-layout}";

          "${mod}+Shift+i" = "exec --no-startup-id ${pkgs._1password-gui}/bin/1password --quick-access";

          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          "${mod}+Shift+d" = "exec --no-startup-id ${pkgs.darkman}/bin/darkman toggle";
          "${mod}+Shift+w" = "exec --no-startup-id ${pkgs.feh}/bin/feh --bg-fill --randomize ${builtins.path {path = ../wallpaper;}}/*";
          "${mod}+Shift+s" = "exec --no-startup-id ${pkgs.flameshot}/bin/flameshot gui";
          "${mod}+Shift+n" = "move workspace to output next";

          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          "${mod}+f" = "fullscreen toggle";

          "${mod}+t" = "layout toggle split";

          "${mod}+Shift+space" = "floating toggle";

          "${mod}+Shift+minus" = "move scratchpad";
          "${mod}+minus" = "scratchpad show";

          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";
          "${mod}+0" = "workspace number 10";

          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";
          "${mod}+Shift+6" = "move container to workspace number 6";
          "${mod}+Shift+7" = "move container to workspace number 7";
          "${mod}+Shift+8" = "move container to workspace number 8";
          "${mod}+Shift+9" = "move container to workspace number 9";
          "${mod}+Shift+0" = "move container to workspace number 10";

          "${mod}+r" = "mode resize";
        };
      };
    };
  };
}
