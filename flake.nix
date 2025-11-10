{
  description = "Marius' Nixos Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    nixpkgs_unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-wsl = {
      # Run NixOS on Windows Subsystem for Linux
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    comin = {
      # GitOps
      url = "github:m4r1vs/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    slidecontrol = {
      # Google Slides remote
      url = "github:m4r1vs/slidecontrol?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      # Configure programs using nix
      url = "github:nix-community/home-manager?ref=release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      # Declare how disks are formatted and partitioned
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      # Find files exported by packages in nixpkgs
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      # Create ISO and other images from config
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      # Enable Secureboot
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-substituters = [
      "https://nix-community.cachix.org"
      "https://nix-cache.niveri.dev"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-cache.niveri.dev:jg3SW6BDJ0sNlPxVu7VzXo3IYa3jKNUutfbYpcKSOB8="
    ];
  };

  outputs = {self, ...} @ inputs: let
    globalArgs = {
      username = "mn";
      git = {
        name = "Marius Niveri";
        email = "marius.niveri@gmail.com";
      };
    };
    makeTheme = import ./makeTheme.nix;
    commonModules = [
      ./hosts
      ./nixpkgs.nix
    ];
  in {
    nixosConfigurations =
      {
        nixpad = inputs.nixpkgs.lib.nixosSystem (let
          systemArgs =
            globalArgs
            // {
              system = "x86_64-linux";
              theme = makeTheme {
                primary = "purplish_grey";
                secondary = "red";
              };
              hostname = "nixpad";
            };
        in {
          inherit (systemArgs) system;
          modules =
            [
              ./hosts/nixpad
              ./hosts/nixos.nix

              inputs.lanzaboote.nixosModules.lanzaboote
              inputs.disko.nixosModules.disko
              inputs.nix-index-database.nixosModules.nix-index
              inputs.home-manager.nixosModules.home-manager

              {config._module.args = {inherit systemArgs self inputs;};}
            ]
            ++ commonModules;
        });
        virtnix = inputs.nixpkgs.lib.nixosSystem (let
          systemArgs =
            globalArgs
            // {
              system = "aarch64-linux";
              theme = makeTheme {
                primary = "green";
                secondary = "orange";
              };
              hostname = "virtnix";
            };
        in {
          inherit (systemArgs) system;
          modules =
            [
              ./hosts/virtnix
              ./hosts/nixos.nix

              inputs.disko.nixosModules.disko
              inputs.nix-index-database.nixosModules.nix-index
              inputs.home-manager.nixosModules.home-manager

              {config._module.args = {inherit systemArgs self inputs;};}
            ]
            ++ commonModules;
        });
        nixner = inputs.nixpkgs.lib.nixosSystem (let
          systemArgs =
            globalArgs
            // {
              system = "aarch64-linux";
              theme = makeTheme {
                primary = "orange";
                secondary = "green";
              };
              ipv4 = "95.217.16.168";
              ipv6 = "2a01:4f9:c013:785::1";
              hostname = "nixner";
              domain = "niveri.dev";
            };
        in {
          inherit (systemArgs) system;
          modules =
            [
              ./hosts/nixner
              ./hosts/nixos.nix

              inputs.comin.nixosModules.comin
              inputs.disko.nixosModules.disko
              inputs.nix-index-database.nixosModules.nix-index
              inputs.home-manager.nixosModules.home-manager
              inputs.slidecontrol.nixosModules.slidecontrol-server

              {config._module.args = {inherit systemArgs self inputs;};}
            ]
            ++ commonModules;
        });
        desknix = inputs.nixpkgs.lib.nixosSystem (let
          systemArgs =
            globalArgs
            // {
              system = "x86_64-linux";
              theme = makeTheme {
                primary = "green";
                secondary = "orange";
              };
              hostname = "desknix";
            };
        in {
          inherit (systemArgs) system;
          modules =
            [
              ./hosts/desknix
              ./hosts/nixos.nix

              inputs.lanzaboote.nixosModules.lanzaboote
              inputs.disko.nixosModules.disko
              inputs.nix-index-database.nixosModules.nix-index
              inputs.home-manager.nixosModules.home-manager

              {config._module.args = {inherit systemArgs self inputs;};}
            ]
            ++ commonModules;
        });
        winix = inputs.nixpkgs.lib.nixosSystem (let
          systemArgs =
            globalArgs
            // {
              system = "x86_64-linux";
              theme = makeTheme {
                primary = "green";
                secondary = "orange";
              };
              hostname = "winix";
            };
        in {
          inherit (systemArgs) system;
          modules =
            [
              ./hosts/winix
              ./hosts/nixos.nix

              inputs.nixos-wsl.nixosModules.default
              inputs.nix-index-database.nixosModules.nix-index
              inputs.home-manager.nixosModules.home-manager

              {config._module.args = {inherit systemArgs self inputs;};}
            ]
            ++ commonModules;
        });
      }
      // (import ./hosts/kubenix) {
        inherit inputs globalArgs self makeTheme;
        modules =
          [
            ./hosts/nixos.nix

            inputs.comin.nixosModules.comin
            inputs.disko.nixosModules.disko
            inputs.nix-index-database.nixosModules.nix-index
            inputs.home-manager.nixosModules.home-manager
          ]
          ++ commonModules;
      };
    darwinConfigurations = {
      nixbook = inputs.nix-darwin.lib.darwinSystem (let
        systemArgs =
          globalArgs
          // {
            system = "aarch64-darwin";
            theme = makeTheme {
              primary = "green";
              secondary = "orange";
            };
            hostname = "nixbook";
          };
      in {
        inherit (systemArgs) system;
        specialArgs = {inherit systemArgs self inputs;};
        modules =
          [
            ./hosts/darwin
            ./hosts/darwin/nixbook

            inputs.home-manager.darwinModules.home-manager
            {config._module.args = {inherit systemArgs self inputs;};}
          ]
          ++ commonModules;
      });
    };
    packages.x86_64-linux = {
      bootstrap_local_x86_64 = inputs.nixos-generators.nixosGenerate (let
        systemArgs =
          globalArgs
          // {
            username = "nixos";
            system = "x86_64-linux";
            theme = makeTheme {
              primary = "green";
              secondary = "orange";
            };
            hostname = "nixiso";
            format = "install-iso";
          };
      in {
        inherit (systemArgs) format system;
        modules =
          [
            ./bootstrap/local.nix
            ./hosts/nixos.nix

            inputs.home-manager.nixosModules.home-manager
            inputs.nix-index-database.nixosModules.nix-index

            {config._module.args = {inherit systemArgs self inputs;};}
          ]
          ++ commonModules;
      });
      bootstrap_remote_arm64 = inputs.nixos-generators.nixosGenerate (let
        systemArgs =
          globalArgs
          // {
            username = "nixos";
            system = "aarch64-linux";
            theme = makeTheme {
              primary = "green";
              secondary = "orange";
            };
            hostname = "nixiso_remote_arm";
            format = "install-iso";
          };
      in {
        inherit (systemArgs) format system;
        modules =
          [
            ./bootstrap/remote.nix
            ./hosts/nixos.nix

            inputs.home-manager.nixosModules.home-manager
            inputs.nix-index-database.nixosModules.nix-index
            {config._module.args = {inherit systemArgs self inputs;};}
          ]
          ++ commonModules;
      });
    };
  };
}
