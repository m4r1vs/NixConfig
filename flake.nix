{
  description = "Marius' Nixos Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-06cb-009a-fingerprint-sensor = {
      url = "github:m4r1vs/nixos-06cb-009a-fingerprint-sensor?ref=24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs = {...} @ inputs: let
    globalArgs = {
      username = "mn";
    };
    makeTheme = import ./makeTheme.nix;
  in {
    nixosConfigurations = {
      nixpad = inputs.nixpkgs.lib.nixosSystem (let
        systemArgs =
          globalArgs
          // {
            system = "x86_64-linux";
            theme = makeTheme {
              primary = "green";
              secondary = "orange";
            };
            hostname = "nixpad";
          };
      in {
        inherit (systemArgs) system;
        modules = [
          ./hosts/nixpad

          ./hosts
          ./nixpkgs.nix
          ./modules

          inputs.disko.nixosModules.disko
          inputs.nixos-06cb-009a-fingerprint-sensor.nixosModules."06cb-009a-fingerprint-sensor"
          inputs.nix-index-database.nixosModules.nix-index
          inputs.home-manager.nixosModules.home-manager

          {config._module.args = {inherit systemArgs;};}
        ];
      });
    };
    packages.x86_64-linux = let
      systemArgs =
        globalArgs
        // {
          arch = "x86_64-linux";
          theme = makeTheme {
            primary = "green";
            secondary = "orange";
          };
          hostname = "nixiso";
          format = "iso";
        };
    in {
      iso = inputs.nixos-generators.nixosGenerate {
        inherit (systemArgs) format system;
        modules = [
          ./hosts
          ./nixpkgs.nix
          ./modules

          inputs.nix-index-database.nixosModules.nix-index
          inputs.home-manager.nixosModules.home-manager

          {config._module.args = {inherit systemArgs;};}
        ];
      };
    };
  };
}
