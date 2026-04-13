{
  isDarwin,
  lib,
  pkgs,
}:
# bash
''
  export LANG=en_US.UTF-8
  export LANGUAGE=en_US.UTF-8
  export NIXPKGS_ALLOW_UNFREE=1

  export MANPAGER="${lib.getExe pkgs.bat} -plman --theme auto:system --theme-dark default --theme-light GitHub"
  help() {
      "$@" --help 2>&1 | ${lib.getExe pkgs.bat} --plain --language=help --theme auto:system --theme-dark default --theme-light GitHub
  }

  export FZF_DEFAULT_OPTS="--bind ctrl-e:preview-down,ctrl-y:preview-up,alt-k:up,alt-j:down --preview-window=right,65%"
  export _ZO_FZF_OPTS="--tmux 80%,80% --bind ctrl-e:preview-down,ctrl-y:preview-up,alt-k:up,alt-j:down --preview \"FILE=\"{}\"; FILE=\"\$(echo \"\$FILE\" | sed \"s/\'//g\")\"; ${pkgs.lsd}/bin/lsd --git --icon=always --color=always --tree --depth=2 /\"\''${FILE#*/}\"\""
  zvm_after_init_commands+=(eval "$(${pkgs.fzf}/bin/fzf --zsh)")
  zoxide_jump() {
    if zi; then
      zle push-line
      zle accept-line
    fi
    zle redisplay
  }
  zle -N zoxide_jump
  bindkey -M 'viins' '^Z' zoxide_jump

  bindkey -M 'viins' '^[m' up-line-or-beginning-search
  bindkey -M 'vicmd' '^[m' up-line-or-beginning-search

  ${
    if isDarwin
    then ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    ''
    else ""
  }
''
