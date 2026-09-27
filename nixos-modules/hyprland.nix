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
      greetd = let
        startHyprland = pkgs.writeShellScript "start-hyprland-session" ''
          exec ${pkgs.hyprland}/bin/start-hyprland >"$HOME/.hyprland.log" 2>&1
        '';
      in {
        useTextGreeter = true;
        enable = true;
        settings = {
          # Every session after the first (logout, crash) has to authenticate.
          default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${startHyprland}";
          # Autologin once per boot (the disk was already unlocked with LUKS).
          # HYPR_AUTOLOGIN makes Hyprland lock itself with hyprlock on startup.
          initial_session = {
            command = "${pkgs.coreutils}/bin/env HYPR_AUTOLOGIN=1 ${startHyprland}";
            user = systemArgs.username;
          };
        };
      };
    };
  };
}
