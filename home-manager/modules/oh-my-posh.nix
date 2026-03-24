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
                type = "session";
                style = "plain";
                foreground = "yellow";
                template = "{{ if .SSHSession }}󰒍 <b><i>{{ .UserName }}@{{ .HostName }}</i></b> {{ end }}";
              }
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
                  git_icon = "";
                  upstream_icons = {
                    "git.informatik.uni-hamburg.de" = "";
                  };
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
                template = "{{ if contains .Type \"impure\" }} 󱄅 <i>devshell</i> {{ else if contains .Type \"pure\" }} 󱄅 <i>pure nix shell</i> {{ end }}";
              }
              {
                type = "status";
                style = "diamond";
                foreground = "white";
                background = "red";
                leading_diamond = "  ";
                trailing_diamond = "";
                template = "{{ if ne .Code 0 }} exited <b>{{ .Code }}</b> - <b>{{ reason .Code }}</b> {{ end }}";
              }
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
                type = "zig";
                style = "plain";
                foreground = "yellow";
                template = "  {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }} ";
              }
              # {
              #   type = "spotify";
              #   style = "plain";
              #   foreground = "green";
              #   include_folders = [
              #     (
              #       if isDarwin
              #       then "/Users/${systemArgs.username}"
              #       else "/home/${systemArgs.username}"
              #     )
              #   ];
              #   template = "{{ if eq .Status \"playing\" }} 󰓇 {{ .Artist }} - {{ .Track }}{{ end }}";
              # }
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
                template = "{{ if eq .Keymap \"vicmd\" }}❮ {{ else }}❯ {{ end }}";
              }
            ];
          }
        ];

        tooltips_action = "extend";
        tooltips = [
          {
            type = "executiontime";
            tips = [
              "t"
              "time"
            ];
            style = "diamond";
            foreground = "white";
            background = "#C15B00";
            leading_diamond = "  ";
            trailing_diamond = "";
            template = " ran for <b>{{ .FormattedMs }}</b> ";
            options = {
              threshold = 0;
              style = "round";
            };
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
