{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.lazygit;
in {
  options.programs.configured.lazygit = {
    enable = mkEnableOption "TUI Git Client";
  };
  config = mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      settings = {
        gui = {
          scrollHeight = 4;
        };
      };
    };
  };
}
