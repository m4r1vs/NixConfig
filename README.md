# Marius' Nix Configuration

My multiplatform configuration focused on software development.

## Bootstrapping

Two definitions in `./bootstrap/`: One for graphical environments (Laptop, Desktop, etc.) and one for headless setups.
The ISO can be built using `nixos-rebuild build-image`. Use tab completion to specify whether to build for an arm64 or x86 CPU.
SSH should work out of the box for both setups with my SSH key already marked as trusted.

Use the `help` script in PATH for a refresher on the installation commands.

## Rebuilding

A bash script `rebuild` is in PATH that automatically runs `sudo nixos-rebuild switch` or `sudo darwin-rebuild switch` depending on the host.
It also checks which specialization is active and switches to that one.

## Global Arguments

The argument `systemArgs` is passed down to all modules both in home-manager, nixos and nix-darwin setups.
It contains global varibales such as username, git e-mail and
default theming colors. The variables can be set globally or per-host in `flake.nix`.

## NeoVim

I use [lazy.nvim](https://github.com/folke/lazy.nvim) to manage plugins. The plugin versions are not directly pinned to nixpkgs.
However, the lock file is configured to be in `./home-manager/modules/neovim/nvim/` so plugin updates are tracked by git in this repo.

## Overlays

Generally, I use the stable nixpkgs branch. However, I like to use the latest versions of some software.
That is managed in `./nixpkgs.nix`. All overlays are defined there.

## Scripts

I make heavy use of bash scripts for all kinds of purposes. They are all placed in `./home-manager/scripts/` and `scripts` is available
across all home-manager modules. A good example is `nixos-notify` which, depending on platform, uses libnotify or AppleScript to show a notification.

## Color Schemes

The primary color palette is inspired by [Flexoki](https://stephango.com/flexoki).
Both graphical NixOS and Darwin installations automatically switch between dark and light variants based on the sun.
There is also a concept of primary and secondary color. These are defined per-wallpaper in the `custom-wallpaper-theme` script.

## Server

Server modules (Kubernetes, Minecraft Server, GitLab, GitLab Runners, Bind DNS, etc.) are defined in `./nixos-modules/server/`.
There are also slim Kubernetes-focused hosts `kubenix` that are synced to my ArgoCD App of Apps in [argo-apps](https://github.com/m4r1vs/argo-apps).
