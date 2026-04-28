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
  };
  config = mkIf cfg.enable {
    services.darkman = {
      enable = true;
      settings = {
        lat = 53.54;
        lng = 9.98;
        usegeoclue = false;
      };
      darkModeScripts = {
        mode = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/color-scheme \"'prefer-dark'\"";
        theme = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/gtk-theme \"'Adwaita-dark'\"";
        icons = "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme \"'Papirus-Dark'\" && pkill blueman-applet && blueman-applet &";
        customs = "${scripts.custom-theme} dark";
      };
      lightModeScripts = {
        mode = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/color-scheme \"'prefer-light'\"";
        theme = "${pkgs.dconf}/bin/dconf write\ /org/gnome/desktop/interface/gtk-theme \"'Adwaita'\"";
        icons = "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme \"'Papirus-Light'\" && pkill blueman-applet && blueman-applet &";
        customs = "${scripts.custom-theme} light";
      };
    };
  };
}
