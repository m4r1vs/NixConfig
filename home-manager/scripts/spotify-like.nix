{
  pkgs,
  scripts,
  helpers,
  ...
}: {
  spotify-like = helpers.mkScript {
    name = "spotify-like";
    runtimeInputs = [pkgs.spotify-player pkgs.jq];
    text = ''
      spotify_player like || true
      NAME="$(spotify_player get key playback | jq -r '.item.name // empty' || true)"
      if [ -z "$NAME" ]; then
        NAME="FAILED TO GET NAME OF TRACK"
      fi
      ${scripts.nixos-notify} \
        -i ${../../assets/nix-flake/with-headphones.svg} \
        -u low \
        -h string:synchronous:spotify-like \
        -t 3200 \
        -e \
        "Liked on  Spotify:" \
        "$NAME"
    '';
  };
}
