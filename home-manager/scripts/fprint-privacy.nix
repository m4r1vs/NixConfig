{pkgs, ...}: {
  fprint-privacy =
    pkgs.writeShellScript "fprint-privacy"
    ''
      pgrep -flx "${pkgs.fprintd-tod}/libexec/fprintd" &> /dev/null
      if [ $? -eq 0 ]; then
        echo "󰈷"
      fi
      exit 0
    '';
}
