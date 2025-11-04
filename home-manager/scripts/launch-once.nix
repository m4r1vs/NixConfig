{pkgs, ...}: {
  launch-once = {
    command,
    grep,
    useHypr ? false,
  }:
    pkgs.writeShellScript "launch-once"
    (
      if useHypr
      then
        /*
        bash
        */
        ''
          if ${pkgs.hyprland}/bin/hyprctl clients | grep -q "${grep}" > /dev/null; then
            exit 0
          else
            ${command} &
          fi
        ''
      else
        /*
        bash
        */
        ''
          if ${pkgs.procps}/bin/pgrep -f "${grep}" > /dev/null; then
            exit 0
          else
            ${command} &
            exit 0
          fi
        ''
    );
}
