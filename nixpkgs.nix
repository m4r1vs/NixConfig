{
  pkgs,
  config,
  lib,
  systemArgs,
  inputs,
  ...
}:
with lib; let
  isWayland = config.configured ? desktop && !config.configured.desktop.x11;
  isDesktop = config.configured ? desktop && config.configured.desktop.enable;
  isDarwin = systemArgs.system == "aarch64-darwin";
  pkgsUnstable = import inputs.nixpkgs_unstable {
    system = systemArgs.system;
    config.allowUnfree = true;
  };
  pkgsMaster = import inputs.nixpkgs_master {
    system = systemArgs.system;
    config.allowUnfree = true;
  };
in {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      /*
      Own packages
      */
      (final: prev: {
        atai = inputs.atai.packages.${prev.system}.atai;
      })
      /*
      From unstable Nixpkgs
      */
      (final: prev: {
        direnv = pkgsUnstable.direnv;
      })
      (final: prev: {
        mise = pkgsUnstable.mise;
      })
      (final: prev: {
        ghostty =
          if isDarwin
          then pkgsUnstable.ghostty-bin
          else pkgsUnstable.ghostty;
      })
      (final: prev: {
        code-cursor = pkgsUnstable.code-cursor;
      })
      (final: prev: {
        aerospace = pkgsUnstable.aerospace;
      })
      (final: prev: {
        yabai = pkgsUnstable.yabai;
      })
      (final: prev: {
        skhd-zig = with pkgs;
          stdenv.mkDerivation {
            pname = "skhd-zig";
            version = "0.0.15";
            buildInputs = [
              lsd
            ];
            src = fetchTarball {
              url = "https://github.com/jackielii/skhd.zig/releases/download/v0.0.15/skhd-arm64-macos.tar.gz";
              sha256 = "sha256:1184g39dfhidzkjqhvn8lcjjhw5l65bg4nzccjkx91j4cx8x5xz9";
            };
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp ./skhd-arm64-macos $out/bin/skhd
              runHook postInstall
            '';
          };
      })
      (final: prev: {
        yazi = pkgsUnstable.yazi;
        yaziPlugins = pkgsUnstable.yaziPlugins;
      })
      (final: prev: {
        minecraftServers = pkgsUnstable.minecraftServers;
      })
      (final: prev: {
        aerospace-swipe = with pkgsUnstable;
          stdenvNoCC.mkDerivation {
            pname = "aerospace-swipe";
            version = "0.1.0";
            buildInputs = [clang_19 darwin.sigtool];
            src = fetchFromGitHub {
              owner = "acsandmann";
              repo = "aerospace-swipe";
              rev = "fc1bdcbcd27c3x7b7765ba88161bb40bddd627b12";
              hash = "sha256-Qfj6+qZ/SQND+LMOSdUiYGDXFxU6+xmXxkYerxsdkcE=";
            };
            patchPhase = ''
              runHook prePatch
              sed -i "s/kIOMainPortDefault/kIOMasterPortDefault/g" src/haptic.c
              sed -i 's|--sign - $(APP_BUNDLE)|-f --sign - $(APP_MACOS)/$(BINARY_NAME)|' Makefile
              runHook postPatch
            '';
            buildPhase = ''
              make bundle
            '';
            installPhase = ''
              mkdir -p $out/Applications
              cp -r AerospaceSwipe.app $out/Applications/
            '';
          };
      })
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
        kubernetes = pkgsUnstable.kubernetes;
      })
      (final: prev: {
        containerd = prev.containerd.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "containerd";
            repo = "containerd";
            rev = "release/2.2";
            hash = "sha256-nMT4iTfVEiGvrobhq0wue/xI1kACX6eB0UteHnZAQbk=";
          };
        };
      })
      (final: prev: {
        gemini-cli = pkgsMaster.gemini-cli;
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
              rev = "9e2a1405e1782eb37ae3746faeb0311adac6f0f6";
              hash = "sha256-RO7So7U78U5uGb4x9G8I2L00XplBsRz3q2U34I4oYwc=";
            };

            cargoHash = "sha256-rqDLkzCl7gn3s/37MPytYaGb0tdtemYi8bgEkrkllDU=";

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
      (final: prev:
        with prev; {
          clippy-darwin = pkgsUnstable.buildGoModule {
            pname = "clippy-darwin";
            version = "1.6.1";

            src = fetchFromGitHub {
              owner = "neilberkman";
              repo = "clippy";
              rev = "dd94573da7ab30a7277834e53aeb04cb2b6f7f56";
              hash = "sha256-81bV+C+3Z7S1ymudZ+4TH6D5IItfvxCo2Hh+dippbic=";
            };

            vendorHash = "sha256-9za2KDUB4txYhJo0ezbLk6h8g6EYnxJhWWjzes+5IIg=";

            buildPhase = ''
              runHook preBuild
              go build -o clippy ./cmd/clippy
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              mv ./clippy $out/bin/clippy
              runHook postInstall
            '';
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
