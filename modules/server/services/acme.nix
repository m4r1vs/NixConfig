{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.server.security.acme;
in {
  options.configured.server.security.acme = {
    enable = mkEnableOption "Enable Let's Encrypt to get SSL certificates";
    email = mkOption {
      type = types.singleLineStr;
      default = "marius.niveri@gmail.com";
      description = "The Email to use for Let's Encrypt";
    };
    domain = mkOption {
      type = types.nullOr types.singleLineStr;
      default = null;
      description = "The Domain to certify (including all subdomains)";
    };
    additionalDomains = mkOption {
      type = types.nullOr (types.listOf types.singleLineStr);
      default = null;
      description = "Additional domains to certify";
    };
    useDNS01 = mkOption {
      type = types.bool;
      default = false;
      description = "Get a wildcard certificate for the domain provided using BIND local DNS.";
    };
  };
  config = optionalAttrs (options ? boot) (mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.useDNS01 == false || cfg.domain != null;
          message = "Provide a Domain if you want to validate it";
        }
        {
          assertion = cfg.useDNS01 == false || config.services.bind.enable == true;
          message = "Please enable BIND if you want to use DNS validation";
        }
        {
          assertion = cfg.useDNS01 == false || config.services.bind.zones.${cfg.domain} != null;
          message = "Please set a BIND zone for the given Domain ${cfg.domain}";
        }
      ];

      security.acme = {
        acceptTerms = true;
        defaults.email = cfg.email;
      };
    }
    (mkIf cfg.useDNS01 {
      /*
      In order to create a Wildcard certificate (*.example.com),
      we need to use DNS certification (DNS-01 challange to be precise).
      We could simply use an existing provider such as Namecheap.
        However where is the fun in that?
      We use Berkley Internet Name Domain (BIND) to host our own DNS.
      The ACME service will tell BIND to create a TXT entry with a public key
      that allows it to verify the authenticity of the given domain.
      The certificate and key is then placed in /var/lib/acme/DOMAIN/ for
      HTTP servers to read.
      */
      services.bind = {
        extraConfig = ''
          include "/var/lib/secrets/dnskeys.conf";
        '';
        zones."${cfg.domain}" = {
          extraConfig = "allow-update { key rfc2136key.${cfg.domain}.; };";
        };
      };

      security.acme = {
        certs."${cfg.domain}" = {
          group = "nginx";
          dnsProvider = "rfc2136";
          domain = "*.${cfg.domain}";
          extraDomainNames = [cfg.domain] ++ cfg.additionalDomains;
          environmentFile = "/var/lib/secrets/certs.secret";
          dnsPropagationCheck = false;
        };
      };

      /*
      Dynamically create the keys so that we don't have to figure out how to handle secrets.
      */
      systemd.services.dns-rfc2136-conf = {
        requiredBy = ["acme-${cfg.domain}.service" "bind.service"];
        before = ["acme-${cfg.domain}.service" "bind.service"];
        unitConfig = {
          ConditionPathExists = "!/var/lib/secrets/dnskeys.conf";
        };
        serviceConfig = {
          Type = "oneshot";
          UMask = 0077;
        };
        path = [pkgs.bind];
        script = ''
          mkdir -p /var/lib/secrets
          chmod 755 /var/lib/secrets
          tsig-keygen rfc2136key.${cfg.domain} > /var/lib/secrets/dnskeys.conf
          chown named:root /var/lib/secrets/dnskeys.conf
          chmod 400 /var/lib/secrets/dnskeys.conf

          # extract secret value from the dnskeys.conf
          while read x y; do if [ "$x" = "secret" ]; then secret="''${y:1:''${#y}-3}"; fi; done < /var/lib/secrets/dnskeys.conf

          cat > /var/lib/secrets/certs.secret << EOF
          RFC2136_NAMESERVER='127.0.0.1:53'
          RFC2136_TSIG_ALGORITHM='hmac-sha256.'
          RFC2136_TSIG_KEY='rfc2136key.${cfg.domain}'
          RFC2136_TSIG_SECRET='$secret'
          EOF
          chmod 400 /var/lib/secrets/certs.secret
        '';
      };
    })
  ]));
}
