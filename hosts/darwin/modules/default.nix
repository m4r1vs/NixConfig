{lib, ...}: let
  dirContents = builtins.readDir ./.;
  allNames = lib.attrNames dirContents;

  # --- Part 1: Find .nix files in the current directory (excluding default.nix) ---

  nixFilesInCurrentDir =
    lib.filter (
      name: let
        entryType = dirContents.${name};
      in
        entryType == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
    )
    allNames;

  currentDirNixFilePaths = lib.map (name: ./. + "/${name}") nixFilesInCurrentDir;

  # --- Part 2: Find immediate subdirectories (to import their default.nix) ---

  dirNames = lib.filter (name: dirContents.${name} == "directory") allNames;

  subDirPaths = lib.map (name: ./. + "/${name}") dirNames;

  allImportPaths = currentDirNixFilePaths ++ subDirPaths;
in {
  imports = allImportPaths;
}
