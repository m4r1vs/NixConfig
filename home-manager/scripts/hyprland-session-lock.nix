{
  pkgs,
  lib,
  helpers,
  ...
}: {
  # Locks a fresh Hyprland session unless greetd's tuigreet already
  # authenticated it (see nixos-modules/hyprland.nix). Fails closed: anything
  # but an explicit HYPR_GREETED gets the lock screen.
  hyprland-session-lock = helpers.mkScript {
    name = "hyprland-session-lock";
    runtimeInputs = [pkgs.hyprland pkgs.util-linux];
    text = ''
      if [ -n "''${HYPR_GREETED-}" ]; then
        exit 0
      fi
      # A crashing hyprlock must end the session instead of leaving it open
      status=0
      ${lib.getExe pkgs.hyprlock} || status=$?
      if [ "$status" -ne 0 ]; then
        logger -t hyprland-session-lock "hyprlock exited with $status, ending the session"
        hyprctl dispatch exit
      fi
    '';
  };
}
