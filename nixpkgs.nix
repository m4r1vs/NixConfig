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
        gimp-with-plugins = prev.gimp3-with-plugins;
      })
      (final: prev: {
        hyprlandPlugins =
          prev.hyprlandPlugins
          // {
            hyprfocus = prev.hyprlandPlugins.hyprfocus.overrideAttrs {
              src = pkgs.fetchFromGitHub {
                owner = "daxisunder";
                repo = "hyprfocus";
                rev = "516e36572f50cca631e7e572249b3716c3602176";
                hash = "sha256-TnsdJxxBFbc54T43UP+7mmZkErc7NrZ31C0QNePdDrE=";
              };
              meta.broken = false;
            };
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
