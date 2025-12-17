{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.i3;
in {
  options.configured.i3 = {
    enable = mkEnableOption "Enable i3 tiling window manager as desktop environment";
  };
  config = mkIf cfg.enable {
    environment = {
      pathsToLink = ["/libexec"];
      systemPackages = with pkgs; [
        lxappearance
        xorg.xrandr
        xclip
      ];
      variables = {
        GDK_SCALE = "1";
        GDK_DPI_SCALE = "1";
        _JAVA_OPTIONS = "-Dsun.java2d.uiScale=1";
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        XCURSOR_SIZE = "20";
      };
    };
    security.pam.services = {
      greetd.kwallet = {
        enable = true;
        package = pkgs.kdePackages.kwallet-pam;
      };
    };
    services = {
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd startx";
            user = systemArgs.username;
          };
          initial_session = {
            command = "startx > ~/.i3.log 2>&1";
            user = systemArgs.username;
          };
        };
      };
      xserver = {
        dpi = 96;
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
