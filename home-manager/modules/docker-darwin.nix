{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.docker-darwin;
in {
  options.programs.configured.docker-darwin = {
    enable = mkEnableOption "Enable Docker on Darwin";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      docker
      docker-credential-helpers
      docker-compose
      colima
    ];
    programs.zsh.initContent = ''
      eval "$(${getExe pkgs.colima} completion zsh)"
    '';
  };
}
