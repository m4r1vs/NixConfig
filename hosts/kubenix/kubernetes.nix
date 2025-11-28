{
  systemArgs,
  pkgs,
  lib,
  ...
}: let
  inherit (systemArgs) clusterRoles k8sPort masterFqdn masterIpv4 domain;
  resourceFromYAML = {
    ns,
    path,
  }: let
    splitYamlDrv =
      pkgs.runCommand "split-yaml-to-json" {
        nativeBuildInputs = [pkgs.remarshal pkgs.coreutils pkgs.gawk];
        src = path;
      } ''
        mkdir -p $out
        awk 'BEGIN{RS="\n?---\n?"} $0 ~ /\S/ {printf "%s\0", $0}' "$src" | \
        while IFS= read -r -d $'\0' chunk; do
          local hash=$(printf "%s" "$chunk" | sha256sum | cut -d' ' -f1)
          local target_json="$out/$hash.json"
          printf "%s" "$chunk" | remarshal -if yaml -i /dev/stdin -of json -o "$target_json" \
            || { echo "Error: remarshal failed for chunk with hash $hash"; exit 1; }
        done
      '';
    dirContents = builtins.readDir splitYamlDrv;
    attrList =
      lib.mapAttrsToList (
        fileName: fileType:
          if fileType == "regular" && lib.strings.hasSuffix ".json" fileName
          then let
            hash = lib.strings.removeSuffix ".json" fileName;
            filePath = splitYamlDrv + "/${fileName}";
            jsonContent = builtins.readFile filePath;
            parsedValue = builtins.fromJSON jsonContent;
          in {
            name = hash;
            value = (
              lib.recursiveUpdate
              parsedValue
              {
                metadata.namespace = ns;
              }
            );
          }
          else null
      )
      dirContents;
    validAttrs = lib.filter (x: x != null) attrList;
  in
    lib.attrsets.listToAttrs validAttrs;
in {
  configured.server = {
    enable = true;
    networking = {
      enable = true;
      nameservers = [
        "8.8.8.8"
      ];
    };
  };

  networking = {
    inherit domain;
    firewall = {
      allowedTCPPorts = [22 53 80 443 k8sPort];
      allowedUDPPorts = [53];
      trustedInterfaces = [
        "enp7s0"
      ];
    };
    extraHosts = ''
      ${masterIpv4} ${masterFqdn}
      10.0.0.4 ronhof.${domain}
      10.0.0.3 stadeln.${domain}
    '';
  };

  services.openssh = {
    ports = lib.mkForce [422];
  };

  services.comin = {
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

  virtualisation.containerd = {
    settings = lib.mkForce {
      version = 2;
      root = "/var/lib/containerd";
      state = "/run/containerd";
      oom_score = 0;

      grpc = {
        address = "/run/containerd/containerd.sock";
      };

      plugins."io.containerd.grpc.v1.cri" = {
        sandbox_image = "registry.k8s.io/pause:3.10.1";

        cni = {
          bin_dir = "/opt/cni/bin";
          max_conf_num = 0;
        };

        containerd.runtimes.runc = {
          runtime_type = "io.containerd.runc.v2";
          options.SystemdCgroup = true;
        };
      };
    };
  };

  services.kubernetes = let
    masterAddr = "https://${masterFqdn}:${toString k8sPort}";
    isMaster = builtins.elem "master" clusterRoles;
  in {
    roles = clusterRoles;
    apiserverAddress = masterAddr;
    masterAddress = masterFqdn;
    easyCerts = true;
    addonManager = lib.mkIf isMaster {
      enable = true;
      bootstrapAddons =
        (resourceFromYAML {
          path = builtins.fetchurl {
            url = "https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.0/manifests/install.yaml";
            sha256 = "sha256:191q5rxlamfm7hh7b9604l3pzhavhx200v5vj95rm130yw7rlaai";
          };
          ns = "argocd";
        })
        // {
          argo-namespace = {
            apiVersion = "v1";
            kind = "Namespace";
            metadata = {
              name = "argocd";
            };
          };
          cluster-bootstrap = {
            apiVersion = "argoproj.io/v1alpha1";
            kind = "Application";
            metadata = {
              name = "cluster-bootstrap";
              namespace = "argocd";
            };
            spec = {
              project = "default";
              source = {
                repoURL = "https://github.com/m4r1vs/argo-apps";
                targetRevision = "HEAD";
                path = "bootstrap";
                directory = {
                  recurse = true;
                };
              };
              destination = {
                server = "https://kubernetes.default.svc";
                namespace = "bootstrap";
              };
              syncPolicy = {
                syncOptions = [
                  "CreateNamespace=true"
                ];
                automated = {
                  prune = true;
                  allowEmpty = true;
                  selfHeal = true;
                };
              };
            };
          };
        };
    };
    addons.dns = {
      enable = true;
      clusterDomain = domain;
      # TODO: test if this has been fixed, if not, open PR
      coredns = {
        imageName = "mariusniveri/my-coredns";
        imageDigest = "sha256:dd3d70eaa614e7228af8124ef37c7d8ccd92e9dd0cbdd823f727428d7b8191f3";
        finalImageTag = "latest";
        sha256 = "sha256-ID+qV6/knQDQ8leyq4r08uexPdDiu739Qeh/cBP0GfE=";
      };
    };
    flannel = {
      enable = true;
      openFirewallPorts = true;
    };
    proxy.enable = true;
    kubelet =
      (
        if isMaster
        then {
          enable = true;
          hostname = masterFqdn;
        }
        else {
          enable = true;
          kubeconfig.server = masterAddr;
        }
      )
      // {
        extraConfig = {
          evictionHard = {
            "imagefs.available" = "5%";
            "nodefs.available" = "5%";
            "memory.available" = "100Mi";
          };
        };
      };
    apiserver = lib.mkIf isMaster {
      enable = true;
      securePort = k8sPort;
      advertiseAddress = masterIpv4;
      allowPrivileged = true;
    };
  };
}
