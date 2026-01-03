{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.brave;
in {
  options.programs.configured.brave = {
    enable = mkEnableOption "Enable the Brave web browser.";
  };
  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      commandLineArgs = [
        "--ozone-platform-hint=auto"
        "--enable-features=TouchpadOverscrollHistoryNavigation"
      ];
    };
  };
}
