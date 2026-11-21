{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.configured.mdns;
in {
  options.configured.mdns = {
    enable = mkEnableOption ''
      mDNS via Avahi: announce this machine as <hostname>.local on the
      current LAN and resolve other .local names (e.g. the Mac's Bonjour
      name), so machines find each other without knowing their IPs
    '';
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      # Resolve *.local through NSS (ssh, ping, ...); IPv4 only, since
      # nssmdns6 makes lookups stall on networks without IPv6 mDNS.
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
      };
      # Opens UDP 5353 (on by default, stated for clarity).
      openFirewall = true;
    };

    # One responder per host: resolved would otherwise also answer on 5353.
    services.resolved.settings.Resolve.MulticastDNS = mkIf config.services.resolved.enable false;
  };
}
