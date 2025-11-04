{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.configured.server.services.bind;
in {
  options.configured.server.services.bind = {
    enable = mkEnableOption "Enable BIND as a DNS Server.";
    domain = mkOption {
      type = types.singleLineStr;
      default = null;
      description = "The Domain to certify (including all subdomains)";
    };
    dnsSettings = mkOption {
      type = types.lines;
      default = null;
      description = "BIND DNS Config";
    };
  };
  config = optionalAttrs (options ? boot) (mkIf cfg.enable {
    system.activationScripts.bind-zones.text = ''
      mkdir -p /etc/bind/zones
      chown named:named /etc/bind/zones
    '';
    environment.etc."bind/zones/${cfg.domain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0644";
      text = cfg.dnsSettings;
    };
    services.bind = {
      enable = true;
      zones."${cfg.domain}" = {
        file = "/etc/bind/zones/${cfg.domain}.zone";
        master = true;
      };
    };
  });
}
