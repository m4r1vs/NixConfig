{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.configured.kdeconnect;
in {
  options.services.configured.kdeconnect = {
    enable = mkEnableOption "Sync Phone with PC";
  };
  config = mkIf cfg.enable {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
