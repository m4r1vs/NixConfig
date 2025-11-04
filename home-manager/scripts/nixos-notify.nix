{
  pkgs,
  systemArgs,
  ...
}: {
  nixos-notify =
    pkgs.writeShellScript "nixos-notify"
    ''
      ${pkgs.libnotify}/bin/notify-send --app-name="${systemArgs.hostname}" "$@"
    '';
}
