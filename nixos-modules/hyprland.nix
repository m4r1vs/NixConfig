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
      hyprland = {
        enable = true;
        package = pkgs.hyprland;
      };
      hyprlock = {
        enable = true;
        package = pkgs.hyprlock;
      };
    };
    services = {
      greetd = {
        useTextGreeter = true;
        enable = true;
        settings = rec {
          default_session = {
            command = "${pkgs.hyprland}/bin/Hyprland > ~/.hyprland.log 2>&1";
            user = systemArgs.username;
          };
          initial_session = default_session;
        };
      };
    };
  };
}
