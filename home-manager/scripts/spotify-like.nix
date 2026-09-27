{
  pkgs,
  scripts,
  ...
}: {
  spotify-like = pkgs.writeShellScript "spotify-like" ''
    ${pkgs.spotify-player}/bin/spotify_player like
    NAME="$(${pkgs.spotify-player}/bin/spotify_player get key playback | ${pkgs.jq}/bin/jq -r '.item.name // empty')"
    if [ -z "''${NAME:-}" ]; then
      NAME="FAILED TO GET NAME OF TRACK"
    fi
    ${scripts.nixos-notify} \
      -i ${../../assets/nix-flake/with-headphones.svg} \
      -u low \
      -h string:synchronous:spotify-like \
      -t 3200 \
      -e \
      "Liked on  Spotify:" \
      "$NAME"
  '';
}
