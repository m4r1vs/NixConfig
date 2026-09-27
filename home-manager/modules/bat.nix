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
      # Follow the system dark/light mode (also used by MANPAGER and help)
      config = {
        theme = "auto:system";
        theme-dark = "default";
        theme-light = "GitHub";
      };
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
