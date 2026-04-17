{
  pkgs,
  scripts,
  config,
  lib,
  ...
}: {
  gracefull-systemctl =
    pkgs.writeShellScript "gracefull-systemctl"
    ''
      ${scripts.nixos-notify} -e "Gracefully Performing Action:" "$1"
      ${pkgs.psmisc}/bin/killall -q -w brave
      ${lib.optionalString (config.configured.system-sounds.enable && config.configured.system-sounds.shutdown.enable) ''
        ${pkgs.mpv}/bin/mpv --no-video --no-config --volume=80 --no-terminal ${config.configured.system-sounds.shutdown.soundFile}
      ''}
      systemctl $1
    '';
}
