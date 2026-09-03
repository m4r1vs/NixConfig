{pkgs, ...}: {
  ls-git =
    pkgs.writeShellScript "ls-git"
    ''
      # ls-git: like `ls`, but only lists git repositories together with their branch.
      # Usage: ls-git [-a] [DIRECTORY]
      shopt -s nullglob

      show_hidden=0
      target="."
      for arg in "$@"; do
        case "$arg" in
          -a | --all) show_hidden=1 ;;
          -h | --help)
            echo "Usage: ls-git [-a] [DIRECTORY]"
            exit 0
            ;;
          *) target="$arg" ;;
        esac
      done

      if [ ! -d "$target" ]; then
        echo "ls-git: cannot access '$target': No such directory" >&2
        exit 1
      fi

      # Colors only when writing to a terminal, like ls.
      if [ -t 1 ]; then
        blue=$'\033[34m'
        bold=$'\033[1m'
        green=$'\033[32m'
        grey=$'\033[90m'
        reset=$'\033[0m'
      else
        blue="" bold="" green="" grey="" reset=""
      fi

      [ "$show_hidden" -eq 1 ] && shopt -s dotglob

      list_repos() {
        for dir in "$target"/*/; do
          dir="''${dir%/}"
          name="''${dir##*/}"
          [ -e "$dir/.git" ] || continue

          branch=$(${pkgs.git}/bin/git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null) \
            || branch=$(${pkgs.git}/bin/git -C "$dir" rev-parse --short HEAD 2>/dev/null) \
            || branch="(no commits)"

          printf '%s\t%s\n' "$name" "$branch"
        done
      }

      # Sort case-insensitively by name, like ls does.
      list_repos | sort -f -t $'\t' -k1,1 | while IFS=$'\t' read -r name branch; do
        printf '%s\n' "''${blue} ''${bold}''${name}''${reset} ''${grey}—''${reset} ''${green} ''${branch}''${reset}"
      done
    '';
}
