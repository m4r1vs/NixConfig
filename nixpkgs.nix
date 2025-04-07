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
              ["fzf"]
              ++ lib.optionals isDesktop [
                "pulseaudio-backend"
                "media-control"
                "image"
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
