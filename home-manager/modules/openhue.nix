{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.openhue;
in {
  options.programs.configured.openhue = {
    enable = mkEnableOption "Philips Hue CLI (openhue) and Manage Lights Rofi menu";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.openhue-cli];
  };
}
