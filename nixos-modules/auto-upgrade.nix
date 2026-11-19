{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}: let
  cfg = config.services.configured.auto-upgrade;
  hostRegex = "^/nix/store/[a-z0-9]{32}-nixos-system-${lib.escapeRegex systemArgs.hostname}-[^/]+$";

  bootHelper = pkgs.writeShellApplication {
    name = "auto-upgrade-boot";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      config.nix.package
      config.system.build.nixos-rebuild
    ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: auto-upgrade-boot <system-store-path>" >&2
        exit 1
      fi

      SYSTEM_PATH="$(readlink -f -- "$1")"
      HOST_RE='${hostRegex}'

      if [[ ! "$SYSTEM_PATH" =~ $HOST_RE ]]; then
        echo "Refusing invalid system store path: $SYSTEM_PATH" >&2
        exit 1
      fi

      if ! nix-store --check-validity "$SYSTEM_PATH" >/dev/null 2>&1; then
        echo "Refusing unregistered store path: $SYSTEM_PATH" >&2
        exit 1
      fi

      if [ ! -f "$SYSTEM_PATH/nixos-version" ] || [ ! -x "$SYSTEM_PATH/bin/switch-to-configuration" ]; then
        echo "Path is not a valid NixOS system closure: $SYSTEM_PATH" >&2
        exit 1
      fi

      exec nixos-rebuild boot --no-reexec --store-path "$SYSTEM_PATH"
    '';
  };

  switchHelper = pkgs.writeShellApplication {
    name = "auto-upgrade-switch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      config.nix.package
      config.system.build.nixos-rebuild
    ];
    text = ''
      if [ "$#" -ne 0 ]; then
        echo "Usage: auto-upgrade-switch (takes no arguments)" >&2
        exit 1
      fi

      SYSTEM_PATH="$(readlink -f -- /nix/var/nix/profiles/system)"
      HOST_RE='${hostRegex}'

      if [[ ! "$SYSTEM_PATH" =~ $HOST_RE ]]; then
        echo "Refusing invalid system profile path: $SYSTEM_PATH" >&2
        exit 1
      fi

      if [ ! -f "$SYSTEM_PATH/nixos-version" ] || [ ! -x "$SYSTEM_PATH/bin/switch-to-configuration" ]; then
        echo "Profile is not a valid NixOS system closure: $SYSTEM_PATH" >&2
        exit 1
      fi

      EXTRA_ARGS=()
      if [ -f /etc/nixos_active_specialisation ]; then
        SPEC="$(< /etc/nixos_active_specialisation)"
        if [ -n "$SPEC" ] && [ -d "$SYSTEM_PATH/specialisation/$SPEC" ]; then
          EXTRA_ARGS+=(--specialisation "$SPEC")
        fi
      fi

      # boot already updated /nix/var/nix/profiles/system and the bootloader;
      # test activates the exact same generation live without creating a
      # duplicate generation or re-running bootloader installation.
      exec nixos-rebuild test --no-reexec --store-path "$SYSTEM_PATH" "''${EXTRA_ARGS[@]}"
    '';
  };
in {
  options.services.configured.auto-upgrade = {
    enable = lib.mkEnableOption "Privileged boot and switch helpers for automated NixOS upgrades";
    bootHelper = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = bootHelper;
      description = "Locked-down root helper that installs a pre-built NixOS system closure for the next boot.";
    };
    switchHelper = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = switchHelper;
      description = "Locked-down root helper that activates /nix/var/nix/profiles/system live (preserving active specialisation).";
    };
  };

  config = lib.mkIf cfg.enable {
    security.sudo.extraRules = [
      {
        users = [systemArgs.username];
        commands = [
          {
            command = "${cfg.bootHelper}/bin/auto-upgrade-boot";
            options = ["NOPASSWD"];
          }
          {
            command = "${cfg.switchHelper}/bin/auto-upgrade-switch";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };
}
