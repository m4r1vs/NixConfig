{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.i3;
in {
  options.configured.i3 = {
    enable = mkEnableOption "Enable i3 tiling window manager as desktop environment";
    scaling = mkOption {
      type = types.number;
      default = 1;
      description = "Display scaling factor of the X session, for HiDPI screens.";
    };
  };
  config = mkIf cfg.enable {
    environment = {
      pathsToLink = ["/libexec"];
      systemPackages = with pkgs; [
        lxappearance
        xrandr
        xclip
      ];
      variables = {
        GDK_SCALE = toString (builtins.floor cfg.scaling);
        GDK_DPI_SCALE = toString (cfg.scaling / (builtins.floor cfg.scaling));
        _JAVA_OPTIONS = "-Dsun.java2d.uiScale=${toString cfg.scaling}";
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        XCURSOR_SIZE = toString (builtins.floor (20 * cfg.scaling));
      };
    };
    security.pam.services = {
      greetd.enableGnomeKeyring = true;
    };
    services = {
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd startx";
          };
        };
      };
      xserver = {
        dpi = builtins.floor (96 * cfg.scaling);
        upscaleDefaultCursor = true;
        enable = true;
        xkb = {
          layout = "us";
          options = "caps:escape";
        };
        desktopManager = {
          xterm.enable = false;
        };
        displayManager = {
          startx = {
            enable = true;
            generateScript = true;
          };
        };
        windowManager.i3 = {
          enable = true;
          extraPackages = with pkgs; [
            i3lock
          ];
        };
      };
    };
  };
}
