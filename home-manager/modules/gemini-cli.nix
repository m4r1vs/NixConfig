{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.gemini-cli;
in {
  options.programs.configured.gemini-cli = {
    enable = mkEnableOption "Gemini CLI - vibecoding assistant";
  };
  config = mkIf cfg.enable {
    home.packages = [pkgs.gemini-cli];
    home.file.".gemini/settings.json".text = builtins.toJSON {
      mcpServers = {
        nixos = {
          command = "nix";
          args = [
            "run"
            "github:utensils/mcp-nixos"
            "--"
          ];
          trust = true;
        };
      };
      security = {
        auth = {
          selectedType = "oauth-personal";
        };
        environmentVariableRedaction = {
          enabled = false;
        };
        enablePermanentToolApproval = true;
        autoAddToPolicyByDefault = true;
      };
      ui = {
        theme = "Default Light";
        autoThemeSwitching = true;
        terminalBackgroundPollingInterval = 4;
        hideBanner = true;
        useBackgroundColor = true;
        inlineThinkingMode = "off";
        hideTips = true;
        showShortcutsHint = false;
        footer = {
          hideContextPercentage = false;
        };
        hideFooter = true;
        showMemoryUsage = true;
        showCitations = true;
        showModelInfoInChat = true;
        loadingPhrases = "all";
        useAlternateBuffer = true;
        showCompatibilityWarnings = false;
      };
      general = {
        vimMode = true;
        previewFeatures = true;
        preferredEditor = "neovim";
        sessionRetention = {
          warningAcknowledged = true;
          enabled = true;
          maxAge = "30d";
        };
        enableNotifications = true;
        plan = {
          modelRouting = true;
          enabled = true;
        };
      };
      context = {
        fileFiltering = {
          respectGeminiIgnore = true;
          enableRecursiveFileSearch = true;
          respectGitIgnore = false;
        };
      };
      output = {
        format = "text";
      };
      tools = {
        shell = {
          showColor = true;
        };
        disableLLMCorrection = false;
      };
      experimental = {
        modelSteering = true;
        directWebFetch = true;
        memoryManager = true;
        topicUpdateNarration = true;
      };
      ide = {
        enabled = false;
      };
      agents = {
        overrides = {};
      };
    };
  };
}
