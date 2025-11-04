{
  lib,
  config,
  systemArgs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.kmscon;
in {
  options.services.configured.kmscon = {
    enable = mkEnableOption "Enable Kmscon geTTY replacement";
    autologin = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically log in with the default user";
    };
  };
  config = optionalAttrs (options ? boot) (mkIf cfg.enable {
    services.kmscon = {
      enable = true;
      fonts = [
        {
          name = "JetBrainsMono Nerd Font Mono";
          package = pkgs.nerd-fonts.jetbrains-mono;
        }
      ];
      autologinUser = mkIf cfg.autologin "${systemArgs.username}";
      extraOptions = "--term xterm-256color";
    };
  });
}
