{
  pkgs,
  scripts,
  helpers,
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

      ${helpers.playSound "shutdown"}

      ${pkgs.psmisc}/bin/killall -q -w brave

      ${command}
    '';
}
