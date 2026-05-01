{
  pkgs,
  config,
  lib,
  systemArgs,
  inputs,
  ...
}:
with lib; let
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
      (final: prev:
        with prev; {
          /*
          Own packages / not in nixpkgs
          */

          atai = inputs.atai.packages.${stdenv.hostPlatform.system}.atai;
          golazo = inputs.golazo.packages.${stdenv.hostPlatform.system}.default;
          hyprland-which-key = inputs.hyprland-which-key.packages.${stdenv.hostPlatform.system}.default;

          # TODO: add PR to add to nixpkgs
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

          # TODO: add PR to add to nixpkgs
          skhd-zig = with pkgs;
            stdenv.mkDerivation {
              pname = "skhd-zig";
              version = "0.0.17";
              buildInputs = [
                lsd
              ];
              src = fetchTarball {
                url = "https://github.com/jackielii/skhd.zig/releases/download/v0.0.17/skhd-arm64-macos.tar.gz";
                sha256 = "sha256:1d4z1a83b77hfl0ddpphrfdzq35mniqm7ssifsg9qyxr7llzcfk0";
              };
              installPhase = ''
                runHook preInstall
                mkdir -p $out/bin
                cp ./skhd-arm64-macos $out/bin/skhd
                runHook postInstall
              '';
            };

          /*
          From unstable/master Nixpkgs
          */

          colima = pkgsUnstable.colima;
          direnv = pkgsUnstable.direnv;
          gemini-cli = pkgsUnstable.gemini-cli;
          ghostty =
            if isDarwin
            then pkgsUnstable.ghostty-bin
            else pkgsUnstable.ghostty;
          hyprlock = pkgsUnstable.hyprlock;
          mise = pkgsUnstable.mise;
          neovim = pkgsUnstable.neovim;
          neovim-unwrapped = pkgsUnstable.neovim-unwrapped;
          opencode = pkgsUnstable.opencode;
          swaynotificationcenter = pkgsUnstable.swaynotificationcenter;
          ty = pkgsUnstable.ty;
          waybar = pkgsUnstable.waybar;
          yazi = pkgsUnstable.yazi;
          yaziPlugins = pkgsUnstable.yaziPlugins;

          /*
          Temporary Fixes / Updates
          */

          # Until v5 is in nixpkgs (add lua config and hyprland devour/overlay mode)
          # Depends on https://github.com/NixOS/nixpkgs/pull/502834
          swayimg = pkgsUnstable.swayimg.overrideAttrs (finalAttrs: {
            version = "v5.2";
            buildInputs = [
              bash-completion
              wayland
              wayland-protocols
              json_c
              libxkbcommon
              fontconfig
              giflib
              libheif
              libjpeg
              libwebp
              libtiff
              librsvg
              libpng
              libjxl
              libexif
              libavif
              libsixel
              libraw
              libdrm
              exiv2
              pkgsUnstable.luajit
              (pkgsUnstable.openexr.overrideAttrs {
                version = "3.4.10"; # TODO: update to 3.4.11
                src = fetchFromGitHub {
                  owner = "AcademySoftwareFoundation";
                  repo = "openexr";
                  rev = "v3.4.10";
                  hash = "sha256-jXio+PvagKTR8NjcYIQ/j8LOMNc/0sQBuaixKk/0V3k=";
                };
              })
            ];
            src = fetchFromGitHub {
              owner = "artemsen";
              repo = "swayimg";
              tag = "v5.2";
              hash = "sha256-aDZ7Ka8uKVLzEwxS2CT5fRFNDf9z/LO3bB0dCMz1Mf0=";
            };
          });

          /*
          Own Forks
          */

          # Add support for zsh-vi-mode
          oh-my-posh = pkgsUnstable.buildGo126Module (finalAttrs: {
            pname = "oh-my-posh";
            version = "29.9.1";

            src = pkgsUnstable.fetchFromGitHub {
              owner = "m4r1vs";
              repo = "oh-my-posh";
              rev = "a483019234881c039e5b51ac0d61094bbd3d6857";
              hash = "sha256-1axqKMFHUGApH+kRKHaxo4csnJmopEWb1BDp+NeZElc=";
            };

            vendorHash = "sha256-0pxVRDXdvImA2B3yonnl01Y1UuEKNb6UCVH4enohu2I=";

            sourceRoot = "${finalAttrs.src.name}/src";

            ldflags = [
              "-s"
              "-w"
              "-X github.com/m4r1vs/oh-my-posh/src/build.Version=${finalAttrs.version}"
              "-X github.com/m4r1vs/oh-my-posh/src/build.Date=1970-01-01T00:00:00Z"
            ];

            tags = [
              "netgo"
              "osusergo"
              "static_build"
            ];

            postPatch = ''
              # these tests requires internet access
              rm cli/image/image_test.go config/migrate_glyphs_test.go cli/upgrade/notice_test.go segments/upgrade_test.go
            '';

            postInstall = ''
              mv $out/bin/{src,oh-my-posh}
              mkdir -p $out/share/oh-my-posh
              cp -r $src/themes $out/share/oh-my-posh/
            '';

            meta = {
              description = "Prompt theme engine for any shell";
              mainProgram = "oh-my-posh";
              license = lib.licenses.mit;
            };
          });

          # Make border between panes invisible
          tmux = tmux.overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "m4r1vs";
              repo = "tmux";
              rev = "4e4c003a27e4872e080f5c5f5ade5ba86dc68ae9";
              hash = "sha256-H2SXYD2IGQLSOkiyPW2yFnlv905Aw8J4NbPWuTqKt60=";
            };
          };

          # Add title, add playing animation and fix podcasts not loading
          spotify-player = rustPlatform.buildRustPackage {
            pname = "spotify-player";
            version = "0.23.0";

            src = fetchFromGitHub {
              owner = "m4r1vs";
              repo = "spotify-player";
              rev = "e5f8b31c829cea9c356d539ffc87e05842b382bd";
              hash = "sha256-kBuqRlop8abuNn4Q7y+ljXKyVE/gx1Of/ynUhMkvKuM=";
            };

            cargoHash = "sha256-mD1UJn3LjX88Ht6QUpPO9lu9WiCec5+qUphtLoCjiXg=";

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

          # Add fn-X and fn-Y shortcuts to resize/move windows
          yabai = pkgsUnstable.yabai.overrideAttrs {
            version = "7.1.24";
            src = pkgs.fetchzip {
              url = "https://github.com/m4r1vs/yabai/raw/19efbf5bdf77e19f87202fb275dfa2adcd2ccd6e/bin.tar.gz";
              hash = "sha256-la2muT7NjkQoYvypybCP0fCymITEK8kSRvk+8bva7w0=";
            };
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp ./yabai $out/bin/yabai
              runHook postInstall
            '';
          };

          /*
          Mods to packages
          */

          rofi-unwrapped = rofi-unwrapped.overrideAttrs (oldAttrs: {
            patchPhase = ''
              echo "NoDisplay=true" >> ./data/rofi-theme-selector.desktop
              echo "NoDisplay=true" >> ./data/rofi.desktop
            '';
          });

          polybar = polybar.override {
            nlSupport = true; # networking
            iwSupport = true; # WiFi
            i3Support = true;
            pulseSupport = true;
            alsaSupport = true;
            githubSupport = true;
          };
        })
    ];
  };
}
