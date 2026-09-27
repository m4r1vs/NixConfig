{pkgs, ...}: {
  term-file-chooser =
    pkgs.writeShellScript "term-file-chooser"
    ''
      set -eu

      # Contract (xdg-desktop-portal-termfilechooser(5)):
      #   $1 multiple  $2 directory  $3 save  $4 suggested path  $5 output file  $6 loglevel
      # The suggested path comes from the (possibly sandboxed) app, so it must
      # never pass through a shell: arguments are handed to ghostty as argv.
      directory="$2"
      path="$4"
      out="$5"

      if [ "''${6:-0}" -ge 4 ]; then
        set -x
      fi

      args=(--chooser-file="$out")
      if [ "$directory" = "1" ]; then
        args+=(--cwd-file="$out.1")
      fi

      rc=0
      ${pkgs.ghostty}/bin/ghostty --class=ghostty.yazi -e \
        ${pkgs.yazi}/bin/yazi "''${args[@]}" -- "$path" || rc=$?

      if [ "$directory" = "1" ]; then
        if [ ! -s "$out" ] && [ -s "$out.1" ]; then
          cat -- "$out.1" > "$out"
        fi
        rm -f -- "$out.1"
      fi

      exit "$rc"
    '';
}
