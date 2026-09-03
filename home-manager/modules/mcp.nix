{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.mcp;
  gitlab = cfg.gitlab;
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
        default = "https://gitlab.com/api/v4";
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
        default = "f6f9928e1c336f8c2b57e83fd033ff2213e6d3f4414d3648c8456ed9bb7cfaf5";
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
  };

  config = mkIf cfg.enable {
    home.activation = mkIf gitlab.enable {
      gitlabMcpTokenDir = hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p ${escapeShellArg (dirOf gitlab.tokenPath)}
      '';
    };

    programs.mcp = {
      enable = true;
      servers =
        {
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
        };
    };
  };
}
