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
          git pull
          nix flake update
          darwin-rebuild build --flake ~/NixConfig/#${systemArgs.hostname}
          ${scripts.nixos-notify} -e "Flake Update Available" "Flake inputs updated successfully and a dry-run build succeeded."
        ''
      else #bash
        ''
          set -e
          export PATH=${pkgs.git}/bin:${pkgs.nix}/bin:/run/current-system/sw/bin:$PATH
          cd ~/NixConfig
          git pull
          nix flake update
          nixos-rebuild dry-build --flake ~/NixConfig/#${systemArgs.hostname}
          ${scripts.nixos-notify} -i ${../../assets/nix-flake/with-packages.svg} -e "Flake Update Available" "Flake inputs updated successfully and a dry-run build succeeded."
        ''
    );
}
