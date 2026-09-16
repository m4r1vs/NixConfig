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
          export PATH="${pkgs.nix-output-monitor}/bin:$PATH"
          ${pkgs.nh}/bin/nh darwin switch -a ~/NixConfig -H ${systemArgs.hostname} && sudo yabai --load-sa
        ''
      else #bash
        ''
          set -o pipefail

          # Ensure nix-output-monitor is in PATH so nh can use it for rich output
          export PATH="${pkgs.nix-output-monitor}/bin:$PATH"

          if [ -f /etc/nixos_active_specialisation ]; then
            SPEC=$(cat /etc/nixos_active_specialisation)
            echo -e "Rebuilding and switching to \e[32mspecialisation\e[0m: \e[33m$SPEC\e[0m\n"
            ${pkgs.nh}/bin/nh os switch -a ~/NixConfig -H ${systemArgs.hostname} -- --specialisation "$SPEC"
          else
            echo -e "Rebuilding and switching to \e[32mdefault specialisation\e[0m.\n"
            ${pkgs.nh}/bin/nh os switch -a ~/NixConfig -H ${systemArgs.hostname}
          fi

          if [ $? -eq 0 ]; then
            ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-packages.svg} -e -h string:synchronous:rebuild "System has been rebuilt" "and I've applied the latest configuration"
          else
            echo -e "\a"
          fi
        ''
    );
}
