{
  description = "A host that lives in its own repository and builds on this configuration";

  inputs.upstream.url = "github:m4r1vs/NixConfig";

  outputs = {upstream, ...} @ inputs: {
    nixosConfigurations.example = upstream.lib.mkHost {
      hostname = "example";
      username = "guest";
      git = {
        name = "Guest";
        email = "guest@example.org";
      };
      # Colour names from makeTheme.nix
      theme = {
        primary = "teal";
        secondary = "orange";
      };
      modules = [./host];
      # The modules in ./host get the inputs above as `ownInputs`
      extraArgs.ownInputs = inputs;
    };
  };
}
