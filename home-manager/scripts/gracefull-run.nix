{
  pkgs,
  scripts,
  config,
  lib,
  ...
}: {
  gracefull-run = command:
    pkgs.writeShellScript "gracefull-run"
    ''
      hour=$(${pkgs.coreutils}/bin/date +%H)

      if (( hour >= 5 && hour < 13 )); then
        GOODBYE_STRING="Goodbye  "
      elif (( hour >= 13 && hour < 16 )); then
        GOODBYE_STRING="Enjoy your Day  "
      elif (( hour >= 16 && hour < 21 )); then
        GOODBYE_STRING="Enjoy your Evening 󰖚 "
      elif (( hour >= 21 || hour < 5 )); then
        GOODBYE_STRING="Goodnight, Nightowl 󰖔 "
      else
        GOODBYE_STRING="Goodbye, Time-traveller  "
      fi

      ${scripts.nixos-notify} -u low -e -t 10000 -h string:synchronous:startup-script "$GOODBYE_STRING" "I'm gracefully closing everything..."

      ${lib.optionalString (config.configured.system-sounds.enable && config.configured.system-sounds.shutdown.enable) ''
        ${pkgs.mpv}/bin/mpv --no-video --no-config --volume=80 --no-terminal ${config.configured.system-sounds.shutdown.soundFile} &
      ''}

      ${pkgs.psmisc}/bin/killall -q -w brave

      ${command}
    '';
}
