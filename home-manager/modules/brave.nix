{
  host,
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.brave;
  isNvidia = osConfig.configured.nvidia.enable or false;
  useVaapi = host.isDesktop && host.isX86 && !isNvidia;
  features =
    ["TouchpadOverscrollHistoryNavigation"]
    ++ optionals useVaapi [
      "AcceleratedVideoDecodeLinuxGL"
      "AcceleratedVideoDecodeLinuxZeroCopyGL"
      "AcceleratedVideoEncoder"
      "VaapiIgnoreDriverChecks"
    ];
in {
  options.programs.configured.brave = {
    enable = mkEnableOption "Enable the Brave web browser.";
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
      description = "Chromium flags shared by Brave, Helium and the Brave desktop entries.";
    };
  };
  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      commandLineArgs = cfg.flags;
    };
  };
}
