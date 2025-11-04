{pkgs, ...}: {
  rofi-search =
    pkgs.writeShellScript "rofi-search"
    ''
      if [ ! -z "$@" ]; then
        input=$(echo "$@")
        ${pkgs.brave}/bin/brave --new-window "https://google.com/search?q=$*" &>/dev/null
        exit 1
      fi
    '';
}
