{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.configured.nginx;
in {
  options.services.configured.nginx = {
    enable = mkEnableOption "Enable NGINX as a reverse proxy to serve different stuff on the WWW.";
    domain = mkOption {
      type = types.singleLineStr;
      default = null;
      description = "The Domain to be used.";
    };
  };
  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      enableReload = true;

      additionalModules = [
        pkgs.nginxModules.brotli
      ];

      commonHttpConfig = ''
        brotli on;
        brotli_static on;
        brotli_types *;
      '';

      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts."${cfg.domain}" = {
        forceSSL = true;
        useACMEHost = cfg.domain;
        globalRedirect = "marius.${cfg.domain}";
      };

      virtualHosts."nixner.${cfg.domain}" = {
        forceSSL = true;
        useACMEHost = cfg.domain;
        globalRedirect = "github.com/m4r1vs/NixConfig/tree/main/hosts/nixner";
      };

      virtualHosts."old.${cfg.domain}" = {
        forceSSL = true;
        useACMEHost = cfg.domain;
        locations."/" = {
          root = ./old.niveri.dev;
          index = "index.html";
          extraConfig = ''
            default_type text/html;
            limit_except GET HEAD {
              deny all;
            }
          '';
        };
      };

      virtualHosts."dns-admin.${cfg.domain}" = {
        forceSSL = true;
        useACMEHost = cfg.domain;
        globalRedirect = "marius.niveri.dev";
      };

      virtualHosts."*.${cfg.domain}" = {
        forceSSL = true;
        useACMEHost = cfg.domain;
        extraConfig = ''
          return 404;
        '';
      };
    };
  };
}
