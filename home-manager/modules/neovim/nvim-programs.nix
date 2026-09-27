{pkgs, ...}:
with pkgs; let
  # Enough for editing configs on servers and ISOs. gcc and tree-sitter are
  # needed because nvim-treesitter compiles its parsers at runtime.
  base = [
    alejandra
    fd
    fzf
    gcc
    lazygit
    lsd
    nil
    ripgrep
    shfmt
    stylua
    taplo
    tree-sitter
  ];
in {
  inherit base;
  full =
    base
    ++ [
      bash-language-server
      black
      cargo
      clang-tools
      dart
      docker-compose-language-service
      dockerfile-language-server
      gitlab-ci-ls
      gnumake
      goimports-reviser
      golangci-lint
      golangci-lint-langserver
      gopls
      gotools
      haskell-language-server
      helm-ls
      hyprls
      jdt-language-server
      kotlin-language-server
      libsecret
      lua-language-server
      marksman
      nixd
      nodejs_22
      pastel
      prettierd
      ruff
      rumdl
      rustfmt
      svelte-language-server
      tailwindcss-language-server
      terraform-ls
      texlab
      tinymist
      ty
      typescript
      typescript-language-server
      typstyle
      vscode-langservers-extracted
      websocat
      yaml-language-server
      zls
    ];
}
