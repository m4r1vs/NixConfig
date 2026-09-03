{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.mcp;
in {
  options.programs.configured.mcp = {
    enable = mkEnableOption "Configuration of Model Context Protocol servers";
  };
  config = mkIf cfg.enable {
    programs.mcp = {
      enable = true;
      servers = {
        nixos = {
          command = "nix";
          enabled = true;
          args = [
            "run"
            "github:utensils/mcp-nixos"
            "--"
          ];
        };
        linear = {
          url = "https://mcp.linear.app/mcp";
        };
      };
    };
  };
}
