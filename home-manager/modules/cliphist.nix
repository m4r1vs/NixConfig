{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.cliphist;
in {
  options.services.configured.cliphist = {
    enable = mkEnableOption "Wayland clipboard manager.";
  };
  config = mkIf cfg.enable {
    services.cliphist = {
      enable = true;
      package = pkgs.cliphist;
      allowImages = true;
    };
  };
}
