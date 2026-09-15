{
  lib,
  config,
  inputs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.npu-dictate;
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  /*
  The upstream flake only builds for x86_64-linux and aarch64-linux, so on
  darwin the imported module's `package` default would point at a missing
  output. Keep it off the darwin hosts entirely.
  */
  imports = optionals (!isDarwin) [
    inputs.npu-dictate.homeManagerModules.default
  ];

  options.programs.configured.npu-dictate = {
    enable = mkEnableOption "Push-to-talk dictation: hold a key, speak, release, and whisper-large-v3-turbo on the NPU types it out";
  };

  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    /*
    The daemon owns the microphone and the socket; the window manager binds
    `npu-dictate start` to key press and `npu-dictate stop` to key release
    (see hyprland.nix / i3.nix). The backend it posts to is
    configured.npu.server on the NixOS side.
    */
    programs.npu-dictate = {
      enable = true;
      settings = {
        server = {
          # Named in the notification when the backend is down
          unit = "flm-serve.service";
        };
        audio = {
          # Accidental taps are dropped without a notification
          min_duration_ms = 300;
          # A stuck key stops recording here and transcribes what it has
          max_duration_secs = 60;
        };
        typing = {
          # "clipboard" pastes with ctrl+v instead, which is wrong in terminals
          method = "type";
          trailing_space = true;
        };
        feedback = {
          # Only failures get a popup; the "Listening…"/"Transcribing…" progress
          # notifications were noise in swaync
          notifications = true;
          progress_notifications = false;
        };
      };
    };

    # Debug level logs every start/stop the daemon receives, including the ones
    # it ignores, which is what shows whether a key release ever reached it.
    systemd.user.services.npu-dictate.Service.Environment = [
      "RUST_LOG=npu_dictate=debug,info"
    ];
  });
}
