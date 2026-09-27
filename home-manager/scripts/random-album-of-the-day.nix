{
  host,
  pkgs,
  scripts,
  ...
}: let
  inherit (host) isDarwin;
in {
  random-album-of-the-day =
    pkgs.writeShellScript "random-album-of-the-day"
    ''
      set -o pipefail

      ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -u low -h string:synchronous:random-album -e "Connecting to Bandcamp..."

      if ! HTML=$(${pkgs.curl}/bin/curl -fsS --connect-timeout 3 --max-time 10 "https://daily.bandcamp.com/album-of-the-day"); then
        ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -e "Failed to reach Bandcamp"
        exit 0
      fi
      RANDOM_ALBUM_LINE=$(echo "$HTML" | grep '<a class="title" href="/album-of-the-day/' | ${pkgs.coreutils}/bin/shuf -n 1)
      RANDOM_ALBUM=$(echo "$RANDOM_ALBUM_LINE" | awk -F '">|</' '{print $3}' | sed -e 's/“//g ; s/”//g')
      ALBUM_PATH=$(echo "$RANDOM_ALBUM_LINE" | sed -n 's/.*href="\([^"]*\)".*/\1/p')
      exit_code="$?"

      if [ -z "$RANDOM_ALBUM" ] || [ "$exit_code" -ne 0 ]; then
        ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -e "Failed to query Bandcamp" "(Unexpected return: \"$RANDOM_ALBUM\")"
        exit 0
      fi

      id=$(${pkgs.spotify-player}/bin/spotify_player search "$RANDOM_ALBUM" | ${pkgs.jq}/bin/jq -r '.albums.[0].id // empty')
      exit_code="$?"

      if [ -z "$id" ] || [ "$exit_code" -ne 0 ]; then
        ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -e "Could not find \"$RANDOM_ALBUM\" on Spotify"
        exit 0
      fi

      ${pkgs.spotify-player}/bin/spotify_player playback start context --id "$id" album >/dev/null
      exit_code="$?"

      if [[ "$exit_code" -ne 0 ]]; then
        ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -e "Failed to start Playback of" "\"$RANDOM_ALBUM\""
        exit 0
      fi

      ${
        if (!isDarwin)
        then
          /*
          bash
          */
          ''
            RESPONSE=$(${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -u low -h string:synchronous:random-album --action="open=Open on Bandcamp" "Playing a random Album of the Day:" "$RANDOM_ALBUM")

            if [[ "$RESPONSE" == *"open"* ]]; then
              ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-headphones.svg} -u low -e -t 2000 "$(${pkgs.xdg-utils}/bin/xdg-open "https://daily.bandcamp.com$ALBUM_PATH")"
            fi

            exit 0''
        else
          /*
          bash
          */
          ''
            /usr/bin/open "https://daily.bandcamp.com$ALBUM_PATH"
          ''
      }
    '';
}
