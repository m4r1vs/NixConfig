{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.antigravity-cli;
in {
  options.programs.configured.antigravity-cli = {
    enable = mkEnableOption "Antigravity CLI - vibecoding assistant";
  };
  config = mkIf cfg.enable {
    programs.antigravity-cli = {
      enable = true;
      enableMcpIntegration = true;
    };
  };
}
