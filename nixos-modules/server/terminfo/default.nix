{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.server.terminfo;
  ghosttyTerminfo = pkgs.stdenv.mkDerivation {
    pname = "ghostty-terminfo";
    version = "1.0";
    src = ./xterm-ghostty.src;
    dontUnpack = true;

    nativeBuildInputs = [pkgs.ncurses];

    buildPhase = ''
      mkdir -p terminfo-out
      ${pkgs.ncurses}/bin/tic -x -o terminfo-out $src
    '';

    installPhase = ''
      mkdir -p $out/share/terminfo
      cp -r terminfo-out/* $out/share/terminfo/
    '';
  };
in {
  options.configured.server.terminfo = {
    enable = mkEnableOption "Use all terminal capabilities on a remote machine.";
  };
  config = mkIf cfg.enable {
    environment.variables.TERMINFO_DIRS = "${ghosttyTerminfo}/share/terminfo" + ":${pkgs.ncurses}/share/terminfo";
  };
}
