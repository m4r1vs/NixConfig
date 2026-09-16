{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.git;
  inherit (systemArgs) git;
in {
  options.programs.configured.git = {
    enable = mkEnableOption "The version controlling software.";
  };
  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          inherit (git) name;
          inherit (git) email;
        };
        pull.rebase = true;
      };
    };
  };
}
