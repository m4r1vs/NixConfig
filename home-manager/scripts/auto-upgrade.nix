{
  pkgs,
  scripts,
  systemArgs,
  ...
}: let
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  auto-upgrade =
    pkgs.writeShellScript "auto-upgrade"
    (
      if isDarwin
      then # bash
        ''
          set -e
          export PATH=${pkgs.git}/bin:${pkgs.nix}/bin:/run/current-system/sw/bin:$PATH
          cd ~/NixConfig
          git pull --rebase
          nix flake update
          git diff --quiet flake.lock || (git add flake.lock && git commit -m "chore: update flake.lock")
          darwin-rebuild build --flake ~/NixConfig/#${systemArgs.hostname}
          ${scripts.nixos-notify} -e "Flake Update Available" "Flake inputs updated successfully and a dry-run build succeeded."
        ''
      else #bash
        ''
          set -e
          export PATH=${pkgs.git}/bin:${pkgs.nix}/bin:/run/current-system/sw/bin:$PATH
          cd ~/NixConfig
          git pull --rebase
          nix flake update
          git diff --quiet flake.lock || (git add flake.lock && git commit -m "chore: update flake.lock")
          nixos-rebuild dry-build --flake ~/NixConfig/#${systemArgs.hostname}
          RESPONSE="$(${scripts.nixos-notify} -t 0 -i ${../../assets/nix-flake/with-packages.svg} -e --action="rebuild=Rebuild" "Flake Update Available" "Flake inputs updated successfully and a dry-run build succeeded.")"
          if [[ "$RESPONSE" == *"rebuild"* ]]; then
            ${pkgs.ghostty}/bin/ghostty --class=rebuild --wait-after-command=true -e bash -c "cd ~/NixConfig && ${scripts.rebuild} && git push || { echo 'An error occurred. Press enter to exit.'; read; }" &
          fi
        ''
    );
}
