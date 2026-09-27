{
  host,
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.zsh;
  inherit (host) isDarwin;
in {
  options.programs.configured.zsh = {
    enable = mkEnableOption "Z-Shell";
  };
  config = mkIf cfg.enable {
    # Not only for interactive zsh, so GUI apps and user services see them too
    home.sessionVariables = {
      LANG = "en_DK.UTF-8";
      LANGUAGE = "en_DK.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      NIXPKGS_ALLOW_UNFREE = "1";
    };
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
          if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
            ZSH_TMUX_AUTOSTART=false
          else
            ZSH_TMUX_AUTOSTART=true
          fi
        '';
      };
      history = {
        append = true;
        size = 50000;
      };
      shellAliases = {
        hud = mkIf config.programs.configured.hunk.enable "hunk diff --watch";
        la = "${lib.getExe pkgs.lsd} -la";
        lg = "${lib.getExe pkgs.lazygit}";
        ls = "${lib.getExe pkgs.lsd}";
        lsg = "ls-git";
        present = mkIf host.isGraphical "${lib.getExe pkgs.zathura} --mode=presentation";
        stty = mkIf isDarwin "/bin/stty"; # Fix for prompt error on macos
        tree = "${lib.getExe pkgs.lsd} --tree";
        vi = "nvim";
        vim = "nvim";
      };
      initContent = mkMerge [
        # Static `brew shellenv` output (saves a fork per shell); runs before
        # compinit so Homebrew completions are picked up too
        (mkIf isDarwin (mkOrder 550 ''
          export HOMEBREW_PREFIX=/opt/homebrew HOMEBREW_CELLAR=/opt/homebrew/Cellar HOMEBREW_REPOSITORY=/opt/homebrew
          path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
          fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
          export INFOPATH="/opt/homebrew/share/info:''${INFOPATH:-}"
        ''))
        (import ./init.nix {inherit lib pkgs;})
      ];
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
