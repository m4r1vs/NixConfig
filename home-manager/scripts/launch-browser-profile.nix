/*
Launches the default browser with a given profile directory ("Default" or
"Secondary"). On Hyprland, writes a short-lived workspace hint before starting
the browser so Hyprland can route the new window to that profile's workspace
(Chromium shares one window class and one process across all profiles in a user
data dir, so a static window rule cannot tell profiles apart).
*/
{
  pkgs,
  lib,
  helpers,
  systemArgs,
  config,
  ...
}: let
  hmCfg = config.home-manager.users.${systemArgs.username}.programs.configured;
  browsers = hmCfg.browser;
  browser = browsers.resolved.default;
  defaultBrowserApp =
    lib.findFirst
    (app: app.match != null && (app.match.initial_class or "") == "^(${browser.windowClass})$" && builtins.isInt app.workspace)
    null
    hmCfg.hyprland.startupApps;
  defaultWorkspace =
    if defaultBrowserApp != null
    then defaultBrowserApp.workspace
    else 1;
  inherit (browsers) secondaryWorkspace;
in {
  launch-browser-profile = helpers.mkScript {
    name = "launch-browser-profile";
    runtimeInputs = [pkgs.coreutils];
    text =
      # bash
      ''
        profile="''${1:-Default}"
        shift || true

        workspace=""
        case "$profile" in
          Default) workspace="${toString defaultWorkspace}" ;;
          Secondary) workspace="${lib.optionalString (secondaryWorkspace != null) (toString secondaryWorkspace)}" ;;
        esac

        if [ -n "$workspace" ] && [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
          tmp=$(mktemp "$runtime_dir/hypr-browser-workspace.XXXXXX")
          printf '%s %s\n' "$workspace" "$(( $(date +%s) + 10 ))" > "$tmp"
          mv -f "$tmp" "$runtime_dir/hypr-browser-workspace"
        fi

        exec ${lib.escapeShellArg browser.exe} "--profile-directory=$profile" ${lib.escapeShellArgs browser.args} "$@"
      '';
  };
}
