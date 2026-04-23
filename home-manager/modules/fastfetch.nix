{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.fastfetch;
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  options.programs.configured.fastfetch = {
    enable = mkEnableOption "Configure FastFetch system info fetcher";
  };
  config = mkIf cfg.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          type = "builtin";
          source =
            if isDarwin
            then "macos"
            else "NixOS";
          color = lib.mkIf (!isDarwin) {
            "1" = "green";
            "2" = "red";
          };
          padding = {
            top = 4;
            right = 6;
            left = 2;
          };
        };
        modules =
          [
            "break"
            {
              type = "custom";
              format = "{#90}┌─────────────────────────────Hardware─────────────────────────────┐{#}";
            }
            {
              type = "host";
              key = "󰟀 PC";
              keyColor = "green";
            }
            {
              type = "cpu";
              key = "├";
              showPeCoreCount = true;
              keyColor = "green";
            }
            {
              type = "gpu";
              key = "├";
              detectionMethod = "pci";
              keyColor = "green";
            }
            {
              type = "display";
              key = "├󱄄";
              keyColor = "green";
            }
            {
              type = "disk";
              key = "├󰋊";
              keyColor = "green";
            }
            {
              type = "memory";
              key = "├";
              keyColor = "green";
            }
            {
              type = "battery";
              key = "├󱊣";
              keyColor = "green";
            }
            {
              type = "swap";
              key = "├󰓡";
              keyColor = "green";
            }
            {
              type = "custom";
              format = "{#90}└──────────────────────────────────────────────────────────────────┘{#}";
            }
            "break"
            {
              type = "custom";
              format = "{#90}┌─────────────────────────────Software─────────────────────────────┐{#}";
            }
            {
              type = "os";
              key =
                if isDarwin
                then "󰀵 OS"
                else "󱄅 OS";
              keyColor = "blue";
            }
            {
              type = "command";
              key = "├󰘬";
              keyColor = "blue";
              text = ''branch=$(git -C ~/NixConfig branch --show-current);upstream=$(git -C ~/NixConfig remote get-url origin); echo "$branch at $upstream"'';
            }
          ]
          ++ lib.optionals (!isDarwin) [
            {
              type = "command";
              key = "├󰔫";
              keyColor = "blue";
              text = ''specialisation=$(cat /etc/nixos_active_specialisation || echo Default); echo "$specialisation specialisation"'';
            }
          ]
          ++ [
            {
              type = "kernel";
              key = "├";
              keyColor = "blue";
            }
            {
              type = "wm";
              key = "├";
              keyColor = "blue";
            }
            {
              type = "de";
              key = " DE";
              keyColor = "blue";
            }
            {
              type = "terminal";
              key = "├";
              keyColor = "blue";
            }
            {
              type = "shell";
              key = "├";
              keyColor = "blue";
            }
            {
              type = "packages";
              key = "├󰏖";
              keyColor = "blue";
            }
            {
              type = "wmtheme";
              key = "├󰉼";
              keyColor = "blue";
            }
            {
              type = "font";
              key = "├";
              keyColor = "blue";
            }
            {
              type = "cursor";
              key = "├󰇀";
              keyColor = "blue";
            }
            {
              type = "custom";
              key = "├󰸌";
              keyColor = "blue";
              format = "Flexoki {#30}●{#31}●{#32}●{#33}●{#34}●{#35}●{#36}●{#37}●";
            }
            {
              type = "custom";
              format = "{#90}└──────────────────────────────────────────────────────────────────┘{#}";
            }
            "break"
            {
              type = "custom";
              format = "{#90}┌───────────────────────Age / Uptime / Update──────────────────────┐{#}";
            }
            {
              type = "command";
              key = "󱦟 OS Age";
              keyColor = "magenta";
              text =
                if isDarwin
                then ''echo $(( ($(date +%s) - $(stat -f %B /)) / 86400 )) days''
                else ''echo $(( ($(date +%s) - $(stat -c %W /)) / 86400 )) days'';
            }
            {
              type = "uptime";
              key = "󱫐 Uptime";
              keyColor = "magenta";
            }
            {
              type = "command";
              key = " Update";
              keyColor = "magenta";
              text = let
                statCmd =
                  if isDarwin
                  then "stat -f %m"
                  else "stat -c %Y";
              in ''updated=$(d=$(( ( $(date +%s) - $(${statCmd} ~/NixConfig/flake.lock) ) / 86400 )); [ "$d" -gt 0 ] && echo "$d day(s) ago" || echo "$(( ( $(date +%s) - $(${statCmd} ~/NixConfig/flake.lock) ) / 3600 )) hour(s) ago"); echo "$updated"'';
            }
            {
              type = "custom";
              format = "{#90}└──────────────────────────────────────────────────────────────────┘{#}";
            }
            "break"
          ];
      };
    };
  };
}
