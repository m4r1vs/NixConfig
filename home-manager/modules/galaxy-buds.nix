{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.galaxy-buds;
in {
  options.programs.configured.galaxy-buds = {
    enable = mkEnableOption "Galaxy Buds Manager (GalaxyBudsClient) and Rofi controls";
  };

  config = mkIf cfg.enable {
    # TODO: fork this to remove UI/tray icon and make it systemd-service only. Rewrite in rust maybe?
    home.packages = [pkgs.galaxy-buds-client];

    # Run GalaxyBudsClient minimized in the tray so its D-Bus IPC/CLI is always
    # ready for Manage Galaxy Buds (ANC/Ambient/EQ actions & per-bud battery).
    systemd.user.services.galaxy-buds-client = {
      Unit = {
        Description = "Galaxy Buds Manager (tray / D-Bus IPC)";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target" "pipewire.service"];
      };
      Service = {
        ExecStart = "${pkgs.galaxy-buds-client}/bin/GalaxyBudsClient /StartMinimized";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
