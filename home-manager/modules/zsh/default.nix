{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.zsh;
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  options.programs.configured.zsh = {
    enable = mkEnableOption "Z-Shell";
  };
  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      package = pkgs.zsh;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "tmux"
        ];
        extraConfig = ''
          ZSH_TMUX_AUTOSTART=true
        '';
      };
      history = {
        append = true;
        size = 50000;
      };
      shellAliases = {
        lg = "${lib.getExe pkgs.lazygit}";
        ls = "${lib.getExe pkgs.lsd}";
        la = "${lib.getExe pkgs.lsd} -la";
        tree = "${lib.getExe pkgs.lsd} --tree";
        g3 = "${lib.getExe pkgs.gemini-cli} -m gemini-3.1-pro-preview";
        present = "${lib.getExe pkgs.zathura} --mode=presentation";
        vi = "nvim";
        vim = "nvim";
        stty = mkIf isDarwin "/bin/stty";
        bat = "bat --theme auto:system --theme-dark default --theme-light GitHub";
      };
      initContent = import ./init.nix {
        inherit isDarwin lib pkgs;
      };
      plugins = [
        {
          name = "fzf-tab";
          src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        }
        {
          name = "zsh-vi-mode";
          src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
        }
      ];
    };
  };
}
