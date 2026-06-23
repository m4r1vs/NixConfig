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

          reforma-fonts = stdenv.mkDerivation {
            name = "Reforma Fonts";
            src = ./assets/fonts/reforma;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p "$out/share/fonts/opentype/Reforma 1918"
              cp $src/1918/*.otf "$out/share/fonts/opentype/Reforma 1918"
              mkdir -p "$out/share/fonts/opentype/Reforma 1969"
              cp $src/1969/*.otf "$out/share/fonts/opentype/Reforma 1969"
              mkdir -p "$out/share/fonts/opentype/Reforma 2018"
              cp $src/2018/*.otf "$out/share/fonts/opentype/Reforma 2018"

              runHook postInstall
            '';
          };

          fcsp-fonts = stdenv.mkDerivation {
            name = "FC Sans Pauli Font";
            src = ./assets/fonts/fcsp;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/fonts/truetype
              cp $src/*.ttf "$out/share/fonts/truetype"

              runHook postInstall
            '';
          };

          apple-color-emoji = stdenv.mkDerivation {
            name = "Apple Color Emoji Font";
            src = fetchurl {
              url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260219-2aa12422/AppleColorEmoji-Linux.ttf";
              hash = "sha256-U1oEOvBHBtJEcQWeZHRb/IDWYXraLuo0NdxWINwPUxg=";
            };
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/fonts/truetype
              cp $src $out/share/fonts/truetype/AppleColorEmoji.ttf

              runHook postInstall
            '';
          };

          samsung-clock-font = stdenv.mkDerivation {
            name = "Samsung Classic Clock Font";
            src = ./assets/fonts/samsung/samsung-clock-classic.ttf;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/fonts/truetype
              cp $src $out/share/fonts/truetype/SamsungClockClassic.ttf

              runHook postInstall
            '';
          };

          sf-pro-nerd-font = stdenv.mkDerivation {
            name = "San Francisco Pro Nerd Font";
            src = fetchFromGitHub {
              owner = "sahibjotsaggu";
              repo = "San-Francisco-Pro-Fonts";
              rev = "8bfea09aa6f1139479f80358b2e1e5c6dc991a58";
              hash = "sha256-mAXExj8n8gFHq19HfGy4UOJYKVGPYgarGd/04kUIqX4=";
            };
            nativeBuildInputs = [
              nerd-font-patcher
              lsd
            ];
            installPhase = ''
              runHook preInstall

              rm SF-Pro-Rounded*.otf

              find \( -name \*.otf \) -execdir nerd-font-patcher --no-progressbars -c {} \;

              mkdir -p "$out/share/fonts/opentype/SFProText Nerd Font"
              cp ./SFProTextNerdFont*.otf "$out/share/fonts/opentype/SFProText Nerd Font"
              mkdir -p "$out/share/fonts/opentype/SFProDisplay Nerd Font"
              cp ./SFProDisplayNerdFont*.otf "$out/share/fonts/opentype/SFProDisplay Nerd Font"

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

          clippy-darwin = pkgsUnstable.clippy-copy;
          gemini-cli = pkgsUnstable.gemini-cli;
          ghostty =
            if isDarwin
            then pkgsUnstable.ghostty-bin
            else pkgsUnstable.ghostty;
          neovim = pkgsUnstable.neovim;
          neovim-unwrapped = pkgsUnstable.neovim-unwrapped;
          opencode = pkgsUnstable.opencode;
          tlrc = pkgsUnstable.tlrc;

          /*
          Temporary Fixes / Updates
          */

          # Until v5 is in nixpkgs (add lua config and hyprland devour/overlay mode)
          # PR: https://github.com/NixOS/nixpkgs/pull/502408
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
              openexr
              luajit
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
          # tmux = tmux.overrideAttrs {
          #   src = pkgs.fetchFromGitHub {
          #     owner = "m4r1vs";
          #     repo = "tmux";
          #     rev = "4e4c003a27e4872e080f5c5f5ade5ba86dc68ae9";
          #     hash = "sha256-H2SXYD2IGQLSOkiyPW2yFnlv905Aw8J4NbPWuTqKt60=";
          #   };
          # };

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

          # # Add fn-X and fn-Y shortcuts to resize/move windows
          yabai = pkgsUnstable.yabai.overrideAttrs {
            version = "7.1.25";
            src = fetchFromGitHub {
              owner = "m4r1vs";
              repo = "yabai";
              rev = "827d9f949846a0d071f5e0ca30408f4abcdd172f";
              hash = "sha256-41xVNlKIk6zt/7fF2biy4ywXgWiDFiHmbxhKzlxdMWw=";
            };
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
