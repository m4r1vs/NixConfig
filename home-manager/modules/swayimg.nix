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
        swayimg.text.size = 16
        swayimg.text.color = 0xaaffffff
        swayimg.viewer.default_scale = "optimal"

        swayimg.overlay = true
        swayimg.viewer.on_key("q", function ()
          swayimg.exit(0)
        end)
      '';
  };
}
