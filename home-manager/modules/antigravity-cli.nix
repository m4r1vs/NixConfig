{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.programs.configured.antigravity-cli;
in {
  options.programs.configured.antigravity-cli = {
    enable = mkEnableOption "Antigravity CLI - vibecoding assistant";
  };
  config = mkIf cfg.enable {
    # agy rewrites settings.json as a regular file on UI changes (e.g. model switch),
    # which otherwise collides with an existing settings.json..hm-backup on activation
    home.file.".gemini/antigravity-cli/settings.json".force = true;

    programs.antigravity-cli = {
      enable = true;
      enableMcpIntegration = true;
      skills = {
        # Read from the source tree: referencing the built package forces a
        # bun2nix IFD, which breaks evaluating Linux hosts from darwin.
        hunk = "${inputs.hunk}/packages/hunk/skills/hunk-review/SKILL.md";
      };
      permissions = {
        ask = [
          "command(npm test)"
          "command(npm run test:cov)"
          "command(git push --force)"
        ];
      };
      settings = {
        "$schema" = "https://antigravity.google/schemas/v1/settings.json";
        agentMode = "auto";
        artifactReviewPolicy = "always-proceed";
        colorScheme = "terminal";
        editorMode = "vim";
        enableTerminalSandbox = true;
        model = "Gemini 4 Neon (High)";
        notifications = true;
        showFeedbackSurvey = false;
        showTips = false;
        toolPermission = "proceed-in-sandbox";
        vimInsertFirst = true;
      };
    };
  };
}
