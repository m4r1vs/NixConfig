{
  pkgs,
  systemArgs,
  ...
}: let
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  rebuild =
    pkgs.writeShellScript "rebuild"
    (
      if isDarwin
      then ''
        sudo darwin-rebuild switch --flake ~/NixConfig/#${systemArgs.hostname} && sudo yabai --load-sa
      ''
      else ''
        sudo nixos-rebuild switch --flake ~/NixConfig/#${systemArgs.hostname}
      ''
    );
}
