{pkgs, ...}: {
  webcam-privacy =
    pkgs.writeShellScript "webcam-privacy"
    ''
      if command -v ${pkgs.psmisc}/bin/fuser /dev/video0 &>/dev/null && ${pkgs.psmisc}/bin/fuser /dev/video0 &>/dev/null; then
          echo " 󰄀"
      fi
      exit 0
    '';
}
