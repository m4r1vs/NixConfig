{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.raycast-scripts;
in {
  options.configured.raycast-scripts = {
    enable = mkEnableOption "Enable Raycast scripts";
  };

  config = mkIf cfg.enable {
    home = {
      activation.unlink-raycast-scripts = lib.hm.dag.entryAfter ["writeBoundary"] ''
        cat ~/.raycast-scripts/spotify-tui.stored-in-nix > .raycast-scripts/spotify.sh
        cat ~/.raycast-scripts/yazi.stored-in-nix > .raycast-scripts/yazi.sh
      '';
      file = {
        ".raycast-scripts/yazi.stored-in-nix".text =
          # bash
          ''
            #!/bin/bash

            # Required parameters:
            # @raycast.schemaVersion 1
            # @raycast.title Floating Yazi
            # @raycast.mode silent

            # Optional parameters:
            # @raycast.icon 🗄️

            # Documentation:
            # @raycast.description Open Ghostty terminal with the Yazi file manager

            if ${pkgs.aerospace}/bin/aerospace list-windows --focused | grep -q "floating_yazi"; then
              ${pkgs.aerospace}/bin/aerospace workspace-back-and-forth
              exit 0
            fi

            if ${pkgs.aerospace}/bin/aerospace list-windows --all | grep -q "floating_yazi"; then
              ${pkgs.aerospace}/bin/aerospace workspace y
              exit 0
            fi

            ${pkgs.ghostty}/bin/ghostty --title=floating_yazi -e zsh -c "${pkgs.yazi}/bin/yazi ~/Downloads" >/dev/null 2>&1 &
            for i in {1..10}; do
              if ${pkgs.aerospace}/bin/aerospace list-windows --focused | grep -q "floating_yazi"; then
                break
              fi
              sleep 0.03
            done

            ${pkgs.aerospace}/bin/aerospace summon-workspace y> /dev/null 2>&1
            ${pkgs.aerospace}/bin/aerospace workspace y> /dev/null 2>&1

            open -g "raycast://extensions/raycast/window-management/top-center-two-thirds"
          '';
        ".raycast-scripts/spotify-tui.stored-in-nix".text =
          # bash
          ''
            #!/bin/bash

            # Required parameters:
            # @raycast.schemaVersion 1
            # @raycast.title Spotify TUI
            # @raycast.mode silent

            # Optional parameters:
            # @raycast.icon 🎶

            if ${pkgs.aerospace}/bin/aerospace list-windows --focused | grep -q "floating_spotify"; then
              ${pkgs.aerospace}/bin/aerospace workspace-back-and-forth
              exit 0
            fi

            if ${pkgs.aerospace}/bin/aerospace list-windows --all | grep -q "floating_spotify"; then
              ${pkgs.aerospace}/bin/aerospace workspace s
              exit 0
            fi

            ${pkgs.ghostty}/bin/ghostty --title=floating_spotify -e zsh -c "${pkgs.spotify-player}/bin/spotify_player" >/dev/null 2>&1 &
            for i in {1..10}; do
              if ${pkgs.aerospace}/bin/aerospace list-windows --focused | grep -q "floating_spotify"; then
                break
              fi
              sleep 0.03
            done

            ${pkgs.aerospace}/bin/aerospace summon-workspace s> /dev/null 2>&1
            ${pkgs.aerospace}/bin/aerospace workspace s> /dev/null 2>&1

            open -g "raycast://extensions/raycast/window-management/top-center-two-thirds"
          '';
      };
    };
  };
}
