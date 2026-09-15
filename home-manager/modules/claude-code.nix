{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.claude-code;
in {
  options.programs.configured.claude-code = {
    enable = mkEnableOption "Claude Code - vibecoding assistant";
  };
  config = mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;
      skills = {
        hunk = "${inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.hunk}/skills/hunk-review/SKILL.md";
      };
      settings = {
        advisorModel = "fable";
        editorMode = "vim";
        enableArtifact = false;
        model = "opus[1m]";
        permissions.defaultMode = "auto";
        preferredNotifChannel = "terminal_bell";
        skipWorkflowUsageWarning = true;
        terminalProgressBarEnabled = true;
        theme = "auto";
        useAutoModeDuringPlan = true;
      };
    };
  };
}
