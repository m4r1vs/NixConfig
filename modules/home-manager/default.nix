{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.home-manager;
in {
  options.configured.home-manager = {
    enable = mkEnableOption "Enable Home Manager";
  };
  config = mkIf cfg.enable {
    home-manager = {
      backupFileExtension = ".hm-backup";
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${systemArgs.username} = import ./home.nix;
      extraSpecialArgs = {
        inherit systemArgs;
        scripts = (import ./makeScripts.nix) {inherit pkgs systemArgs config;};
      };
    };
  };
}
