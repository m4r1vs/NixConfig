{
  pkgs,
  host,
  ...
}: {
  rofi-search =
    pkgs.writeShellScript "rofi-search"
    ''
      if [ -n "''${1-}" ]; then
        query=$(${pkgs.jq}/bin/jq -rn --arg q "$*" '$q|@uri')
        ${
        if host.isDarwin
        then ''/usr/bin/open -na "Brave Browser" --args --new-window "https://google.com/search?q=$query" &>/dev/null || /usr/bin/open "https://google.com/search?q=$query" &>/dev/null''
        else ''${pkgs.brave}/bin/brave --new-window "https://google.com/search?q=$query" &>/dev/null''
      }
        exit 0
      fi
    '';
}
