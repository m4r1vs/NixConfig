/*
Collects every home-manager/scripts/*.nix into one attrset. Each file gets the
finished set as `scripts` (a fixpoint, so scripts can reference each other)
plus `helpers` from scriptLib.nix.
*/
{
  pkgs,
  systemArgs,
  config,
}: let
  inherit (pkgs) lib;
  helpers = import ./scriptLib.nix {inherit pkgs config;};
  files =
    lib.attrNames
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name)
      (builtins.readDir ./scripts));
  build = scripts: let
    perFile = lib.genAttrs files (file:
      import ./scripts/${file} {
        inherit pkgs lib systemArgs config scripts helpers;
        inherit (config.configured) host;
      });
    # Only forces attribute names, never values, so the fixpoint stays lazy.
    owners = lib.zipAttrs (lib.mapAttrsToList (file: set: lib.mapAttrs (_: _: file) set) perFile);
    duplicates = lib.filterAttrs (_: fs: builtins.length fs > 1) owners;
  in
    assert lib.assertMsg (duplicates == {})
    "makeScripts: duplicate script names: ${lib.concatStringsSep "; " (lib.mapAttrsToList (name: fs: "${name} in ${lib.concatStringsSep ", " fs}") duplicates)}";
      lib.foldl' lib.mergeAttrs {} (lib.attrValues perFile);
in
  lib.fix build
