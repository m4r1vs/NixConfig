{
  lib,
  config,
  pkgs,
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
    # which otherwise collides with an existing settings.json..hm-backup on activation.
    # TODO(home-manager 26.11): replace with `programs.antigravity-cli.mutableSettings = true;` (HM 0e11b7bc).
    home.file.".gemini/antigravity-cli/settings.json".force = true;

    programs.antigravity-cli = {
      enable = true;
      # TODO(home-manager 26.11): re-enable `enableMcpIntegration = true;` and drop `mcpServers`
      # below once on release-26.11 (fixed upstream in HM a813a041 / 5bcff431). On release-26.05,
      # `enableMcpIntegration` renames `url` -> `serverUrl` inside `lib.hm.mcp.transformMcpServer`,
      # which immediately strips `serverUrl` and breaks remote HTTP MCP servers (like Linear).
      enableMcpIntegration = false;
      mcpServers = mkIf config.programs.mcp.enable (
        mapAttrs (
          name: server:
            lib.hm.mcp.transformMcpServer {
              inherit server;
              extraTransforms = [
                lib.hm.mcp.addType
                (lib.hm.mcp.wrapEnvFilesCommand {inherit pkgs name;})
              ];
            }
        )
        config.programs.mcp.servers
      );
      skills = {
        # Read from the source tree: referencing the built package forces a
        # bun2nix IFD, which breaks evaluating Linux hosts from darwin.
        hunk = "${inputs.hunk}/packages/hunk/skills/hunk-review/SKILL.md";
      };
      permissions = {
        allow =
          [
            "mcp(gitlab/*)"
            "mcp(nixos/*)"
          ]
          ++ optionals (config.programs.configured.mcp.enable && config.programs.configured.mcp.slack.enable) [
            "mcp(slack/*)"
          ]
          ++ optionals (config.programs.configured.mcp.enable && config.programs.configured.mcp.googleWorkspace.enable) [
            "mcp(google-workspace/*)"
          ]
          ++ optionals (config.programs.configured.mcp.enable && config.programs.configured.mcp.context7.enable) [
            "mcp(context7/*)"
          ];
        ask = [
          "command(npm test)"
          "command(npm run test:cov)"
          "command(git push --force)"
        ];
      };
      settings = {
        "$schema" = "https://antigravity.google/schemas/v1/settings.json";
        artifactReviewPolicy = "always-proceed";
        editorMode = "vim";
        # agy's terminal sandbox fails to start on NixOS (connection reset / missing bash in sandbox PATH),
        # adding latency on every shell command without providing containment.
        enableTerminalSandbox = false;
        model = "Gemini 4 Neon (High)";
        notifications = true;
        showFeedbackSurvey = false;
        showTips = false;
        # Intentional: run tools/commands without prompts unless matched by permissions.ask / permissions.deny.
        toolPermission = "always-proceed";
        vimInsertFirst = true;
      };
    };
  };
}
