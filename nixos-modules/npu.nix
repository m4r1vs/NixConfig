{
  lib,
  config,
  options,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.npu;

  /*
  The underlying options come from inputs.nix-amd-ai.nixosModules.default,
  which must be imported in the host's module list in flake.nix. Guarding on
  its presence keeps this auto-imported module harmless on every other host.
  */
  hasAmdNpuModule = options.hardware ? amd-npu;

  /*
  XRT >= 2.25 finds its XDNA shim next to whichever libxrt_coreutil the
  loader resolved. The flm binary's RUNPATH points at the plain XRT store
  path, which has no shim, so `flm run/serve` fails with
  "No such device with index '0'" even though the NPU is present. The
  nix-amd-ai module exposes its merged XRT+shim tree via XILINX_XRT; put
  that tree first on the library path and the shim is found.
  */
  xrtCombined = config.environment.sessionVariables.XILINX_XRT;
  flmWrapped = pkgs.writeShellScriptBin "flm" ''
    export LD_LIBRARY_PATH="${xrtCombined}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec ${pkgs.fastflowlm}/bin/flm "$@"
  '';
  # flm downloads its models into $HOME/.config/flm, so the unit needs one
  homeDir = "/home/${systemArgs.username}";
in {
  options.configured.npu = {
    enable = mkEnableOption "AMD Ryzen AI (XDNA2) NPU userspace: XRT, the amdxdna shim and FastFlowLM";
    server.enable = mkEnableOption "`flm serve --asr 1`, the whisper-large-v3-turbo backend npu-dictate talks to";
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = hasAmdNpuModule;
          message = "configured.npu needs inputs.nix-amd-ai.nixosModules.default in this host's module list (flake.nix)";
        }
      ];
    })
    (optionalAttrs hasAmdNpuModule (mkIf cfg.enable {
      hardware.amd-npu = {
        enable = true;
        # We install our own wrapped flm below instead of the module's bare one
        enableFastFlowLM = false;
        # No OpenAI-compatible frontend or image generation; `flm serve` is enough
        enableLemonade = false;
        enableImageGen = false;
      };

      # LLM/ASR inference on the NPU via `flm` (whisper-v3:turbo, qwen3, ...)
      environment.systemPackages = [flmWrapped];
      # nix pins the version; flm's update probe on every start is noise
      environment.sessionVariables.FLM_DISABLE_UPDATE_CHECK = "1";

      # The module grants unlimited memlock (needed for NPU DMA buffers) to these groups
      users.users.${systemArgs.username}.extraGroups = ["video" "render"];

      # Prebuilt XRT/FastFlowLM from the flake author's cache instead of a 30+ min build
      nix.settings = {
        substituters = ["https://nix-amd-ai.cachix.org"];
        trusted-public-keys = ["nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="];
      };

      /*
      The ASR backend. A *system* unit on purpose: NPU DMA buffers need an
      unlimited RLIMIT_MEMLOCK, which PAM grants to interactive sessions but
      which systemd --user never inherits. It still runs as the user, so the
      ~1 GB whisper model lands in ~/.config/flm on first start.
      */
      systemd.services.flm-serve = mkIf cfg.server.enable {
        description = "FastFlowLM ASR server (whisper-large-v3-turbo on the NPU)";
        documentation = ["https://github.com/FastFlowLM/FastFlowLM"];
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];

        environment = {
          HOME = homeDir;
          XILINX_XRT = xrtCombined;
          FLM_DISABLE_UPDATE_CHECK = "1";
        };

        serviceConfig = {
          ExecStart = "${flmWrapped}/bin/flm serve --asr 1";
          User = systemArgs.username;
          SupplementaryGroups = ["video" "render"];
          LimitMEMLOCK = "infinity";
          WorkingDirectory = homeDir;
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    }))
  ];
}
