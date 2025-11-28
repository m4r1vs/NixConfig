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
      (final: prev:
        with prev; {
          /*
          Own packages / not in nixpkgs
          */
          atai = inputs.atai.packages.${stdenv.hostPlatform.system}.atai;
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

          /*
          From unstable/master Nixpkgs
          */
          ghostty =
            if isDarwin
            then pkgsUnstable.ghostty-bin
            else pkgsUnstable.ghostty;
          aerospace = pkgsUnstable.aerospace;
          minecraftServers = pkgsUnstable.minecraftServers;
          yabai = pkgsUnstable.yabai;
          yazi = pkgsUnstable.yazi;
          yaziPlugins = pkgsUnstable.yaziPlugins;
          gemini-cli = pkgsMaster.gemini-cli;

          /*
          Temporary Fixes / Updates
          */
          #  https://github.com/NixOS/nixpkgs/pull/463023
          eb-garamond = eb-garamond.overrideAttrs {
            nativeBuildInputs = [
              fontforge
              python3
              ttfautohint-nox
            ];
          };
          # TODO: test if this has been fixed
          hyprlandPlugins =
            hyprlandPlugins
            // {
              hyprfocus = hyprlandPlugins.hyprfocus.overrideAttrs {
                src = pkgs.fetchFromGitHub {
                  owner = "daxisunder";
                  repo = "hyprfocus";
                  rev = "516e36572f50cca631e7e572249b3716c3602176";
                  hash = "sha256-TnsdJxxBFbc54T43UP+7mmZkErc7NrZ31C0QNePdDrE=";
                };
                meta.broken = false;
              };
            };
          # Removes a line that quits containerd when sandbox is missing
          # TODO: test if it has been fixed by the sandbox overwrite
          containerd = containerd.overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "containerd";
              repo = "containerd";
              rev = "release/2.2";
              hash = "sha256-XLg4oh4AZDboHm9YkSDwlNuYxvvS0yFIXaorgfNGFWU=";
            };
          };

          /*
          Own Forks
          */
          tmux = tmux.overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "m4r1vs";
              repo = "tmux";
              rev = "159971c823a31d989925f8ad82774bb949f97e20";
              hash = "sha256-TP0jL+oA/qHHlOYG2zyDZmSxa39+UgLWM2NvPEoVXyE=";
            };
          };
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

          /*
          Mods to packages
          */
          gimp-with-plugins = gimp3-with-plugins;
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

          /*
          Specialisations
          */
          rofi = lib.mkIf isWayland rofi-wayland;
        })
    ];
  };
}
