{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.server.services.minecraft;
in {
  options.configured.server.services.minecraft = {
    enable = mkEnableOption "Enable a minecraft server";
    port = mkOption {
      type = types.port;
      default = 25565;
      description = "The Port to be used";
    };
  };
  config = mkIf cfg.enable {
    services.minecraft-server = {
      package = pkgs.minecraftServers.vanilla-1-21;
      enable = true;
      eula = true;
      openFirewall = true;
      declarative = true;
      serverProperties = {
        server-port = cfg.port;
        difficulty = 2;
        gamemode = 0;
        max-players = 12;
        motd = "Schlackis gemütliche Fussball Ecke";
        white-list = false;
        allow-cheats = false;
      };
      jvmOpts = "-Xms2048M -Xmx4096M";
    };
  };
}
