{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.gamescope;
  isX86 = systemArgs.system == "x86_64-linux";
in {
  options.configured.gamescope = {
    enable = mkEnableOption "Enable gamescope session";
  };

  config = mkIf cfg.enable {
    services = {
      displayManager = {
        autoLogin = {
          enable = true;
          user = systemArgs.username;
        };
        defaultSession = "steam-gamescope";
      };

      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd steam-gamescope";
            user = systemArgs.username;
          };
          initial_session = {
            command = "steam-gamescope";
            user = systemArgs.username;
          };
        };
      };
    };

    security.pam.services = {
      greetd.kwallet = {
        enable = true;
        package = pkgs.kdePackages.kwallet-pam;
      };
    };

    programs = {
      gamescope.enable = true;
      steam = mkIf isX86 {
        gamescopeSession = {
          enable = true;
          args = ["--force-grab-cursor"];
        };
      };
    };
  };
}
