{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.configured.hushlogin;
in {
  options.configured.hushlogin = {
    enable = mkEnableOption "Do not show the login message on darwin";
  };
  config = mkIf cfg.enable {
    home.file."./.hushlogin".text = "";
  };
}
