{
  pkgs,
  scripts,
  ...
}: {
  gracefull-systemctl =
    pkgs.writeShellScript "gracefull-systemctl"
    ''
      ${scripts.nixos-notify} -e "Gracefully Performing Action:" "$1"
      ${pkgs.psmisc}/bin/killall -q -w brave
      systemctl $1
    '';
}
