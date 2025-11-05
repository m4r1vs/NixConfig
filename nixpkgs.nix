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
in {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      /*
      From unstable Nixpkgs
      */
      (final: prev: {
        ghostty =
          if isDarwin
          then pkgsUnstable.ghostty-bin
          else pkgsUnstable.ghostty;
      })
      (final: prev: {
        aerospace = pkgsUnstable.aerospace;
      })
      (final: prev: {
        yabai = pkgsUnstable.yabai;
      })
      (final: prev: {
        skhd = pkgsUnstable.skhd;
      })
      (final: prev: {
        yazi = pkgsUnstable.yazi;
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
        containerd = prev.containerd.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "m4r1vs";
            repo = "containerd";
            rev = "4c61e0f45c81a137fede02daf25fd70e193410bf";
            hash = "sha256-of/6mGBs/Dt4z7mEPyZGcwP80GMezxJ3Zzzxc1l3krk=";
          };
        };
      })
      (final: prev: {
        gemini-cli-bin = with prev;
          stdenvNoCC.mkDerivation (finalAttrs: {
            pname = "gemini-cli-bin";
            version = "0.11.0";
            src = fetchurl {
              url = "https://github.com/google-gemini/gemini-cli/releases/download/v${finalAttrs.version}/gemini.js";
              hash = "sha256-NdGVl7yZfao4Z5sGw7Xii3MJM3GZ3khHP3NwODkPlE8=";
            };
            dontUnpack = true;
            strictDeps = true;
            buildInputs = [nodejs];
            installPhase = ''
              runHook preInstall
              install -D "$src" "$out/bin/gemini"
              runHook postInstall
            '';
            doInstallCheck = true;
            nativeInstallCheckInputs = [
              writableTmpDirAsHomeHook
            ];
            installCheckPhase = ''
              runHook preInstallCheck
              "$out/bin/gemini" -v
              runHook postInstallCheck
            '';
          });
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
          scratchpad-rs = rustPlatform.buildRustPackage {
            pname = "scratchpad-rs";
            version = "0.1.0";

            src = fetchFromGitHub {
              owner = "m4r1vs";
              repo = "scratchpad-rs";
              rev = "4422543baaa68ac76456b28252e4bd477a3c42c4";
              hash = "sha256-IaEk5pXHxQKQRTB5m7Y8sEjd/ubvV2IoDLdC9VDzOZw=";
            };

            cargoHash = "sha256-nEDsB0nE0cNdC9uCLUHckk2A8kyzyaZw8Hd1xQcki+g=";

            nativeBuildInputs = [
              pkg-config
              cmake
              rustPlatform.bindgenHook
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
