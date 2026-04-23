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
          mise = pkgsUnstable.mise;
          neovim = pkgsUnstable.neovim;
          neovim-unwrapped = pkgsUnstable.neovim-unwrapped;
          opencode = pkgsUnstable.opencode;
          swaynotificationcenter = pkgsUnstable.swaynotificationcenter;
          ty = pkgsUnstable.ty;
          yazi = pkgsUnstable.yazi;
          yaziPlugins = pkgsUnstable.yaziPlugins;

          /*
          Temporary Fixes / Updates
          */

          # https://github.com/NixOS/nixpkgs/pull/463023
          eb-garamond = eb-garamond.overrideAttrs {
            nativeBuildInputs = [
              fontforge
              python3
              ttfautohint-nox
            ];
          };

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
              rev = "a990349944fa8bc719d144538bc3351defc471aa";
              hash = "sha256-x8vpD++jKcGMLMEHAkHQS7rYmiowhPfRYXZgoMv5chU=";
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
            version = "7.1.18";
            src = pkgs.fetchzip {
              url = "https://github.com/m4r1vs/yabai/raw/48c4fac997579ee007e5486f846f50f199263c3b/bin.tar.gz";
              hash = "sha256-zyWS5St2xIl40LB5yxYhoy8oI+jK+Wnvlj5UoezrSmw=";
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
