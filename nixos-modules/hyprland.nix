{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.hyprland;
in {
  options.configured.hyprland = {
    enable = mkEnableOption "Enable hyprland tiling window manager as desktop environment";
  };
  config = mkIf cfg.enable {
    environment = {
      systemPackages = with pkgs; [
        wl-clipboard
      ];
      sessionVariables = {
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        NIXOS_OZONE_WL = "1";
        QS_ICON_THEME = "Papirus";
      };
    };

    security.pam.services = {
      greetd.enableGnomeKeyring = true;
      login.enableGnomeKeyring = true;
      greetd-password.enableGnomeKeyring = true;
      gdm-password.enableGnomeKeyring = true;
      hyprlock.enableGnomeKeyring = true;
    };
    programs = {
      hyprland.enable = true;
      hyprlock.enable = true;
    };
    services = {
      greetd = {
        useTextGreeter = true;
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.hyprland}/bin/Hyprland";
            user = systemArgs.username;
          };
        };
      };
    };
  };
}
