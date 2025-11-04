{
  pkgs,
  scripts,
  ...
}: {
  random-album-of-the-day =
    pkgs.writeShellScript "random-album-of-the-day"
    ''
      set -o pipefail

      HTTP=$(${pkgs.curl}/bin/curl -s "https://daily.bandcamp.com/album-of-the-day")
      random_album=$(echo "$HTTP" | grep '<a class="title" href="/album-of-the-day/' | shuf -n 1 | awk -F '">|</' '{print $3}' | sed -e 's/“//g ; s/”//g')
      exit_code="$?"

      if [ -z "$random_album" ] || [ "$exit_code" -ne 0 ]; then
        ${scripts.nixos-notify} -e "Failed to query Bandcamp's" "Album of the Day (got \"$random_album\")"
        exit 0
      fi

      id=$(${pkgs.spotify-player}/bin/spotify_player search "$random_album" | ${pkgs.jq}/bin/jq -r '.albums.[0].id')
      exit_code="$?"

      if [ -z "$id" ] || [ "$exit_code" -ne 0 ]; then
        ${scripts.nixos-notify} -e "Failed to search Spotify for" "\"$random_album\""
        exit 0
      fi

      ${pkgs.spotify-player}/bin/spotify_player playback start context --id $id album >/dev/null
      exit_code="$?"

      if [[ "$exit_code" -ne 0 ]]; then
        ${scripts.nixos-notify} -e "Failed to start Playback of" "\"$random_album\""
        exit 0
      fi

      RESPONSE=$(${scripts.nixos-notify} --action="open=Open on Bandcamp" "Playing a random Album of the Day:" "\"$random_album\"")

      if [[ "$RESPONSE" == *"open"* ]]; then
        ALBUM_PATH=$(echo "$HTTP" | grep '<a class="title" href="/album-of-the-day/' | shuf -n 1 | awk -F 'href="|">' '{print $3}')
        ${scripts.nixos-notify} -e -t 1000 "$(${pkgs.xdg-utils}/bin/xdg-open "https://daily.bandcamp.com$ALBUM_PATH")"
      fi

      exit 0
    '';
}
