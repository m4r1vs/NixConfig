{
  pkgs,
  scripts,
  ...
}: {
  spotify-like = pkgs.writeShellScript "spotify-like" ''
    ${pkgs.spotify-player}/bin/spotify_player like && ${scripts.nixos-notify} -e -h string:synchronous:spotify-like -t 1800 "Liked currently playing Track on Spotify"
  '';
}
