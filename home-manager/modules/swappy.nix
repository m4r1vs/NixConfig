{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.swappy;
in {
  options.programs.configured.swappy = {
    enable = mkEnableOption "Screenshot Editor";
  };
  config = mkIf cfg.enable {
    home.file."./.config/swappy/config".text = ''
      [Default]
      auto_save=false
      save_dir=$HOME/Pictures/Screenshots
      save_filename_format=screenshot_%Y-%m-%d-%H-%M-%S.png
      show_panel=true
      line_size=5
      text_size=16
      text_font=sans-serif
      paint_mode=brush
      early_exit=false
      fill_shape=false
    '';
  };
}
