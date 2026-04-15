---
name: install-program
description: Use this skill to install a program on the user's computer.
---

# Installing a program

## Query Nixpkgs

First, use the nixos MCP server's `search` capability to search for the package in nixpkgs.
If the package has multiple versions, query the information for each package and get back to the user so they can decide which package to use.

Some programs can be configured through home-manager. Use the MCP server to find out if the given package is supported by home-manager.

### Supported by home-manager

1. Create a new module in @home-manager/modules called `[pacakge-name].nix`. Use this template:

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.[package-name];
in {
  options.programs.configured.[package-name] = {
    enable = mkEnableOption "[DESCRIPTION]";
  };
  config = mkIf cfg.enable {
    programs.[package-name-in-home-manager] = {
        # Default config
    };
  };
}
```

2. Go through the possible config with the user, educate them on the options and set them according to their needs.

### Not supported by home-manager

1. Add the pacakge to @home-manager/packages.nix - if the package has GUI elements, it should be in graphical or nixos desktop only. Otherwise, every system.

## Not in nixpkgs

If the package does not exist in nixpkgs, query Google for "[Package Name] nixos". Some bleeding edge packages can be added through flake inputs.
Educate the user on the risks and ask if they want to continue. If yes, add the flake input to @flake.nix and run `nix flake update`.
Then edit @nixpkgs.nix to add the package in the "Own Packages/Not in nixpkgs" category.

## Rebuilding

Run the command `rebuild` which is defined in the nix configuration to point to the correct command depending on system and hostname.
If it fails, fix the errors until it succeeds. Then ask the user to test the program and ask for feedback.
