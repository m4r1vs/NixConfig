{
  pkgs,
  pkgs_main,
  ...
}: {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      /*
      Temporary Fixes / Updates
      */
      (final: prev: {
        libfprint-tod = prev.libfprint-tod.overrideAttrs (oldAttrs: {
          buildInputs = oldAttrs.buildInputs ++ [prev.nss];
        });
      })
      (final: prev: {
        neovim-unwrapped = pkgs_main.neovim-unwrapped;
      })
      (final: prev: {
        hypr-dynamic-cursors = pkgs_main.hyprlandPlugins.hypr-dynamic-cursors;
      })
      (final: prev: {
        tmux = prev.tmux.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "m4r1vs";
            repo = "tmux";
            rev = "master";
            hash = "sha256-wSZ30YSB8SD18ynwQvSAaNbA6q3eShtZJI1Nm0MN82A=";
          };
        };
      })
      (final: prev: {
        hyprfocus = prev.hyprlandPlugins.hyprfocus.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "daxisunder";
            repo = "hyprfocus";
            rev = "main";
            hash = "sha256-ST5FFxyw5El4A7zWLaWbXb9bD9C/tunU+flmNxWCcEY=";
          };
          meta.broken = false;
        };
      })
      /*
      Own Forks
      */
      (final: prev: {
        spotify-player =
          (prev.spotify-player.override {
            withStreaming = true;
            withDaemon = true;
            withAudioBackend = "pulseaudio";
            withMediaControl = true;
            withImage = true;
            withNotify = true;
            withSixel = false;
            withFuzzy = true;
          })
          .overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "m4r1vs";
              repo = "spotify-player";
              rev = "master";
              hash = "sha256-Ck8ma6TTyeCu7XgpiEnrVSFBcZIDco+9k7Fs2hqIJxo=";
            };
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
    ];
  };
}
