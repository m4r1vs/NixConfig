{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.neovim;
in {
  options.programs.configured.neovim = {
    enable = mkEnableOption "Neo VIM";
    profile = mkOption {
      type = types.enum ["base" "full"];
      default = "full";
      description = "base: minimal toolchain for servers/ISOs, full: every LSP and language provider.";
    };
  };
  config = mkIf cfg.enable {
    xdg.configFile."nvim" = {
      source = ./nvim;
      recursive = true;
    };
    programs.neovim = {
      enable = true;
      # Our init.lua replaces the generated one, so load HM's Lua (provider
      # paths etc.) via --cmd instead of writing it to init.lua
      sideloadInitLua = true;
      package = pkgs.neovim-unwrapped;
      vimAlias = true;
      defaultEditor = true;
      viAlias = true;
      coc.enable = false;
      extraPackages = (import ./nvim-programs.nix {inherit pkgs;}).${cfg.profile};
      withNodeJs = cfg.profile == "full";
      withRuby = cfg.profile == "full";
      withPython3 = cfg.profile == "full";
    };
  };
}
