{
  lib,
  config,
  pkgs,
  scripts,
  ...
}:
with lib; let
  cfg = config.services.configured.hyprsunset;
  darkman = config.services.configured.darkman;
in {
  options.services.configured.hyprsunset = {
    enable = mkEnableOption "Smooth solar-elevation color temperature filter (hyprsunset)";
    latitude = mkOption {
      type = types.float;
      default = darkman.latitude;
      description = "Latitude for solar elevation calculation.";
    };
    longitude = mkOption {
      type = types.float;
      default = darkman.longitude;
      description = "Longitude for solar elevation calculation.";
    };
    dayTemperature = mkOption {
      type = types.ints.between 2000 6500;
      default = 6500;
      description = "Daytime color temperature in Kelvin (6500 = identity).";
    };
    nightTemperature = mkOption {
      type = types.ints.between 2000 6500;
      default = 3800;
      description = "Nighttime color temperature in Kelvin.";
    };
    minElevation = mkOption {
      type = types.float;
      default = -6.0;
      description = "Solar elevation in degrees at which nightTemperature is fully reached (civil twilight).";
    };
    maxElevation = mkOption {
      type = types.float;
      default = 6.0;
      description = "Solar elevation in degrees at which the golden-hour ramp begins.";
    };
    nightGamma = mkOption {
      type = types.ints.between 50 100;
      default = 100;
      description = "Nighttime gamma percentage (100 = no software dimming).";
    };
  };

  config = mkIf cfg.enable {
    services.hyprsunset = {
      enable = true;
      package = pkgs.hyprsunset;
      settings = {
        max-gamma = 100;
        profile = [
          {
            time = "00:00";
            identity = true;
          }
        ];
      };
    };

    systemd.user.services.hyprsunset-solar = {
      Unit = {
        Description = "Apply solar-elevation color temperature to hyprsunset";
        ConditionEnvironment = "WAYLAND_DISPLAY";
        After = ["hyprsunset.service"];
        Requires = ["hyprsunset.service"];
        PartOf = [config.wayland.systemd.target];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${scripts.nightlight} sync";
      };
      Install.WantedBy = [config.wayland.systemd.target];
    };

    systemd.user.timers.hyprsunset-solar = {
      Unit = {
        Description = "Update hyprsunset color temperature along solar elevation curve";
        PartOf = [config.wayland.systemd.target];
      };
      Timer = {
        OnCalendar = "*:0/5";
        AccuracySec = "30s";
      };
      Install.WantedBy = [config.wayland.systemd.target];
    };
  };
}
