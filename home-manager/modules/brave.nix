{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.brave;
in {
  options.programs.configured.brave = {
    enable = mkEnableOption "Enable the Brave web browser.";
    flags = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      default = [
        "--ozone-platform-hint=auto"
        "--enable-features=TouchpadOverscrollHistoryNavigation"
        "--password-store=gnome-libsecret"
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
