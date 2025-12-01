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
    homepage-server = {
      enable = true;
      domain = "marius.niveri.dev";
      acmeHost = "niveri.dev";
      socket = true;
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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDB9dPD91UOXdhmhfx9tZa/duzFyPgUj0uX8Q5scmCwF gitlab_ci"
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

          envoy                 IN      A       91.107.238.152
                                IN      AAAA    2a01:4f8:1c1c:373e::1

          *.envoy               IN      A       91.107.238.152
                                IN      AAAA    2a01:4f8:1c1c:373e::1

          *                     IN      TXT     google-site-verification=D-lnbFdtT250DqBO99hnS1fN3vDOXKvtTB42F9iGOE4

          @                     IN      TXT     google-site-verification=D-lnbFdtT250DqBO99hnS1fN3vDOXKvtTB42F9iGOE4

          @                     IN      A       ${ipv4}
                                IN      AAAA    ${ipv6}

          *                     IN      A       ${ipv4}
                                IN      AAAA    ${ipv6}

          mc                    IN      A       ${ipv4}
                                IN      AAAA    ${ipv6}

          _minecraft._tcp.mc    IN      SRV     0   5   25565   mc.niveri.dev.
        '';
      };
      cache = {
        domain = "niveri.dev";
        enable = true;
      };
      gitlab-runner = {
        enable = true;
        authSecretPaths = [
          "/var/lib/secrets/nix-gitlab-runner-0-token"
          "/var/lib/secrets/nix-gitlab-runner-1-token"
          "/var/lib/secrets/nix-gitlab-runner-2-token"
          "/var/lib/secrets/nix-gitlab-runner-3-token"
        ];
      };
      minecraft = {
        enable = true;
        port = 25565;
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
