{pkgs, ...}: {
  rofi-search =
    pkgs.writeShellScript "rofi-search"
    ''
      if [ -n "''${1-}" ]; then
        query=$(${pkgs.jq}/bin/jq -rn --arg q "$*" '$q|@uri')
        ${pkgs.brave}/bin/brave --new-window "https://google.com/search?q=$query" &>/dev/null
        exit 0
      fi
    '';
}
