{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.services.configured.stummumschalterung;
in {
  options.services.configured.stummumschalterung = {
    enable = mkEnableOption "Enable Stummumschalterung";
    domain = mkOption {
      type = types.singleLineStr;
      default = null;
      description = "The Domain to be used.";
    };
    port = mkOption {
      type = types.port;
      default = 1338;
      description = "The Port to be used.";
    };
  };
  config = mkIf cfg.enable {
    nixpkgs.overlays = [inputs.stummumschalterung.overlays.default];
    services = {
      stummumschalterung-server = {
        enable = true;
        port = cfg.port;
        dataDir = "/var/data/stummumschalterung";
      };

      nginx = {
        virtualHosts."stummumschalterung.${cfg.domain}" = {
          forceSSL = true;
          useACMEHost = cfg.domain;
          locations."/" = {
            proxyPass = "http://0.0.0.0:${toString cfg.port}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_http_version 1.1;
              proxy_headers_hash_bucket_size 128;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };
  };
}
