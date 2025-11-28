{
  lib,
  osConfig,
  config,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.neovim;
  theme = systemArgs.theme;
in {
  options.programs.configured.neovim = {
    enable = mkEnableOption "Neo VIM";
  };
  config = mkIf cfg.enable {
    home.file."./.config/nvim/" = {
      source = ./nvim;
      recursive = true;
    };
    programs.neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;
      vimAlias = true;
      defaultEditor = true;
      viAlias = true;
      coc.enable = false;
      extraPackages = import ./nvim-programs.nix {inherit pkgs osConfig systemArgs lib;};
      withNodeJs = true;
      extraWrapperArgs = [
        "--suffix"
        "PRIMARY_COLOR"
        ":"
        "${theme.secondaryColor.hex}"
      ];
    };
  };
}
