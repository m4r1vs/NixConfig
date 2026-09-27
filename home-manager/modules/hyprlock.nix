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
  inherit (systemArgs) theme;

  scale = val: builtins.floor (val * cfg.scaling);

  # hyprlock runs every cmd[] child synchronously and blocks its own exit until
  # they all finish - a hanging command keeps the dismissed lock screen alive.
  capped = cmd: "${pkgs.coreutils}/bin/timeout -k 1 4 ${cmd}";

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
    # Recomputes the media labels only when a player changes (instead of every
    # label running playerctl, identify and bc every 4s) and pokes hyprlock
    # with SIGUSR2 so the force-updatable (:1) labels refresh immediately.
    systemd.user.services.hyprlock-mpris-cache = {
      Unit = {
        Description = "Cache MPRIS metadata for the hyprlock media labels";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = pkgs.writeShellScript "hyprlock-mpris-cache" ''
          DIR="''${XDG_RUNTIME_DIR:-/tmp}/hyprlock-mpris"
          mkdir -p -m 700 "$DIR"

          update() {
            ${scripts.mpris-hyprlock} --write-cache "$DIR"
            # SIGUSR2 = refresh labels (SIGUSR1 would unlock!). hyprlock only
            # installs its handler after connecting to Wayland; until then
            # SIGUSR2 kills it, which ends the autologin session. So only
            # signal instances whose SigCgt mask has SIGUSR2 (bit 11) set; a
            # fresh hyprlock reads the cache on its own anyway.
            for pid in $(${pkgs.procps}/bin/pgrep -x hyprlock); do
              caught=$(${pkgs.gawk}/bin/awk '/^SigCgt:/ {print $2}' "/proc/$pid/status" 2>/dev/null) && [ -n "$caught" ] || continue
              if (( (0x$caught >> 11) & 1 )); then
                kill -USR2 "$pid" 2>/dev/null || true
              fi
            done
          }

          update
          while read -r _; do
            # Players emit bursts of changes; update once per burst
            while read -r -t 0.15 _; do :; done
            update
          done < <(${pkgs.playerctl}/bin/playerctl -a --follow metadata --format '{{playerName}} {{status}} {{title}} {{mpris:artUrl}}')
          exit 1 # playerctl died, let systemd restart us
        '';
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          grace = 0;
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
            path = "${config.home.homeDirectory}/.active_wallpaper.jpg";
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
            text = "cmd[update:2000] ${capped scripts.battery-status}";
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
            text = "cmd[update:4000:1] ${capped "${scripts.mpris-hyprlock} --read title"}";
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
            text = "cmd[update:4000:1] ${capped "${scripts.mpris-hyprlock} --read length"}";
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
            text = "cmd[update:4000:1] ${capped "${scripts.mpris-hyprlock} --read source"}";
            color = "rgba(${theme.backgroundColorLightRGB}, 0.32)";
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
            text = "cmd[update:4000:1] ${capped "${scripts.mpris-hyprlock} --read artist"}";
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
            text = "cmd[update:3600000] ${capped scripts.weather-status}";
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
            check_color = "rgba(${theme.backgroundColorLightRGB}, 0.46)";
            inner_color = "rgba(0,0,0,0)";
            fail_color = "rgba(${theme.backgroundColorLightRGB}, 0.86)";
            outline_thickness = 0;
            font_family = "SFProDisplay Nerd Font SemiBold";
            fail_text = "Try Again";
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
            reload_cmd = capped "${scripts.mpris-hyprlock} --read arturl";
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
