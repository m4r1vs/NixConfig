{
  pkgs,
  config,
  lib,
  ...
}: let
  isWayland = !config.configured.desktop.x11;
  isDesktop = config.configured.desktop.enable;
in {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      /*
      Temporary Fixes / Updates
      */
      (final: prev: {
        tmux = prev.tmux.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "m4r1vs";
            repo = "tmux";
            rev = "159971c823a31d989925f8ad82774bb949f97e20";
            hash = "sha256-TP0jL+oA/qHHlOYG2zyDZmSxa39+UgLWM2NvPEoVXyE=";
          };
        };
      })
      (final: prev: {
        hyprlandPlugins =
          prev.hyprlandPlugins
          // {
            hyprfocus = prev.hyprlandPlugins.hyprfocus.overrideAttrs {
              src = pkgs.fetchFromGitHub {
                owner = "daxisunder";
                repo = "hyprfocus";
                rev = "8061b05a04432da5331110e0ffaa8c81e1035725";
                hash = "sha256-n8lCf4zQehWEK6UJWcLuGUausXuRgqggGuidc85g20I=";
              };
              meta.broken = false;
            };
          };
      })
      (final: prev: {
        etcd = let
          version = "3.5.19";
          etcdSrcHash = "sha256-UulUIjl4HS1UHJnlamhtgVqzyH+UroCQ9zarxO5Hp6M=";
          etcdServerVendorHash = "sha256-0AXw44BpMlDQMML4HFQwdORetNrAZHlN2QG9aZwq5Ks=";
          etcdUtlVendorHash = "sha256-RZEsk79wQJnv/8W7tVCehNsqK2awkycd6gV/4OwqdFM=";
          etcdCtlVendorHash = "sha256-RESLrpgsWQV1Fm0vkQedlDowo+yWS4KipiwIcsCB34Y=";

          src = pkgs.fetchFromGitHub {
            owner = "etcd-io";
            repo = "etcd";
            rev = "v${version}";
            hash = etcdSrcHash;
          };

          env = {
            CGO_ENABLED = 0;
          };

          meta = with lib; {
            description = "Distributed reliable key-value store for the most critical data of a distributed system";
            license = licenses.asl20;
            homepage = "https://etcd.io/";
            maintainers = with maintainers; [offline];
            platforms = platforms.darwin ++ platforms.linux;
          };

          etcdserver = pkgs.buildGo123Module {
            pname = "etcdserver";

            inherit
              env
              meta
              src
              version
              ;

            vendorHash = etcdServerVendorHash;

            modRoot = "./server";

            preInstall = ''
              mv $GOPATH/bin/{server,etcd}
            '';

            ldflags = ["-X go.etcd.io/etcd/api/v3/version.GitSHA=GitNotFound"];
          };

          etcdutl = pkgs.buildGo123Module {
            pname = "etcdutl";

            inherit
              env
              meta
              src
              version
              ;

            vendorHash = etcdUtlVendorHash;

            modRoot = "./etcdutl";
          };

          etcdctl = pkgs.buildGo123Module {
            pname = "etcdctl";

            inherit
              env
              meta
              src
              version
              ;

            vendorHash = etcdCtlVendorHash;

            modRoot = "./etcdctl";
          };
        in
          pkgs.symlinkJoin {
            name = "etcd-${version}";

            inherit meta version;

            passthru = {
              inherit etcdserver etcdutl etcdctl;
            };

            paths = [
              etcdserver
              etcdutl
              etcdctl
            ];
          };
      })
      (final: prev: {
        containerd = prev.containerd.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "m4r1vs";
            repo = "containerd";
            rev = "4c61e0f45c81a137fede02daf25fd70e193410bf";
            hash = "sha256-of/6mGBs/Dt4z7mEPyZGcwP80GMezxJ3Zzzxc1l3krk=";
          };
        };
      })
      /*
      Own Forks
      */
      (final: prev:
        with prev; {
          spotify-player = rustPlatform.buildRustPackage {
            pname = "spotify-player";
            version = "0.20.4";

            src = fetchFromGitHub {
              owner = "m4r1vs";
              repo = "spotify-player";
              rev = "afbad6784ba4c43371def403a789e0994f84af3b";
              hash = "sha256-gY/7Pxn8Am/K9PuWAatWmVKZ2SGEPNEvJ4T45hMFRNQ=";
            };

            useFetchCargoVendor = true;
            cargoHash = "sha256-35HuRXp9YFQr0Zxoh0ee7VwqIlHtwcdbIx9K7RSVnU4=";

            nativeBuildInputs = [
              pkg-config
              cmake
              rustPlatform.bindgenHook
            ];

            buildInputs =
              [
                openssl
                dbus
                fontconfig
              ]
              ++ lib.optionals isDesktop [libpulseaudio];

            buildNoDefaultFeatures = true;

            buildFeatures =
              ["fzf" "image"]
              ++ lib.optionals isDesktop [
                "pulseaudio-backend"
                "media-control"
                "daemon"
                "notify"
                "streaming"
              ];
          };
        })
      /*
      Mods to packages
      */
      (final: prev: {
        rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs (oldAttrs: {
          patchPhase = ''
            echo "NoDisplay=true" >> ./data/rofi-theme-selector.desktop
            echo "NoDisplay=true" >> ./data/rofi.desktop
          '';
        });
      })
      (final: prev: {
        polybar = prev.polybar.override {
          nlSupport = true; # networking
          iwSupport = true; # WiFi
          i3Support = true;
          pulseSupport = true;
          alsaSupport = true;
          githubSupport = true;
        };
      })
      /*
      Specialisations
      */
      (lib.mkIf isWayland
        (final: prev: {
          rofi = prev.rofi-wayland;
        }))
    ];
  };
}
