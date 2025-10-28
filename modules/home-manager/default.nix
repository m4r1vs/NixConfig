{
  lib,
  config,
  pkgs,
  systemArgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.configured.home-manager;
  pkgsUnstable = import inputs.nixpkgs_unstable {
    system = systemArgs.system;
    config.allowUnfree = true;
  };
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
        inherit systemArgs pkgsUnstable;
        scripts = (import ./makeScripts.nix) {inherit pkgs systemArgs config;};
      };
    };
  };
}
