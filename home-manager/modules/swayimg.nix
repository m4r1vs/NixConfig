{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.swayimg;
in {
  options.programs.configured.swayimg = {
    enable = mkEnableOption "swayimg image viewer";
  };
  config = mkIf cfg.enable {
    programs.swayimg = {
      enable = true;
      package = pkgs.swayimg;
    };
    xdg.configFile."swayimg/init.lua".text =
      #lua
      ''
        swayimg.text.set_size(16)
        swayimg.text.set_foreground(0xaaffffff)
        swayimg.viewer.set_default_scale("optimal")

        swayimg.enable_overlay(true)
        swayimg.viewer.on_key("q", function ()
          swayimg.exit(0)
        end)
      '';
  };
}
