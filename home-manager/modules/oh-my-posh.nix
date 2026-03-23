{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.oh-my-posh;
in {
  options.programs.configured.oh-my-posh = {
    enable = mkEnableOption "Nice shell prompt";
  };
  config = mkIf cfg.enable {
    programs.oh-my-posh = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        transient_prompt = {
          foreground = "green";
          newline = false;
          template = "❯ ";
        };
        blocks = [
          {
            type = "prompt";
            alignment = "left";
            newline = true;
            segments = [
              {
                type = "path";
                style = "plain";
                foreground = "blue";
                template = "<b>{{ .Path }}</b> ";
                options = {
                  style = "full";
                };
              }
              {
                type = "git";
                style = "plain";
                foreground = "green";
                template = "{{ .UpstreamIcon }} <b><i>{{ .HEAD }}</i></b>{{if .BranchStatus }} {{ .BranchStatus }}{{ end }} {{ if .Working.Changed }} {{ end }}{{ if .Staging.Changed }} {{ end }}{{ if gt .StashCount 0 }} {{ end }}";
                options = {
                  fetch_status = true;
                  fetch_push_status = true;
                  fetch_upstream_icon = true;
                  source = "cli";
                  branch_icon = "";
                  branch_identical_icon = "";
                };
              }
              {
                type = "project";
                style = "plain";
                foreground = "magenta";
                template = " {{ if .Error }}{{ .Error }}{{ else }}{{ if .Version }} {{.Version}}{{ end }}{{ end }} ";
              }
              {
                type = "nix-shell";
                style = "plain";
                foreground = "cyan";
                template = "{{ if contains .Type \"impure\" }} 󱄅 direnv {{ else if contains .Type \"pure\" }} 󱄅 pure {{ end }}";
              }
              # {
              #   type = "firebase";
              #   style = "powerline";
              #   powerline_symbol = "";
              #   foreground = "#ffffff";
              #   background = "#FFA000";
              #   template = " 󰥧 {{ .Project }}";
              # }
              # {
              #   type = "kubectl";
              #   style = "powerline";
              #   powerline_symbol = "";
              #   foreground = "#000000";
              #   background = "#ebcc34";
              #   template = " 󱃾 {{.Context}}{{if .Namespace}} :: {{.Namespace}}{{end}} ";
              #   options = {
              #     context_aliases = {
              #       "arn:aws:eks:eu-west-1:1234567890:cluster/posh" = "posh";
              #     };
              #     cluster_aliases = {
              #       "arn:aws:eks:eu-west-1:1234567890:cluster/posh" = "posh-cluster";
              #     };
              #   };
              # }
              # {
              #   type = "aws";
              #   style = "powerline";
              #   powerline_symbol = "";
              #   foreground = "#ffffff";
              #   background = "#FFA400";
              #   template = "  {{.Profile}}{{if .Region}}@{{.Region}}{{end}}";
              # }
              # {
              #   type = "gcp";
              #   style = "powerline";
              #   powerline_symbol = "";
              #   foreground = "#ffffff";
              #   background = "#47888d";
              #   template = " 󱇶 {{.Project}} :: {{.Account}} ";
              # }
            ];
          }
          {
            type = "prompt";
            alignment = "right";
            segments = [
              {
                type = "argocd";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Name }}:{{ .User }}@{{ .Server }} ";
              }
              {
                type = "bun";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "docker";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Context }} ";
              }
              {
                type = "helm";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Version }} ";
              }
              {
                type = "npm";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "svelte";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "react";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "terraform";
                style = "plain";
                foreground = "yellow";
                template = "  {{.WorkspaceName}}";
              }
              {
                type = "go";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "dart";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "java";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }}";
              }
              {
                type = "lua";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "node";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "python";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "rust";
                style = "plain";
                foreground = "yellow";
                template = "  {{ .Full }} ";
              }
              {
                type = "os";
                style = "plain";
                foreground = "default";
                template = "  {{.Icon}} ";
              }
            ];
          }
          {
            type = "prompt";
            alignment = "left";
            newline = true;
            segments = [
              {
                type = "text";
                style = "plain";
                foreground = "green";
                template = "❯ ";
              }
            ];
          }
        ];

        shell_integration = true;
        enable_cursor_positioning = true;
        async = true;
        streaming = 60;
        version = 4;
      };
    };
  };
}
