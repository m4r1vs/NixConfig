{
  lib,
  config,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.tmux;
  theme = systemArgs.theme;
  mkTmuxWindowStatusFormat = {
    shellIconMap,
    showPaneCount,
  }: let
    iconSubstitutions = lib.concatStrings (lib.mapAttrsToList
      (cmd: icon: "#{s|${cmd}|${icon}|:")
      shellIconMap);

    closeSubstitutions = lib.concatStrings (
      lib.replicate
      (lib.length (lib.attrNames shellIconMap))
      "}"
    );

    pathFormat = "#{s|${config.home.username}|~|:#{b:pane_current_path}}";

    format =
      "#{?#{==:#{pane_current_command},zsh},"
      + "#{?#{window_active},,} ${pathFormat},"
      + "${"${iconSubstitutions}pane_current_command${closeSubstitutions}"}"
      + " ${pathFormat}"
      + "}${
        if showPaneCount
        then "#{?#{>:#{window_panes},1}, (#{window_panes}),}"
        else ""
      }";
  in
    format;
in {
  options.programs.configured.tmux = {
    enable = mkEnableOption "Terminal Multiplexer";
    shellIconMap = mkOption {
      type = types.attrsOf types.str;
      default = {
        htop = "";
        lazygit = "";
        mpv = "";
        newsboat = "󰎕";
        nvim = "";
        nix = "󱄅";
        sudo = "";
        yazi = "󰇥";
        bash = "";
        terraform = "";
      };
      description = "Map program-names to their icons";
    };
    showPaneCount = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to show number of open panes (if more than 1)";
    };
  };
  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      package = pkgs.tmux;
      keyMode = "vi";
      shortcut = "Space";
      escapeTime = 0;
      baseIndex = 1;
      customPaneNavigationAndResize = true;
      disableConfirmationPrompt = true;
      sensibleOnTop = true;
      mouse = true;
      historyLimit = 5000;
      terminal = "xterm-256color";
      extraConfig =
        /*
        tmux
        */
        ''
          set -g allow-passthrough all
          set -ga update-environment TERM
          set -ga update-environment TERM_PROGRAM

          set-option -g set-titles on
          set-option -g set-titles-string "${mkTmuxWindowStatusFormat {
            shellIconMap = cfg.shellIconMap;
            showPaneCount = cfg.showPaneCount;
          }}"

          bind-key -n M-L switch-client -n
          bind-key -n M-H switch-client -p
          bind-key -n M-N new-session

          bind-key C-e copy-mode \; if-shell -F "#{pane_in_mode}" "send-keys C-e" "copy-mode \; send-keys C-e"
          bind-key C-y copy-mode \; if-shell -F "#{pane_in_mode}" "send-keys C-y" "copy-mode \; send-keys C-y"
          bind-key C-u copy-mode \; if-shell -F "#{pane_in_mode}" "send-keys C-u" "copy-mode \; send-keys C-u"
          bind-key C-d copy-mode \; if-shell -F "#{pane_in_mode}" "send-keys C-d" "copy-mode \; send-keys C-d"

          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
          bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
          bind-key v copy-mode
          bind-key k copy-mode

          # Window bindings
          bind-key -n M-l next
          bind-key -n M-h prev
          bind-key -n M-n new-window -c "#{pane_current_path}" \;
          bind-key -n M-x kill-window
          bind-key -n M-1 select-window -t 1
          bind-key -n M-2 select-window -t 2
          bind-key -n M-3 select-window -t 3
          bind-key -n M-4 select-window -t 4
          bind-key -n M-5 select-window -t 5
          bind-key -n M-6 select-window -t 6
          bind-key -n M-7 select-window -t 7
          bind-key -n M-8 select-window -t 8
          bind-key -n M-9 select-window -t 9
          bind-key -n M-0 select-window -t 10

          # Toggle Status bar
          bind-key z set status

          bind-key l swap-window -t +1 \; next
          bind-key h swap-window -t -1 \; prev

          # Pane bindings
          bind-key -n M-v split-window -h -c "#{pane_current_path}"
          bind-key -n M-s split-window -v -c "#{pane_current_path}"

          # Resize pane bindings
          bind-key -n M-f resize-pane -Z \;
          bind-key -n M-Left resize-pane -L 5
          bind-key -n M-Down resize-pane -D 5
          bind-key -n M-Up resize-pane -U 5
          bind-key -n M-Right resize-pane -R 5

          # dont ask for confirmation closing panes
          bind-key x kill-pane
          bind-key Enter split-window

          # If getting strings cut in left status or right
          # Here 20 is the length of the characters in the string
          set -g status-right-length 20
          set -g status-left-length 20
        '';
      plugins = with pkgs; [
        tmuxPlugins.vim-tmux-navigator
        tmuxPlugins.jump
        tmuxPlugins.yank
        {
          plugin =
            tmuxPlugins.mkTmuxPlugin
            {
              pluginName = "minimal-tmux-status";
              version = "1.0";
              src = pkgs.fetchFromGitHub {
                owner = "niksingh710";
                repo = "minimal-tmux-status";
                rev = "main";
                sha256 = "sha256-k/rEvNWUTge1uYwwSMfgM7CDoKanIm8ED3vo5mqDe08=";
              };
              rtpFilePath = "minimal.tmux";
            };
          extraConfig = ''
            set -g @minimal-tmux-fg "#000000"
            set -g @minimal-tmux-bg "${theme.primaryColor.hex}"
            set -g @minimal-tmux-justify "centre"
            set -g @minimal-tmux-indicator-str "   󰴻   "
            set -g @minimal-tmux-indicator true
            set -g @minimal-tmux-status "bottom"

            # Enables or disables the left and right status bar
            set -g @minimal-tmux-right true
            set -g @minimal-tmux-left true

            # expanded icon (fullscreen icon)
            set -g @minimal-tmux-expanded-icon " "

            # on all tabs (default is false)
            # false will make it visible for the current tab only
            set -g @minimal-tmux-show-expanded-icons-for-all-tabs false

            # To add or remove extra text in status bar
            set -g @minimal-tmux-status-right-extra ""
            set -g @minimal-tmux-status-left-extra "       "

            # To make the selection box rounded () or edged <>
            set -g @minimal-tmux-use-arrow false

            set -g @minimal-tmux-window-status-format " ${mkTmuxWindowStatusFormat {
              shellIconMap = cfg.shellIconMap;
              showPaneCount = cfg.showPaneCount;
            }} "

            # Not recommended to change these values
            set -g @minimal-tmux-status-right " %d.%m. 󰥔 %H:%M"
            set -g @minimal-tmux-status-left ""
          '';
        }
      ];
    };
  };
}
