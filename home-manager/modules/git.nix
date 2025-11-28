{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.git;
  git = systemArgs.git;
in {
  options.programs.configured.git = {
    enable = mkEnableOption "The version controlling software.";
  };
  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = git.name;
          email = git.email;
        };
        pull.rebase = true;
      };
    };
  };
}
