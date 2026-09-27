/*
Single source of truth for "what kind of host is this?".

Derived from options that already exist (configured.desktop, wsl, the active
window manager), so it is re-evaluated inside every desktop specialisation.
Home-manager modules and scripts receive it as the `host` argument.

Never derive this from `pkgs`: nixpkgs.nix reads it inside the overlay.
*/
{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.host;
  readOnly = description: default:
    mkOption {
      type = types.bool;
      readOnly = true;
      inherit default description;
    };
  windowManager =
    if config.configured.hyprland.enable or false
    then "hyprland"
    else if config.configured.i3.enable or false
    then "i3"
    else if config.configured.gamescope.enable or false
    then "gamescope"
    else null;
in {
  options.configured.host = {
    kind = mkOption {
      type = types.enum ["desktop" "server" "wsl" "iso" "darwin"];
      default =
        if hasSuffix "darwin" systemArgs.system
        then "darwin"
        else if config.wsl.enable or false
        then "wsl"
        else if config.configured.desktop.enable or false
        then "desktop"
        else "server";
      description = "Kind of host. Installer ISOs set this to \"iso\" explicitly.";
    };
    windowManager = mkOption {
      type = types.nullOr (types.enum ["hyprland" "i3" "gamescope"]);
      readOnly = true;
      default =
        if cfg.isDesktop
        then windowManager
        else null;
      description = "Window manager of the active (specialisation) session.";
    };
    isDesktop = readOnly "Graphical NixOS workstation" (cfg.kind == "desktop");
    isServer = readOnly "Headless server" (cfg.kind == "server");
    isWSL = readOnly "NixOS on WSL" (cfg.kind == "wsl");
    isISO = readOnly "Installer ISO" (cfg.kind == "iso");
    isDarwin = readOnly "nix-darwin" (cfg.kind == "darwin");
    isLinux = readOnly "Linux" (!cfg.isDarwin);
    isX86 = readOnly "x86_64" (hasPrefix "x86_64" systemArgs.system);
    isGraphical = readOnly "Has a local GUI (NixOS desktop or macOS)" (cfg.isDesktop || cfg.isDarwin);
    isHeadless = readOnly "Server or installer ISO" (cfg.isServer || cfg.isISO);
    isDev = readOnly "Interactive dev machine that gets the full toolchain" (cfg.isGraphical || cfg.isWSL);
    isWayland = readOnly "Wayland session" (cfg.windowManager == "hyprland" || cfg.windowManager == "gamescope");
    isX11 = readOnly "X11 session" (cfg.windowManager == "i3");
    hasPowerProfiles = readOnly "power-profiles-daemon is enabled" (config.services.power-profiles-daemon.enable or false);
    hasNpuServer = readOnly "NPU transcription server is enabled" (config.configured.npu.server.enable or false);
    flakePath = mkOption {
      type = types.str;
      default = "${config.users.users.${systemArgs.username}.home}/NixConfig";
      description = "Where this flake is checked out (used by nh, rebuild and auto-upgrade).";
    };
  };
}
