{pkgs, ...}: {
  mediaplayer-wrapper =
    pkgs.writeShellScript "mediaplayer-wrapper"
    ''
      ${pkgs.waybar-mpris}/bin/waybar-mpris --position --autofocus --play "󰐊" --pause "󰏤" --order "SYMBOL:TITLE:ARTIST" \
        | ${pkgs.jq}/bin/jq --unbuffered -R -c 'fromjson? | if .text == "󰐊 " then {} else . end'
    '';
}
