/*
Which browser a host uses, by role rather than by name:

- default: opens links, gets the launcher entries and lives on workspace 1
- side: installed next to the default one and kept on a special workspace (F12)

Desktop entries, window rules and scripts read the `resolved` values below
instead of naming a browser, so a host switches with one option.
*/
{
  host,
  lib,
  config,
  osConfig,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.browser;
  isNvidia = osConfig.configured.nvidia.enable or false;
  useVaapi = host.isDesktop && host.isX86 && !isNvidia;
  features =
    [
      "TouchpadOverscrollHistoryNavigation"
      "WaylandWindowDecorations"
    ]
    ++ optionals useVaapi [
      "AcceleratedVideoDecodeLinuxGL"
      "AcceleratedVideoDecodeLinuxZeroCopyGL"
      "AcceleratedVideoEncoder"
      "VaapiIgnoreDriverChecks"
    ];

  /*
  What differs between the Chromium-based browsers. `exe` plus `args` is the
  full command line; window classes and the MPRIS name were read off the
  running programs (Helium keeps Chromium's "chrome-" prefix for --app
  windows and its "chromium" MPRIS name).
  */
  browsers = {
    brave = {
      name = "brave";
      title = "Brave";
      exe = "${pkgs.brave}/bin/brave";
      args = cfg.flags;
      windowClass = "brave-browser";
      appClassPrefix = "brave";
      processName = "brave";
      mprisName = "brave";
      desktopEntry = "brave-browser";
      secondaryDesktopEntry = "brave-secondary";
      icons = {
        personal = "brave-browser-nightly";
        work = "brave-browser-dev";
      };
    };
    helium = {
      name = "helium";
      title = "Helium";
      # The Helium module bakes the flags into this wrapper
      exe = getExe (config.programs.helium.package.override {inherit (config.programs.helium) flags;});
      args = [];
      windowClass = "helium";
      appClassPrefix = "chrome";
      processName = "helium";
      mprisName = "chromium";
      desktopEntry = "helium";
      secondaryDesktopEntry = "helium-secondary";
      icons = {
        personal = "helium";
        work = "helium";
      };
    };
  };
  names = attrNames browsers;
  withCommand = browser: browser // {command = concatStringsSep " " ([browser.exe] ++ browser.args);};
in {
  options.programs.configured.browser = {
    default = mkOption {
      type = types.enum names;
      default = "brave";
      description = "The browser that opens links, gets the launcher entries and lives on workspace 1.";
    };
    side = mkOption {
      type = types.nullOr (types.enum names);
      default =
        if cfg.default == "brave"
        then "helium"
        else null;
      description = "A second browser kept on a special workspace (F12), or null for none.";
    };
    secondaryProfile = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the default browser gets a second profile with its own launcher
        entry, so work and personal browsing stay apart. Which of the two is
        the work one follows systemArgs.useWorkProfileByDefault.
      '';
    };
    flags = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      default =
        [
          "--ozone-platform-hint=auto"
          "--enable-features=${concatStringsSep "," features}"
          "--password-store=gnome-libsecret"
        ]
        ++ optionals useVaapi [
          "--enable-gpu-rasterization"
          "--enable-zero-copy"
        ];
      description = "Chromium flags shared by every browser here.";
    };
    installed = mkOption {
      type = types.listOf (types.enum names);
      readOnly = true;
      default = unique ([cfg.default] ++ optional (cfg.side != null) cfg.side);
      description = "The browsers a desktop host installs.";
    };
    resolved = mkOption {
      type = types.raw;
      readOnly = true;
      default = {
        default = withCommand browsers.${cfg.default};
        side =
          if cfg.side == null || cfg.side == cfg.default
          then null
          else withCommand browsers.${cfg.side};
        # The profile directory of each role; one profile serves both without a second one
        workProfile =
          if cfg.secondaryProfile && !systemArgs.useWorkProfileByDefault
          then "Secondary"
          else "Default";
        personalProfile =
          if cfg.secondaryProfile && systemArgs.useWorkProfileByDefault
          then "Secondary"
          else "Default";
      };
      description = "Everything the other modules need to know about the chosen browsers.";
    };
  };
}
