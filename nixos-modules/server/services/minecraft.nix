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
      whitelist = {
        username1 = "dfa12c34-c848-4f8a-b29a-e31aaafaa679";
        nille453 = "c837e949-c226-48cc-a5f6-9f4d0e71b8d7";
      };
      serverProperties = {
        server-port = cfg.port;
        difficulty = 2;
        gamemode = 0;
        max-players = 12;
        motd = "Schlackis gemütliche Fussball Ecke";
        white-list = true;
        allow-cheats = false;
      };
      jvmOpts = "-Xms2048M -Xmx4096M";
    };
  };
}
