let
  importScript = {
    fileName,
    pkgs,
    systemArgs,
    config,
  }: let
    scriptModule = import ./scripts/${fileName};
  in
    scriptModule {
      inherit pkgs systemArgs config;
      scripts = makeScripts {inherit pkgs systemArgs config;};
      lib = pkgs.lib;
    };

  makeScripts = {
    pkgs,
    systemArgs,
    config,
  }: (pkgs.lib.foldl pkgs.lib.mergeAttrs {} (
    pkgs.lib.mapAttrsToList (fileName: fileType:
      importScript {
        inherit fileName pkgs systemArgs config;
      }) (builtins.readDir ./scripts)
  ));
in
  makeScripts
