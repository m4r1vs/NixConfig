{pkgs, ...}: {
  date-trivia =
    pkgs.writeShellScript "date-trivia"
    ''
      CURL_OUTPUT=$(${pkgs.curl}/bin/curl -s -w "%{http_code}" "http://numbersapi.com/$(date +%m/%d)/date")
      STATUS="''${CURL_OUTPUT: -3}"
      DATA="''${CURL_OUTPUT::-3}"

      if [ "$STATUS" -eq 200 ]; then
        echo "$DATA"
      else
        echo "In the year $(date "%Y"), on $(date "+%B %d"), Marius had no Internet."
      fi
    '';
}
