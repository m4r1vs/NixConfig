{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.configured.server.services.cache;
in {
  options.configured.server.services.cache = {
    enable = mkEnableOption "Serve this host's /nix/store as a cache to the WWW";

    domain = mkOption {
      type = types.singleLineStr;
      default = null;
      description = "The domain to serve the cache on";
    };
  };
  config = optionalAttrs (options ? boot) (mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.nginx.enable;
        message = "Please enable nginx so this cache can be served.";
      }
      {
        assertion = config.services.nginx.recommendedProxySettings;
        message = "Please enable nginx recommended proxy settings.";
      }
      {
        assertion = config.services.nginx.virtualHosts."${cfg.domain}" != null;
        message = "The nginx virtualhost for 'nix-cache.${cfg.domain}' has already been set. Disable it or choose a different domain.";
      }
    ];
    users.users."nix-serve" = {
      isSystemUser = true;
      group = "nix-serve";
    };
    users.groups."nix-serve" = {
      name = "nix-serve";
    };
    systemd.services.cache-key-gen = {
      requiredBy = ["nix-serve.service"];
      before = ["nix-serve.service"];
      unitConfig = {
        ConditionPathExists = "!/var/cache-priv-key.pem";
      };
      serviceConfig = {
        Type = "oneshot";
        UMask = 0077;
      };
      script = ''
        cd /var
        /run/current-system/sw/bin/nix-store --generate-binary-cache-key nix-cache.${cfg.domain} cache-priv-key.pem cache-pub-key.pem
        chown nix-serve cache-priv-key.pem
        chmod 600 cache-priv-key.pem
      '';
    };

    services = {
      nix-serve = {
        enable = true;
        secretKeyFile = "/var/cache-priv-key.pem";
        bindAddress = "127.0.0.1";
      };
      nginx.virtualHosts."nix-cache.${cfg.domain}" = {
        forceSSL = true;
        useACMEHost = cfg.domain;
        locations."/".proxyPass = "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
      };
    };
  });
}
