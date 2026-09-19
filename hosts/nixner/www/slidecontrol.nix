{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.services.configured.slidecontrol;
in {
  options.services.configured.slidecontrol = {
    enable = mkEnableOption "Enable Slidecontrol";
    domain = mkOption {
      type = types.singleLineStr;
      default = null;
      description = "The Domain to be used.";
    };
    port = mkOption {
      type = types.port;
      default = 1337;
      description = "The Port to be used.";
    };
  };
  config = mkIf cfg.enable {
    nixpkgs.overlays = [inputs.slidecontrol.overlays.default];
    services = {
      slidecontrol-server = {
        enable = true;
        inherit (cfg) port;
        dataDir = "/var/data/slidecontrol";
      };

      nginx = {
        virtualHosts."slides.${cfg.domain}" = {
          forceSSL = true;
          useACMEHost = cfg.domain;
          locations."/" = {
            root = "${pkgs.slidecontrol-pwa}/dist";
            index = "index.html";
            extraConfig = ''
              default_type text/html;
              error_page 404 =200 /index.html;
              limit_except GET HEAD {
                deny all;
              }
            '';
          };
          locations."/socket" = {
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
