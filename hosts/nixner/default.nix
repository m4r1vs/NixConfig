{systemArgs, ...}: let
  inherit (systemArgs) ipv4 ipv6;
in {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
    ./www
  ];

  services = {
    configured = {
      nginx = {
        enable = true;
        domain = "niveri.dev";
      };
      slidecontrol = {
        enable = true;
        domain = "niveri.dev";
      };
      stummumschalterung = {
        enable = true;
        domain = "niveri.dev";
      };
    };
    comin = {
      enable = true;
      debug = true;
      allowForcePushMain = true;
      remotes = [
        {
          name = "origin";
          url = "https://github.com/m4r1vs/NixConfig.git";
          branches.main.name = "main";
        }
      ];
    };
  };

  users.users.${systemArgs.username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFBNq0SWrIVxHKZazvSROg+sghfK4857bclimtjBQGP+ pipeline@gitlab.cluster.niveri.dev"
  ];

  configured.server = {
    enable = true;
    networking = {
      enable = true;
      nameservers = [
        "8.8.8.8"
      ];
    };
    security = {
      acme = {
        enable = true;
        domain = "niveri.dev";
        additionalDomains = [
          "*.kubenix.niveri.dev"
        ];
        useDNS01 = true;
      };
    };
    services = {
      bind = {
        enable = true;
        domain = "niveri.dev";
        dnsSettings = ''
          $ORIGIN niveri.dev.
          $TTL    1h
          @                     IN      SOA     ns1 dns-admin (
                                                    10  ; Serial
                                                    3h  ; Refresh
                                                    1h  ; Retry
                                                    1w  ; Expire
                                                    1h) ; Negative Cache TTL
                                IN      NS      ns1
                                IN      NS      ns2

          falkenberg.kubenix    IN      A       91.99.10.215
                                IN      AAAA    2a01:4f8:c013:e704::1

          stadeln.kubenix       IN      A       91.107.238.152
                                IN      AAAA    2a01:4f8:1c1c:373e::1

          ronhof.kubenix        IN      A       91.99.63.12
                                IN      AAAA    2a01:4f8:1c1b:f047::1

          cluster               IN      A       91.99.10.215
                                IN      AAAA    2a01:4f8:c013:e704::1

          *.cluster             IN      A       91.99.10.215
                                IN      AAAA    2a01:4f8:c013:e704::1

          @                     IN      A       ${ipv4}
                                IN      AAAA    ${ipv6}

          *                     IN      A       ${ipv4}
                                IN      AAAA    ${ipv6}
        '';
      };
      cache = {
        domain = "niveri.dev";
        enable = true;
      };
    };
  };

  networking = {
    firewall = {
      allowedTCPPorts = [53 80 443];
      allowedUDPPorts = [53];
    };
  };

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
