{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.programs.configured.helium;
in {
  /*
  Linux only: upstream sets meta.platforms to Linux (it repacks a .deb against
  alsa/systemd/X11), so enabling this on darwin fails evaluation by design.
  macOS gets Helium through the homebrew cask instead.
  */
  imports = [
    inputs.helium.homeModules.default
  ];

  options.programs.configured.helium = {
    enable = mkEnableOption "Enable the Helium web browser.";
  };

  config = mkIf cfg.enable {
    programs.helium = {
      enable = true;
      flags = [
        "--ozone-platform-hint=auto"
        "--enable-features=TouchpadOverscrollHistoryNavigation"
        "--password-store=gnome-libsecret"
      ];
    };
  };
}
