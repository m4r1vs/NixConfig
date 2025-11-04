{pkgs, ...}: {
  mediaplayer-wrapper =
    pkgs.writeShellScript "mediaplayer-wrapper"
    ''
      ${pkgs.waybar-mpris}/bin/waybar-mpris --position --autofocus --play "" --pause "" | while read -r line; do
          output=$(echo "$line" | ${pkgs.jq}/bin/jq -c 'if .text == " " then {} else . end')
          echo "$output"
      done
    '';
}
