{
  lib,
  config,
  osConfig,
  ...
}:
with lib; let
  cfg = config.services.configured.ollama;
in {
  options.services.configured.ollama = {
    enable = mkEnableOption "Run LLMs locally";
  };
  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      acceleration =
        if osConfig.configured.nvidia.enable
        then "cuda"
        else "";
    };
  };
}
