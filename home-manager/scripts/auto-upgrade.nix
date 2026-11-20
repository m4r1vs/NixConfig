{
  config,
  helpers,
  host,
  lib,
  pkgs,
  scripts,
  systemArgs,
  ...
}: let
  inherit (host) isDarwin;
  flakeDir = lib.escapeShellArg host.flakePath;
  hostFlakeAttr = lib.escapeShellArg "${host.flakePath}#nixosConfigurations.${systemArgs.hostname}.config.system.build.toplevel";
in {
  auto-upgrade =
    helpers.mkScript
    (
      if isDarwin
      then {
        name = "auto-upgrade";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.openssh
          config.nix.package
        ];
        text = ''
          export PATH="/run/current-system/sw/bin:$PATH"
          cd ${flakeDir}

          if ! git diff --quiet -- flake.lock; then
            ${scripts.nixos-notify} -e "Flake Auto-Update Skipped" "flake.lock has uncommitted local changes."
            exit 1
          fi

          OLD_HEAD=$(git rev-parse HEAD)
          git pull --rebase
          nix flake update

          LOCK_CHANGED=0
          if ! git diff --quiet -- flake.lock; then
            LOCK_CHANGED=1
          fi

          PULLED_CHANGES=0
          if [ "$OLD_HEAD" != "$(git rev-parse HEAD)" ]; then
            PULLED_CHANGES=1
          fi

          if [ "$LOCK_CHANGED" -eq 0 ] && [ "$PULLED_CHANGES" -eq 0 ]; then
            exit 0
          fi

          if ! darwin-rebuild build --flake ${lib.escapeShellArg "${host.flakePath}#${systemArgs.hostname}"}; then
            if [ "$LOCK_CHANGED" -eq 1 ]; then
              git checkout -- flake.lock
            fi
            ${scripts.nixos-notify} -e "Flake Auto-Update Failed" "darwin-rebuild build failed for ${systemArgs.hostname}."
            exit 1
          fi

          if [ "$LOCK_CHANGED" -eq 1 ]; then
            git commit --only -m "nix: auto-update" -- flake.lock
            git push || true
          fi

          ${scripts.nixos-notify} -e "Flake Update Available" "Flake inputs updated successfully and the build succeeded."
        '';
      }
      else let
        bootHelper = "${config.services.configured.auto-upgrade.bootHelper}/bin/auto-upgrade-boot";
        switchHelper = "${config.services.configured.auto-upgrade.switchHelper}/bin/auto-upgrade-switch";
      in {
        name = "auto-upgrade";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.openssh
          config.nix.package
        ];
        text = ''
          TMP_DIR=""
          cleanup() {
            if [ -n "''${TMP_DIR:-}" ]; then
              rm -rf -- "$TMP_DIR"
            fi
          }
          trap cleanup EXIT

          notify_failure() {
            local title="$1"
            local body="$2"
            ${scripts.nixos-notify} \
              -u critical \
              -t 0 \
              -i ${../../assets/nix-flake/default.svg} \
              "$title" "$body"
          }

          restore_lock() {
            if [ "$LOCK_CHANGED" -eq 1 ]; then
              git checkout -- flake.lock
            fi
          }

          LOCK_CHANGED=0
          cd ${flakeDir}

          if ! git diff --quiet -- flake.lock; then
            notify_failure \
              "NixOS Auto-Update Skipped" \
              "flake.lock has uncommitted local changes in ${host.flakePath}."
            exit 1
          fi

          OLD_HEAD="$(git rev-parse HEAD)"

          # A checkout without an upstream branch has nothing to pull or to push to
          HAS_UPSTREAM=0
          if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            HAS_UPSTREAM=1
          fi

          if [ "$HAS_UPSTREAM" -eq 1 ] && ! git pull --rebase; then
            notify_failure \
              "NixOS Auto-Update Failed" \
              "git pull --rebase failed in ${host.flakePath}."
            exit 1
          fi

          if ! nix flake update; then
            git checkout -- flake.lock
            notify_failure \
              "NixOS Auto-Update Failed" \
              "nix flake update failed."
            exit 1
          fi

          if ! git diff --quiet -- flake.lock; then
            LOCK_CHANGED=1
          fi

          PULLED_CHANGES=0
          if [ "$OLD_HEAD" != "$(git rev-parse HEAD)" ]; then
            PULLED_CHANGES=1
          fi

          if [ "$LOCK_CHANGED" -eq 0 ] && [ "$PULLED_CHANGES" -eq 0 ]; then
            exit 0
          fi

          TMP_DIR="$(mktemp -d)"
          RESULT_LINK="$TMP_DIR/result"

          if ! nix build --out-link "$RESULT_LINK" ${hostFlakeAttr}; then
            restore_lock
            notify_failure \
              "NixOS Auto-Update Build Failed" \
              "Test-build failed for ${systemArgs.hostname}. Check journalctl --user -u auto-upgrade."
            exit 1
          fi

          SYSTEM_PATH="$(readlink -f -- "$RESULT_LINK")"
          CURRENT_BOOT="$(readlink -f -- /nix/var/nix/profiles/system 2>/dev/null || true)"

          if [ "$SYSTEM_PATH" = "$CURRENT_BOOT" ]; then
            if [ "$LOCK_CHANGED" -eq 1 ]; then
              git commit --only -m "nix: auto-update" -- flake.lock
              if [ "$HAS_UPSTREAM" -eq 1 ]; then
                git push || true
              fi
            fi
            exit 0
          fi

          if ! /run/wrappers/bin/sudo -n ${bootHelper} "$SYSTEM_PATH"; then
            restore_lock
            notify_failure \
              "NixOS Auto-Update Boot Failed" \
              "Test-build passed, but installing the boot generation failed. Check journalctl --user -u auto-upgrade."
            exit 1
          fi

          PUSH_FAILED=0
          if [ "$LOCK_CHANGED" -eq 1 ]; then
            git commit --only -m "nix: auto-update" -- flake.lock
            if [ "$HAS_UPSTREAM" -eq 1 ] && ! git push; then
              PUSH_FAILED=1
            fi
          fi

          BODY="System rebuilt for next boot. Switch now to apply without rebooting."
          if [ "$PUSH_FAILED" -eq 1 ]; then
            BODY="System rebuilt for next boot (git push failed — push manually). Switch now to apply without rebooting."
          fi

          RESPONSE="$(
            ${scripts.nixos-notify} \
              -u critical \
              -t 0 \
              -i ${../../assets/nix-flake/with-packages.svg} \
              --action="switch=Switch" \
              "System Update Ready" \
              "$BODY" || true
          )"

          if [[ "$RESPONSE" == *"switch"* ]]; then
            if /run/wrappers/bin/sudo -n ${switchHelper}; then
              ${scripts.nixos-notify} \
                -i ${../../assets/nix-flake/with-packages.svg} \
                -e \
                -h string:synchronous:rebuild \
                "System has been switched" \
                "The latest configuration is now active"
            else
              notify_failure \
                "System Switch Failed" \
                "Failed to activate the new configuration. Check journalctl --user -u auto-upgrade."
              exit 1
            fi
          fi
        '';
      }
    );
}
