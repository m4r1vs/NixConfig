{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.gtk;
in {
  options.configured.gtk = {
    enable = mkEnableOption "Gnome/GNU/GUI Toolkit for UI.";
  };
  config = mkIf cfg.enable {
    gtk = {
      enable = true;
      gtk3 = {
        bookmarks = [
          "file://${config.home.homeDirectory}/Desktop"
          "file://${config.home.homeDirectory}/Downloads"
          "file://${config.home.homeDirectory}/Documents"
          "file://${config.home.homeDirectory}/Pictures"
          "file://${config.home.homeDirectory}/Music"
          "file://${config.home.homeDirectory}/Projects"
          "file://${config.home.homeDirectory}/Videos"
        ];
      };
      theme = {
        package = pkgs.gnome-themes-extra;
        name = "Adwaita";
      };
      iconTheme = {
        package = pkgs.papirus-icon-theme;
        name = "Papirus";
      };
      cursorTheme = {
        package = pkgs.bibata-cursors;
        size = 20;
        name = "Bibata-Modern-Ice";
      };
      font = {
        package = pkgs.ubuntu-classic;
        name = "Ubuntu";
        size = 10;
      };
    };
  };
}
