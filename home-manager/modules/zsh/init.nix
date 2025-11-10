pkgs:
# bash
''
  export LANGUAGE=en_US.UTF-8
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

  export NIXPKGS_ALLOW_UNFREE=1
''
