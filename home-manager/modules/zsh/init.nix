{
  isDarwin,
  lib,
  pkgs,
}:
# bash
''
  export LANG=en_DK.UTF-8
  export LANGUAGE=en_DK.UTF-8
  export LC_MONETARY=de_DE.UTF-8
  export NIXPKGS_ALLOW_UNFREE=1

  export MANPAGER="${lib.getExe pkgs.bat} -plman"
  help() {
      "$@" --help 2>&1 | ${lib.getExe pkgs.bat} --plain --language=help
  }

  export _ZO_FZF_OPTS="--tmux 80%,80% --bind ctrl-e:preview-down,ctrl-y:preview-up,alt-k:up,alt-j:down --preview \"FILE=\"{}\"; FILE=\"\$(echo \"\$FILE\" | sed \"s/\'//g\")\"; ${pkgs.lsd}/bin/lsd --git --icon=always --color=always --tree --depth=2 /\"\''${FILE#*/}\"\""
  zvm_after_init_commands+=(eval "$(${pkgs.fzf}/bin/fzf --zsh)")

  zstyle ':fzf-tab:*' use-fzf-default-opts yes

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
