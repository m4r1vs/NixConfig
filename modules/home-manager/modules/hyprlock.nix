{
  config,
  lib,
  pkgs,
  scripts,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.hyprlock;
  theme = systemArgs.theme;
in {
  options.programs.configured.hyprlock = {
    enable = mkEnableOption "Enable custom hyprlock configuration";
  };

  config = mkIf cfg.enable {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          grace = 5;
          text_trim = false;
          hide_cursor = true;
        };
        auth = {
          fingerprint = {
            enabled = true;
          };
          pam = {
            enabled = true;
          };
        };
        animations = {
          enabled = true;
          bezier = [
            "fade, 0.05, 0.9, 0.1, 1"
          ];
          animation = [
            "fade, 1, 5, fade"
            "inputFieldColors, 1, 3, fade"
          ];
        };
        background = [
          {
            path = "${builtins.path {path = ../wallpaper/Sunset_Tree.jpg;}}";
          }
        ];
        label = [
          {
            text = "$TIME";
            font_family = "Clock BoldSerif";
            color = "rgba(${theme.backgroundColorLightRGB},0.86)";
            font_size = 74;
            text_align = "center";
            halign = "center";
            valign = "center";
            position = "0, 228";
            shadow_size = 4;
            shadow_passes = 4;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 2;
          }
          {
            text = " Plugged In"; # Consider making this dynamic based on battery status
            color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            font_size = 12;
            font_family = "JetBrainsMono NF SemiBold";
            position = "-24, -24";
            text_align = "right";
            halign = "right";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 3.2;
          }
          {
            text = "cmd[update:1000] ${scripts.mpris-hyprlock} --title";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            font_size = 12;
            font_family = "JetBrainsMono NF SemiBold";
            position = "118, -24";
            text_align = "left";
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 2;
          }
          {
            text = "cmd[update:1000] ${scripts.mpris-hyprlock} --length";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.56)";
            font_size = 12;
            font_family = "JetBrainsMono NF SemiBold";
            position = "118, -80";
            text_align = "left";
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 2;
          }
          {
            text = "cmd[update:1000] ${scripts.mpris-hyprlock} --source";
            color = "rgba(${theme.secondaryColor.rgb}, 0.32)";
            font_size = 64;
            font_family = "JetBrainsMono Nerd Font";
            position = "-24, -6";
            text_align = "left";
            zindex = 1;
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 2;
          }
          {
            text = "cmd[update:1000] ${scripts.mpris-hyprlock} --artist";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.56)";
            font_family = "JetBrainsMono Nerd Font";
            font_size = 12;
            position = "118, -46";
            text_align = "left";
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 2;
          }
          {
            text = "cmd[update:60000] echo \"$(date +\"%a, %b %d\")  $(${pkgs.wttrbar}/bin/wttrbar --nerd --custom-indicator \"{ICON} {temp_C}°\" | ${pkgs.jq}/bin/jq .text -r)\"";
            font_family = "JetBrainsMono NF Light";
            color = "rgba(${theme.backgroundColorLightRGB},0.72)";
            font_size = 15;
            text_align = "center";
            halign = "center";
            valign = "center";
            position = "0, 152";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 4;
          }
        ];
        input-field = [
          {
            size = "338, 42";
            position = "0, 38";
            halign = "center";
            valign = "center";
            monitor = "";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgba(255,255,255,0.76)";
            rounding = 0;
            check_color = "rgba(${theme.primaryColor.rgb},1)";
            inner_color = "rgba(0,0,0,0)";
            fail_color = "rgba(${theme.secondaryColor.rgb},1)";
            outline_thickness = 0;
            font_family = "JetBrainsMono Nerd Font";
            fail_text = "Keep Trying.";
            placeholder_text = "";
            swap_font_color = true;
          }
        ];
        image = [
          {
            size = 82;
            rounding = 5;
            border_size = 0;
            rotate = 0;
            reload_time = 2;
            reload_cmd = "${scripts.mpris-hyprlock} --arturl";
            position = "24, -21";
            halign = "left";
            valign = "top";
            zindex = 2;
            shadow_size = 2;
            shadow_passes = 4;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 1;
          }
        ];
      };
    };
  };
}
