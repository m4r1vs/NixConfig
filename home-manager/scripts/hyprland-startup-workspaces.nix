{
  pkgs,
  scripts,
  lib,
  systemArgs,
  config,
  ...
}: let
  toLua = lib.generators.toLua {};
  braveFlags = config.home-manager.users.${systemArgs.username}.programs.configured.brave.flags;
  # With the Lua config, `hyprctl dispatch X` evaluates `hl.dispatch(X)`, so the
  # argument must be a Lua dispatcher expression. hyprctl prints Lua errors but
  # still exits 0.
  dispatch = lua: "hyprctl dispatch ${lib.escapeShellArg lua}";
  exec = cmd: dispatch "hl.dsp.exec_cmd(${toLua cmd})";
  workspace = ws: dispatch "hl.dsp.focus({ workspace = ${toString ws} })";
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
      ${exec "${lib.getExe pkgs.signal-desktop} --ozone-platform-hint=auto"}
      ${exec "${lib.getExe pkgs.whatsapp-electron} --ozone-platform-hint=auto"}
      ${lib.optionalString systemArgs.useWorkProfileByDefault (exec (lib.getExe pkgs.slack))}
      ${exec "${lib.getExe pkgs.obsidian} --ozone-platform-hint=auto"}
      ${lib.optionalString (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.spotify)
        (exec "${lib.getExe pkgs.spotify} --ozone-platform-hint=auto")}
      ${exec (lib.getExe pkgs.ghostty)}
      ${exec "${lib.getExe pkgs.brave} --profile-directory=Default ${lib.concatStringsSep " " braveFlags}"}

      sleep 2
      ${workspace 2}
      sleep 2
      ${workspace 3}
      sleep 1
      ${lib.optionalString systemArgs.useWorkProfileByDefault
        # bash
        ''
          ${workspace 4}
          sleep 1
        ''}
      ${workspace 6}
      sleep 1
      ${workspace 9}

      sleep 2

      ${workspace 1}
      ${scripts.nixos-notify} -u low -e -t 3000 -h string:synchronous:startup-script "You're ready to go 󱓟 "

      exit 0
    '';
}
