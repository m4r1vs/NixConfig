{pkgs, ...}: {
  term-file-chooser =
    pkgs.writeShellScript "term-file-chooser"
    ''
      set -e

      if [ "$6" -ge 4 ]; then
        set -x
      fi

      multiple="$1"
      directory="$2"
      save="$3"
      path="$4"
      out="$5"

      cmd="${pkgs.yazi}/bin/yazi"
      termcmd="${pkgs.ghostty}/bin/ghostty --class=ghostty.yazi -e"

      if [ "$save" = "1" ]; then
        # save a file
        set -- --chooser-file="$out" "\"$path\""
      elif [ "$directory" = "1" ]; then
        # upload files from a directory
        set -- --chooser-file="$out" --cwd-file="$out"".1" "\"$path\""
      elif [ "$multiple" = "1" ]; then
        # upload multiple files
        set -- --chooser-file="$out" "\"$path\""
      else
        # upload only 1 file
        set -- --chooser-file="$out" "\"$path\""
      fi

      command="$termcmd $cmd"
      for arg in "$@"; do
        command="$command $arg"
      done

      echo "$command" > /tmp/termfilechooser_command.txt

      sh -c "$command"

      if [ "$directory" = "1" ]; then
        if [ ! -s "$out" ] && [ -s "$out"".1" ]; then
          cat "$out"".1" > "$out"
          rm "$out"".1"
        else
          rm "$out"".1"
        fi
      fi
    '';
}
