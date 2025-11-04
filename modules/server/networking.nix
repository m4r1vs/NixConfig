{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.server.networking;
  inherit (systemArgs) ipv4 ipv6 domain;
in {
  options.configured.server.networking = {
    enable = mkEnableOption "Enable custom networking (do not use DHCPCD)";
    ipv4gateway = mkOption {
      type = types.singleLineStr;
      default = "172.31.1.1";
      description = "Static IPv4 Gateway to use on interface";
    };
    ipv6gateway = mkOption {
      type = types.singleLineStr;
      default = "fe80::1";
      description = "Static IPv6 Gateway to use on interface";
    };
    nameservers = mkOption {
      type = types.nullOr (types.listOf types.singleLineStr);
      default = null;
      description = "Nameservers to use";
    };
    interface = mkOption {
      type = types.singleLineStr;
      default = "enp1s0";
      description = "network interface to use";
    };
  };
  config = optionalAttrs (options ? boot) (mkIf cfg.enable {
    networking = {
      inherit domain;
      dhcpcd.enable = lib.mkForce false;
      useDHCP = lib.mkForce false;
      nameservers = mkIf (cfg.nameservers != null) cfg.nameservers;
      enableIPv6 = true;
      defaultGateway = {
        address = cfg.ipv4gateway;
        interface = cfg.interface;
      };
      defaultGateway6 = {
        address = cfg.ipv6gateway;
        interface = cfg.interface;
      };
      interfaces = {
        "${cfg.interface}" = {
          ipv4.addresses = [
            {
              address = ipv4;
              prefixLength = 20;
            }
          ];
          ipv4.routes = [
            {
              address = cfg.ipv4gateway;
              prefixLength = 32;
            }
          ];
          ipv6.addresses = [
            {
              address = ipv6;
              prefixLength = 64;
            }
          ];
          ipv6.routes = [
            {
              address = cfg.ipv6gateway;
              prefixLength = 128;
            }
          ];
        };
      };
    };
  });
}
