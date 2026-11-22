{
  host,
  lib,
  config,
  inputs,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.hey-computer;
  inherit (host) isDarwin;
in {
  /*
  The upstream flake only builds for x86_64-linux and aarch64-linux (as with
  npu-dictate), so keep its module off the darwin hosts entirely.
  */
  imports = optionals (!isDarwin) [
    inputs.hey-computer.homeManagerModules.default
  ];

  options.programs.configured.hey-computer = {
    enable = mkEnableOption ''
      hey-computer: a voice assistant that keeps one agy agent warm and
      answers "Hey Computer, …" from npu-dictate. The agent runs every
      command that does not need root without asking'';
  };

  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    /*
    The agent is this account without its password: whatever the account may
    do without typing one, the agent may do, without confirmation (see the
    permission model in hey-computer's README). The service runs with
    NoNewPrivileges, so sudo and other setuid programs it runs itself fail.
    */
    programs.hey-computer = {
      enable = true;
      # The agy build the interactive CLI uses (nixpkgs master, see nixpkgs.nix)
      agent.package = config.programs.antigravity-cli.package;
      # Readable and writable without confirmation; null where a host names
      # no vault, which also leaves out the Obsidian skills
      vault =
        mapNullable (name: "${config.home.homeDirectory}/Documents/${name}")
        (systemArgs.obsidianVault or null);
      # The same Obsidian the desktop starts (hyprland.nix startupApps); the
      # agent drives it through its obsidian-cli
      obsidian.package = pkgs.obsidian;
      /*
      On top of the module's basics (a shell, coreutils and the text tools,
      curl, jq, notify-send, playerctl, wpctl): hyprctl from the Hyprland the
      session runs, and the volume and brightness tools the keybinds use, so
      "louder" means what the volume keys mean. Everything else the account
      has installed follows through programs.hey-computer.systemPath.
      */
      extraPackages = with pkgs; [
        hyprland
        pamixer
        brightnessctl
        wl-clipboard
      ];
      settings = {
        agent = {
          model = "gemini-4-hydrogen";
          thought_level = "low";
        };
        # A follow-up this soon after an answer continues the conversation
        conversation.follow_up_secs = 90;
      };
    };

    /*
    Greetd autologin reaches graphical-session.target before hyprlock unlocks
    GNOME Keyring. Waiting in an ExecStart wrapper (rather than ExecStartPre)
    lets systemd mark the Type=simple unit active right away with no startup
    timeout, while delaying agy's warm start until the keyring is unlocked so
    it does not trigger a hidden gcr-prompter behind hyprlock and time out.
    */
    systemd.user.services.hey-computer.Service.ExecStart = mkForce (
      toString (pkgs.writeShellScript "hey-computer-daemon" ''
        trap 'exit 0' TERM INT
        until ${pkgs.dbus}/bin/dbus-send --print-reply --dest=org.freedesktop.secrets \
          /org/freedesktop/secrets/aliases/default \
          org.freedesktop.DBus.Properties.Get \
          string:org.freedesktop.Secret.Collection \
          string:Locked 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "boolean false"; do
          sleep 0.5 &
          wait $! || exit 0
        done
        exec ${getExe config.programs.hey-computer.package} daemon
      '')
    );
  });
}
