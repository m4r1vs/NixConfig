{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.opencode;
in {
  options.programs.configured.opencode = {
    enable = mkEnableOption "Multi-provider AI coding CLI";
  };
  config = mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      settings = {
        theme = "system";
        autoupdate = true;
      };
    };
  };
}
