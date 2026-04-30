{
  lib,
  config,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.ghostty;
  isDarwin = systemArgs.system == "aarch64-darwin";
  theme = systemArgs.theme;
in {
  options.programs.configured.ghostty = {
    enable = mkEnableOption "Cross-platform terminal emulator.";
  };
  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      clearDefaultKeybinds = true;
      enableZshIntegration = true;
      settings = {
        theme = "dark:flexoki-dark,light:flexoki-light";
        window-padding-x =
          if isDarwin
          then 6
          else 3;
        window-padding-y =
          if isDarwin
          then 6
          else 3;
        gtk-titlebar = false;
        font-size =
          if isDarwin
          then 12
          else 10;
        font-family = [
          "JetBrainsMono Nerd Font Propo"
          "Apple Color Emoji"
        ];
        confirm-close-surface = false;
        resize-overlay = "never";
        window-decoration =
          if isDarwin
          then "auto"
          else false;
        macos-titlebar-style = mkIf isDarwin "hidden";
        macos-icon = "official";
        class = "ghostty.default";
        mouse-hide-while-typing = true;
        window-padding-balance = true;
        background-blur = mkIf isDarwin 35;
        window-colorspace = mkIf isDarwin "display-p3";
        link-url = true;
        keybind =
          [
            "ctrl+i=csi:6~"
            "ctrl+minus=decrease_font_size:1"
            "ctrl+equal=increase_font_size:1"
            "ctrl+plus=increase_font_size:1"
            "ctrl+shift+v=paste_from_clipboard"
            "ctrl+shift+c=copy_to_clipboard"
            "ctrl+shift+i=inspector:toggle"
            "ctrl+zero=reset_font_size"
            "shift+insert=paste_from_selection"
          ]
          ++ optionals isDarwin [
            "super+c=copy_to_clipboard"
            "super+v=paste_from_clipboard"
            "super+q=quit"
            # "global:super+enter=new_window"
          ];
      };
      themes = {
        flexoki-dark = {
          palette = [
            "0=#100f0f"
            "1=#d14d41"
            "2=#879a39"
            "3=#d0a215"
            "4=#4385be"
            "5=#ce5d97"
            "6=#3aa99f"
            "7=#878580"
            "8=#575653"
            "9=#af3029"
            "10=#66800b"
            "11=#ad8301"
            "12=#205ea6"
            "13=#a02f6f"
            "14=#24837b"
            "15=#e6e5df"
          ];
          background = "${theme.backgroundColor}";
          foreground = "#e6e5df";
          cursor-color = "#cecdc3";
          cursor-text = "#100f0f";
          selection-background = "#403e3c";
          selection-foreground = "${theme.secondaryColor.hex}";
          background-opacity = 0.92;
        };
        flexoki-light = {
          palette = [
            "0=#100f0f"
            "1=#af3029"
            "2=#66800b"
            "3=#ad8301"
            "4=#205ea6"
            "5=#a02f6f"
            "6=#24837b"
            "7=#6f6e69"
            "8=#b7b5ac"
            "9=#d14d41"
            "10=#879a39"
            "11=#d0a215"
            "12=#4385be"
            "13=#ce5d97"
            "14=#3aa99f"
            "15=#cecdc3"
          ];
          background = "#fffcf0";
          foreground = "#100f0f";
          cursor-color = "#100f0f";
          cursor-text = "#fffcf0";
          selection-background = "#cecdc3";
          selection-foreground = "${theme.secondaryColor.hex}";
          background-opacity = 0.92;
        };
      };
    };
  };
}
