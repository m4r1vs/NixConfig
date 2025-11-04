{
  lib,
  config,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.razer;
in {
  options.configured.razer = {
    enable = mkEnableOption "Enable OpenRazer Drivers";
  };
  config = mkIf cfg.enable {
    users.users.${systemArgs.username}.extraGroups = [
      "openrazer"
    ];
    environment.systemPackages = with pkgs; [
      openrazer-daemon
    ];
    hardware.openrazer.enable = true;
  };
}
