{
  lib,
  config,
  scripts,
  ...
}:
with lib; let
  cfg = config.programs.configured.newsboat;
in {
  options.programs.configured.newsboat = {
    enable = mkEnableOption "RSS Reader";
  };
  config = mkIf cfg.enable {
    programs.newsboat = {
      enable = true;
      autoReload = true;
      browser = "${
        scripts.xdg-open-yt {
          player = "${config.programs.mpv.finalPackage}/bin/mpv";
        }
      }";
      extraConfig = ''
        unbind-key ENTER
        unbind-key j
        unbind-key k
        unbind-key J
        unbind-key K

        bind-key j down
        bind-key k up
        bind-key l open
        bind-key h quit
      '';
    };
  };
}
