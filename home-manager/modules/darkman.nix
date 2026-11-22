{
  lib,
  config,
  scripts,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.darkman;
in {
  options.services.configured.darkman = {
    enable = mkEnableOption "Automatically change dark/light theme based on the position of the sun in the sky.";
    latitude = mkOption {
      type = types.float;
      default = 53.54;
      description = "Latitude used for solar sunrise/sunset calculation.";
    };
    longitude = mkOption {
      type = types.float;
      default = 9.98;
      description = "Longitude used for solar sunrise/sunset calculation.";
    };
  };
  config = mkIf cfg.enable {
    services.darkman = {
      enable = true;
      settings = {
        lat = cfg.latitude;
        lng = cfg.longitude;
        usegeoclue = false;
      };
      darkModeScripts = {
        mode = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/color-scheme \"'prefer-dark'\"";
        theme = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/gtk-theme \"'Adwaita-dark'\"";
        icons = "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme \"'Papirus-Dark'\" && pkill blueman-applet && blueman-applet &";
        customs = "${scripts.custom-dark-light-theme} dark";
      };
      lightModeScripts = {
        mode = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/color-scheme \"'prefer-light'\"";
        theme = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/gtk-theme \"'Adwaita'\"";
        icons = "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme \"'Papirus-Light'\" && pkill blueman-applet && blueman-applet &";
        customs = "${scripts.custom-dark-light-theme} light";
      };
    };
  };
}
