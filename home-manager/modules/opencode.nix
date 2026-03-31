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
    home.file."./.config/opencode/tui.json".text = builtins.toJSON {
      theme = "system";
      background = "none";
    };
    programs.opencode = {
      enable = true;
      settings = {
        autoupdate = false;
      };
    };
  };
}
