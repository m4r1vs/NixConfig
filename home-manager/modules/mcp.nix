{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.mcp;
  inherit (cfg) gitlab slack;

  slackReadonlyTools = [
    "channels_list"
    "channels_me"
    "conversations_history"
    "conversations_replies"
    "conversations_search_messages"
    "conversations_unreads"
    "users_search"
    "usergroups_list"
    "usergroups_me"
    "saved_list"
    "attachment_get_data"
  ];
  slackModifyTools =
    slackReadonlyTools
    ++ [
      "conversations_add_message"
      "reactions_add"
      "reactions_remove"
      "conversations_mark"
      "saved_update"
      "saved_clear_completed"
    ];

  slackAuthEnv =
    if slack.authMode == "xoxc"
    then {
      SLACK_MCP_XOXC_TOKEN.file = "${slack.tokenDir}/xoxc";
      SLACK_MCP_XOXD_TOKEN.file = "${slack.tokenDir}/xoxd";
    }
    else if slack.authMode == "xoxp"
    then {
      SLACK_MCP_XOXP_TOKEN.file = "${slack.tokenDir}/xoxp";
    }
    else {
      SLACK_MCP_XOXB_TOKEN.file = "${slack.tokenDir}/xoxb";
    };

  slackToolEnv =
    if slack.permissionMode == "readonly"
    then {
      SLACK_MCP_ENABLED_TOOLS = concatStringsSep "," slackReadonlyTools;
    }
    else if slack.permissionMode == "modify"
    then {
      SLACK_MCP_ENABLED_TOOLS = concatStringsSep "," slackModifyTools;
      SLACK_MCP_ADD_MESSAGE_TOOL = "true";
      SLACK_MCP_REACTION_TOOL = "true";
    }
    else {
      SLACK_MCP_ADD_MESSAGE_TOOL = "true";
      SLACK_MCP_REACTION_TOOL = "true";
      SLACK_MCP_ATTACHMENT_TOOL = "true";
    };
in {
  options.programs.configured.mcp = {
    enable = mkEnableOption "Configuration of Model Context Protocol servers";

    gitlab = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to expose the GitLab MCP server (OAuth2 authenticated).";
      };

      apiUrl = mkOption {
        type = types.str;
        default = "https://gitlab.tools.meetovo.dev/api/v4";
        example = "https://gitlab.example.com/api/v4";
        description = ''
          GitLab API v4 endpoint. The OAuth endpoints are derived from it by
          stripping the `/api/v4` suffix.
        '';
      };

      permissionMode = mkOption {
        type = types.enum ["readonly" "modify" "full"];
        default = "modify";
        description = "Which subset of the GitLab MCP tools is exposed.";
      };

      clientId = mkOption {
        type = types.str;
        default = "4fa10a200cd268c5ef6be43a16f28a46c3dac7b0048b36930152a4b3e16c7cdf";
        description = ''
          Application ID of the GitLab OAuth application. Public
          (non-confidential) OAuth clients use PKCE, so this ID is not a secret.
        '';
      };

      redirectUri = mkOption {
        type = types.str;
        default = "http://127.0.0.1:8888/callback";
        description = ''
          Redirect URI registered with the GitLab OAuth application. The server
          listens on its port while completing the browser flow.
        '';
      };

      tokenPath = mkOption {
        type = types.str;
        default = "${config.xdg.stateHome}/gitlab-mcp/token.json";
        description = ''
          Where the OAuth access/refresh token is cached (mode 0600). The
          server does not create missing parent directories, so this module
          does it during activation.
        '';
      };
    };

    slack = {
      enable = mkOption {
        type = types.bool;
        default = systemArgs.useWorkProfileByDefault;
        description = ''
          Whether to expose the Slack MCP server (korotovsky/slack-mcp-server).
          Defaults to `systemArgs.useWorkProfileByDefault` so non-work and
          downstream hosts do not fail startup when no token files are present.
        '';
      };

      authMode = mkOption {
        type = types.enum ["xoxc" "xoxp" "xoxb"];
        default = "xoxc";
        description = ''
          Slack credential mode:
          - `xoxc`: browser session token (`xoxc`) + `d` cookie (`xoxd`); requires no Slack app install or workspace admin approval.
          - `xoxp`: User OAuth token (`xoxp`) from a Slack app.
          - `xoxb`: Bot token (`xoxb`) from a Slack app (no search or DMs).
        '';
      };

      tokenDir = mkOption {
        type = types.str;
        default = "${config.xdg.stateHome}/slack-mcp";
        description = ''
          Directory (mode 0700) containing mode 0600 token file(s) read at
          startup by the Home Manager env-file wrapper (`xoxc` + `xoxd`,
          `xoxp`, or `xoxb` depending on `authMode`).
        '';
      };

      permissionMode = mkOption {
        type = types.enum ["readonly" "modify" "full"];
        default = "readonly";
        description = ''
          Which subset of Slack MCP tools is exposed:
          - `readonly`: read/search/list/unreads/saved_list/attachments only.
          - `modify`: adds posting messages, reactions, mark-as-read, and saved items updates.
          - `full`: all tools including channel join/leave and usergroup management.
        '';
      };

      enterpriseTls = mkOption {
        type = types.bool;
        default = false;
        description = "Enable custom browser-mimicking TLS handshake (`SLACK_MCP_CUSTOM_TLS`) for strict Enterprise Slack workspaces.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.activation =
      optionalAttrs gitlab.enable {
        gitlabMcpTokenDir = hm.dag.entryAfter ["writeBoundary"] ''
          run mkdir -p ${escapeShellArg (dirOf gitlab.tokenPath)}
        '';
      }
      // optionalAttrs slack.enable {
        slackMcpTokenDir = hm.dag.entryAfter ["writeBoundary"] ''
          run install -d -m 700 ${escapeShellArg slack.tokenDir}
        '';
      };

    programs.mcp = {
      enable = true;
      servers =
        {
          nixos = {
            # Pinned via the unstable overlay instead of `nix run github:...`,
            # which fetched and built it on every agent start
            command = getExe pkgs.mcp-nixos;
            enabled = true;
          };
          linear = {
            url = "https://mcp.linear.app/mcp";
          };
        }
        // optionalAttrs gitlab.enable {
          gitlab = {
            command = getExe pkgs.gitlab-mcp;
            enabled = true;
            env = {
              GITLAB_API_URL = gitlab.apiUrl;
              GITLAB_PERMISSION_MODE = gitlab.permissionMode;
              GITLAB_USE_OAUTH = "true";
              GITLAB_OAUTH_CLIENT_ID = gitlab.clientId;
              GITLAB_OAUTH_REDIRECT_URI = gitlab.redirectUri;
              GITLAB_OAUTH_TOKEN_PATH = gitlab.tokenPath;
            };
          };
        }
        // optionalAttrs slack.enable {
          slack = {
            command = getExe pkgs.slack-mcp-server;
            args = ["--transport" "stdio"];
            enabled = true;
            env =
              slackAuthEnv
              // slackToolEnv
              // optionalAttrs slack.enterpriseTls {
                SLACK_MCP_CUSTOM_TLS = "true";
              };
          };
        };
    };
  };
}
