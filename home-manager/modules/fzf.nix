{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.fzf;
in {
  options.programs.configured.fzf = {
    enable = mkEnableOption "Quick fuzzy finder.";
  };
  config = mkIf cfg.enable {
    programs.fzf = {
      enable = true;
      enableZshIntegration = false;
      defaultOptions = [
        "--bind ctrl-e:preview-down,ctrl-y:preview-up,alt-k:up,alt-j:down"
        "--preview-window=right,65%"
      ];
    };
  };
}
