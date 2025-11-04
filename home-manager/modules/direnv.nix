{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.direnv;
in {
  options.programs.configured.direnv = {
    enable = mkEnableOption "Load project environments automagically.";
  };
  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      mise.enable = false;
      silent = true;
    };
  };
}
