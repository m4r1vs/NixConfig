{
  pkgs,
  osConfig,
  systemArgs,
  lib,
  ...
}: let
  isDesktop = osConfig.configured ? desktop && osConfig.configured.desktop.enable;
  isDarwin = systemArgs.system == "aarch64-darwin";
  isGraphical = isDarwin || isDesktop;
in
  with pkgs;
    [
      alejandra
      bash-language-server
      black
      docker-compose-language-service
      dockerfile-language-server
      fd
      fzf
      gcc
      gitlab-ci-ls
      gnumake
      goimports-reviser
      golangci-lint
      golangci-lint-langserver
      gopls
      helm-ls
      hyprls
      lazygit
      libsecret
      lua-language-server
      marksman
      nil
      nixd
      nodejs_22
      prettierd
      pyright
      ripgrep
      shfmt
      stylua
      svelte-language-server
      tailwindcss-language-server
      taplo
      terraform-ls
      texlab
      tinymist
      tree-sitter
      vscode-langservers-extracted
      websocat
      yaml-language-server
      zls
    ]
    ++ lib.optionals isGraphical [
      cargo
      clang-tools
      dart
      gotools
      jdt-language-server
      kotlin-language-server
      rustfmt
      typstyle
    ]
