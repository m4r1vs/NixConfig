{
  pkgs,
  scripts,
  lib,
  systemArgs,
  config,
  ...
}: let
  toLua = lib.generators.toLua {};
  cfg = config.home-manager.users.${systemArgs.username}.programs.configured.hyprland;
  # What to open is a host's choice: programs.configured.hyprland.startupApps
  apps = lib.filter (app: app.command != null) cfg.startupApps;
  # With the Lua config, `hyprctl dispatch X` evaluates `hl.dispatch(X)`, so the
  # argument must be a Lua dispatcher expression. hyprctl prints Lua errors but
  # still exits 0.
  dispatch = lua: "hyprctl dispatch ${lib.escapeShellArg lua}";
  exec = cmd: dispatch "hl.dsp.exec_cmd(${toLua cmd})";
  workspace = ws: dispatch "hl.dsp.focus({ workspace = ${toString ws} })";
  # An app that no window rule recognises is put on its workspace as it starts
  launch = app:
    exec ((lib.optionalString (app.match == null && app.workspace != null) "[workspace ${toString app.workspace} silent] ") + app.command);
  /*
  Every numbered workspace that gets an app is shown once, so that its windows
  are drawn before they are needed. The session ends on the lowest one.
  */
  numbered = lib.unique (lib.sort lib.lessThan (lib.filter builtins.isInt (map (app: app.workspace) apps)));
  stops = lib.drop 1 numbered;
  visit = index: ws: ''
    ${workspace ws}
    sleep ${
      if index == 0 || index == builtins.length stops - 1
      then "2"
      else "1"
    }'';
in {
  hyprland-startup-workspaces =
    pkgs.writeShellScript "hyprland-startup-workspaces"
    # bash
    ''
      export PATH=${lib.makeBinPath [pkgs.hyprland pkgs.gnugrep]}:$PATH

      hour=$((10#$(${pkgs.coreutils}/bin/date +%H)))

      if (( hour >= 5 && hour < 12 )); then
        WELCOME_STRING="Good Morning  "
      elif (( hour >= 12 && hour < 18 )); then
        WELCOME_STRING="Good Afternoon  "
      elif (( hour >= 18 && hour < 23 )); then
        WELCOME_STRING="Good Evening 󰖚 "
      elif (( hour >= 23 || hour < 5 )); then
        WELCOME_STRING="Hello, Nightowl 󰖔 "
      else
        WELCOME_STRING="Hello, Time-traveller  "
      fi

      # Wait until keyring is unlocked to avoid gnome-keyring popup
      until ${pkgs.dbus}/bin/dbus-send --print-reply --dest=org.freedesktop.secrets \
        /org/freedesktop/secrets/aliases/default \
        org.freedesktop.DBus.Properties.Get \
        string:org.freedesktop.Secret.Collection \
        string:Locked 2>/dev/null | grep -q "boolean false"; do
        if [ -z "''${asked_to_unlock-}" ]; then
          ${scripts.nixos-notify} -u low -i "${../../assets/nix-flake/at-door.svg}" -e -t 12000 -h string:synchronous:startup-script "$WELCOME_STRING" "Please unlock the keyring so I can get everything running..."
          asked_to_unlock=1
        fi
        sleep 0.5
      done

      ${scripts.nixos-notify} -u low -e -t 12000 -h string:synchronous:startup-script "$WELCOME_STRING" "Let me get everything running for you..."

      ${exec (lib.getExe pkgs.waybar)}
      ${lib.concatMapStringsSep "\n" launch apps}

      sleep 2
      ${lib.concatStringsSep "\n" (lib.imap0 visit stops)}
      ${lib.optionalString (numbered != []) (workspace (lib.head numbered))}
      ${scripts.nixos-notify} -u low -e -t 3000 -h string:synchronous:startup-script "You're ready to go 󱓟 "

      exit 0
    '';
}
