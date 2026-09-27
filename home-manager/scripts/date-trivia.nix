{
  pkgs,
  helpers,
  ...
}: {
  date-trivia = helpers.mkScript {
    name = "date-trivia";
    runtimeInputs = with pkgs; [curl coreutils];
    text = ''
      # No network: curl fails and the status is "000", handled below
      CURL_OUTPUT=$(curl -s --connect-timeout 3 --max-time 5 -w "%{http_code}" "http://number-trivia.com/$(date +%m/%d)/date" || true)
      STATUS="''${CURL_OUTPUT: -3}"
      DATA="''${CURL_OUTPUT::-3}"

      if [ "$STATUS" = 200 ]; then
        echo -n "$DATA"
      else
        echo -n "In the year $(date +%Y), on $(date "+%B %d"), Marius had no Internet."
      fi
    '';
  };
}
