{
  lib,
  config,
  ...
}:
with lib; let
  inherit (config.configured.host) isDesktop;
  cfg = config.configured.nvidia;
in {
  options.configured.nvidia = {
    enable = mkEnableOption "Enable NVidia Driver";
  };
  config = mkIf cfg.enable {
    services = mkIf isDesktop {
      xserver.videoDrivers = ["nvidia"];
    };
    hardware = {
      nvidia-container-toolkit.enable = true;
      graphics = {
        enable = true;
      };
      nvidia = {
        # Required choice for drivers >= 560; open modules need Turing or newer
        open = mkDefault true;
        modesetting.enable = true;
        powerManagement.enable = true;
        powerManagement.finegrained = false;
        nvidiaSettings = isDesktop;
      };
    };
  };
}
