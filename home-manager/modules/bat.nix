{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.bat;
in {
  options.programs.configured.bat = {
    enable = mkEnableOption "Enable bat as a cat alternative and manpage viewer";
  };
  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batpipe
        prettybat
        batman
        batdiff
        batgrep
      ];
    };
  };
}
