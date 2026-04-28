{
  pkgs,
  scripts,
  systemArgs,
  ...
}: let
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  rebuild =
    pkgs.writeShellScript "rebuild"
    (
      if isDarwin
      then # bash
        ''
          sudo darwin-rebuild switch --flake ~/NixConfig/#${systemArgs.hostname} && sudo yabai --load-sa
        ''
      else #bash
        ''
          set -o pipefail
          if [ -f /etc/nixos_active_specialisation ]; then
            SPEC=$(cat /etc/nixos_active_specialisation)
            echo -e "Rebuilding and switching to \e[32mspecialisation\e[0m: \e[33m$SPEC\e[0m"
            sudo nixos-rebuild switch --specialisation "$SPEC" --flake ~/NixConfig/#${systemArgs.hostname}
          else
            echo -e "Rebuilding and switching to \e[32mdefault specialisation\e[0m."
            sudo nixos-rebuild switch --flake ~/NixConfig/#${systemArgs.hostname}
          fi

          if [ $? -eq 0 ]; then
            ${scripts.nixos-notify} -e -h string:synchronous:rebuild "System has been rebuilt" "and I've applied the latest configuration"
          else
            echo -e "\a"
          fi
        ''
    );
}
