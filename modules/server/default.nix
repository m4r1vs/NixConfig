{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.configured.server;
in {
  imports = [
    ./terminfo
    ./services
    ./networking.nix
  ];
  options.configured.server = {
    enable = mkEnableOption "Enable SSH and other stuff that should be available on a remote Server.";
  };

  config = mkIf cfg.enable {
    configured.server.terminfo.enable = true;

    nixpkgs.overlays = [inputs.slidecontrol.overlays.default];

    services = {
      fail2ban.enable = true;
      openssh = {
        enable = true;
        ports = [22];
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
  };
}
