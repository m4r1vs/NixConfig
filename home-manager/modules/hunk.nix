{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.programs.configured.hunk;
in {
  imports = [
    inputs.hunk.homeManagerModules.default
  ];

  options.programs.configured.hunk = {
    enable = mkEnableOption "Terminal diff viewer with great AI agent support.";
  };
  config = mkIf cfg.enable {
    programs.hunk = {
      enable = true;
      settings = {
        theme = "auto";
        mode = "auto";
        line_numbers = true;
      };
      enableGitIntegration = true;
    };
  };
}
