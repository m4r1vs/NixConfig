{
  config,
  lib,
  pkgs,
  scripts,
  systemArgs,
  osConfig,
  ...
}:
with lib; let
  cfg = config.programs.configured.hyprlock;
  theme = systemArgs.theme;

  scale = val: builtins.floor (val * cfg.scaling);
  scaleStr = valStr: let
    parts = lib.splitString "," (toString valStr);
    scaled = map (p: toString (scale (lib.toInt (lib.trim p)))) parts;
  in
    lib.concatStringsSep ", " scaled;
in {
  options.programs.configured.hyprlock = {
    enable = mkEnableOption "Enable custom hyprlock configuration";
    scaling = mkOption {
      type = types.float;
      default = 1.0;
      description = "Scaling factor for hyprlock elements";
    };
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
            enabled = osConfig.services.fprintd.enable;
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
            path = "/home/${systemArgs.username}/.active_wallpaper.jpg";
          }
        ];
        label = [
          {
            text = "$TIME";
            font_family = "Clock BoldSerif";
            color = "rgba(${theme.backgroundColorLightRGB},0.86)";
            font_size = scale 74;
            text_align = "center";
            halign = "center";
            valign = "center";
            position = scaleStr "0, 228";
            shadow_size = 4;
            shadow_passes = 4;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.5;
          }
          {
            text = "cmd[update:2000] ${scripts.battery-status}";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            font_size = scale 12;
            font_family = "SFProDisplay Nerd Font SemiBold";
            position = scaleStr "-24, -24";
            text_align = "right";
            halign = "right";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.9;
          }
          {
            text = "cmd[update:4000] ${scripts.mpris-hyprlock} --title";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            font_size = scale 12;
            font_family = "SFProDisplay Nerd Font Bold";
            position = scaleStr "118, -24";
            text_align = "left";
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.9;
          }
          {
            text = "cmd[update:4000] ${scripts.mpris-hyprlock} --length";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.56)";
            font_size = scale 12;
            font_family = "SFProDisplay Nerd Font SemiBold";
            position = scaleStr "118, -80";
            text_align = "left";
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.9;
          }
          {
            text = "cmd[update:4000] ${scripts.mpris-hyprlock} --source";
            color = "rgba(${theme.secondaryColor.rgb}, 0.32)";
            font_size = scale 64;
            font_family = "SFProDisplay Nerd Font SemiBold";
            position = scaleStr "0, -10";
            text_align = "left";
            zindex = 1;
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.9;
          }
          {
            text = "cmd[update:4000] ${scripts.mpris-hyprlock} --artist";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.56)";
            font_family = "SFProDisplay Nerd Font SemiBold";
            font_size = scale 12;
            position = scaleStr "118, -46";
            text_align = "left";
            halign = "left";
            valign = "top";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.9;
          }
          {
            text = "cmd[update:60000] echo \"$(date +\"%a, %b %d\")  $(${pkgs.wttrbar}/bin/wttrbar --nerd --custom-indicator \"{ICON} {temp_C}°\" | ${pkgs.jq}/bin/jq .text -r)\"";
            font_family = "SFProDisplay Nerd Font SemiBold";
            color = "rgba(${theme.backgroundColorLightRGB},0.72)";
            font_size = scale 15;
            text_align = "center";
            halign = "center";
            valign = "center";
            position = scaleStr "0, 152";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 1;
          }
          {
            text = " ${systemArgs.username}";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            font_size = scale 12;
            font_family = "SFProDisplay Nerd Font SemiBold";
            position = scaleStr "24, 24";
            text_align = "left";
            halign = "left";
            valign = "bottom";
            shadow_size = 2;
            shadow_passes = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.9;
          }
        ];
        input-field = [
          {
            size = scaleStr "400, 72";
            position = scaleStr "0, 172";
            halign = "center";
            valign = "bottom";
            monitor = "";
            dots_center = true;
            dots_size = 0.20;
            fade_on_empty = false;
            font_color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            rounding = 0;
            check_color = "rgba(${theme.primaryColor.rgb},0.67)";
            inner_color = "rgba(0,0,0,0)";
            fail_color = "rgba(175,48,41,0.76)";
            outline_thickness = 0;
            font_family = "SFProDisplay Nerd Font SemiBold";
            fail_text = " 󰌾 ";
            placeholder_text = " 󰌾 ";
            swap_font_color = true;
          }
        ];
        image = [
          {
            size = scale 82;
            rounding = 5;
            border_size = 0;
            rotate = 0;
            reload_time = 4;
            reload_cmd = "${scripts.mpris-hyprlock} --arturl";
            position = scaleStr "24, -21";
            halign = "left";
            valign = "top";
            zindex = 2;
            shadow_size = 2;
            shadow_passes = 4;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 0.3;
          }
        ];
      };
    };
  };
}
