{pkgs, ...}: {
  term-file-chooser =
    pkgs.writeShellScript "term-file-chooser"
    ''
      multiple="$1"
      directory="$2"
      save="$3"
      path="$4"
      out="$5"
      cmd="yazi"

      escape_args() {
        printf '%s' "$1" | sed -e "s/[()&|;]/\\\\&/g" -e 's/ /\\ /g'
      }

      if [ "$save" = "1" ]; then
        # /usr/bin/touch $path
        set -- --chooser-file="$(escape_args "$out")" --cwd-file="$(escape_args "$path")"
        printf '%s' '
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      !!!                 === WARNING! ===                 !!!
      !!! The contents of *whatever* file you open last in !!!
      !!! yazi will be *overwritten*!                      !!!
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      Instructions:
      1) Move this file wherever you want.
      2) Rename the file if needed.
      3) Confirm your selection by opening the file, for
         example by pressing <Enter>.

      Notes:
      1) This file is provided for your convenience. You
         could delete it and choose another file to overwrite
         that, for example.
      2) If you quit yazi without opening a file, this file
         will be removed and the save operation aborted.
      ' > "$path"
      elif [ "$directory" = "1" ]; then
        set -- --cwd-file="$(escape_args "$out")"
      elif [ "$multiple" = "1" ]; then
        set -- --chooser-file="$(escape_args "$out")"
      else
        set -- --chooser-file="$(escape_args "$out")"
      fi

      ${pkgs.ghostty}/bin/ghostty --class=ghostty.yazi -e $cmd "$(escape_args "$@") $(escape_args "$path")"
      if [ "$save" = "1" ] && [ ! -s "$out" ]; then
        rm "$path"
      fi
    '';
}
