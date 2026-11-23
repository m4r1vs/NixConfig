{
  host,
  lib,
  config,
  inputs,
  scripts,
  ...
}:
with lib; let
  cfg = config.programs.configured.npu-dictate;
  inherit (host) isDarwin;
  toLua = generators.toLua {};
  exec = cmd: "hl.dsp.exec_cmd(${toLua cmd})";

  /*
  What `voice-command browser|whatsapp|obsidian` focuses or starts: the same
  window match, workspace and command the Hyprland module pins the app with
  (programs.configured.hyprland.startupApps). An app a host does not pin gets
  no voice command.
  */
  browser = config.programs.configured.browser.resolved.default;
  browserCommand = concatStringsSep " " ([browser.exe "--profile-directory=Default"] ++ browser.args);
  startupApp = title: isIt: let
    app = findFirst (app: app.match != null && isInt app.workspace && isIt app.match) null config.programs.configured.hyprland.startupApps;
  in
    mapNullable (app: {
      inherit title;
      inherit (app) workspace match;
      launch = mapNullable exec app.command;
    })
    app;
  apps = filterAttrs (_: app: app != null) {
    # Workspace 1 is the default browser's (see browser.nix), started as the
    # login session starts it and as links open it
    browser = {
      inherit (browser) title;
      workspace = 1;
      match.class = "^(${browser.windowClass})$";
      launch = exec browserCommand;
    };
    whatsapp = startupApp "WhatsApp" (match: hasPrefix "^(WhatsApp" (match.initial_title or ""));
    obsidian = startupApp "Obsidian" (match: (match.initial_class or "") == "^(md.obsidian.Obsidian)$");
    slack = startupApp "Slack" (match: (match.initial_class or "") == "^(slack)$");
    signal = startupApp "Signal" (match: (match.initial_class or "") == "^(signal)$");
    spotify = startupApp "Spotify" (match: (match.initial_class or "") == "^(spotify)$");
  };
  voiceCommand = scripts.voice-command {
    inherit apps;
    openUrl = exec "${browserCommand} @URL@";
    inherit (config.programs.configured.waybar) weatherLocation;
  };
  run = args: [voiceCommand] ++ args;
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
    enable = mkEnableOption "Push-to-talk dictation: hold a key and speak; the words appear as you say them and whisper-large-v3-turbo on the NPU replaces them with its transcript";
    voiceCommands.enable = mkOption {
      type = types.bool;
      default = host.isDev;
      description = ''
        Voice commands: a dictation that is only "Browser", "Workspace 3",
        "Wetter" or "open github.com" (see the rules below) runs that instead
        of being typed. There is no way to type such a dictation literally.
      '';
    };
    voiceCommand = mkOption {
      type = types.raw;
      readOnly = true;
      internal = true;
      default = {
        script = voiceCommand;
        inherit apps;
      };
      description = "Instantiated voice-command script and resolved app map, shared with hey-computer.";
    };
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
      /*
      Words show up in the focused field while the key is held, underlined,
      and the NPU transcript replaces them: a short dictation in one piece at
      release, a long one phrase by phrase at pauses. The streaming model
      (Nemotron 3.5, German and English) is a 475 MB fetch and keeps about
      1.5 GB of memory for as long as the daemon runs. The daemon registers as
      the seat's input method for this, so it cannot run next to fcitx5 or
      ibus; where an app offers no text field (or on i3) the text is typed at
      release as before.
      */
      live.enable = true;
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
        /*
        Voice commands. A rule fires only when the whole dictation is one of
        its phrases, compared without case, punctuation, umlauts and the
        spaces between words ("Work space drei." is "Workspace 3"). Nothing
        is guessed: a spelling whisper keeps producing for a phrase is listed
        as a phrase of its own. A phrase that is an ordinary thing to dictate
        on its own does not belong here: "Right.", "nach links" and "Workspace
        10" are typed as usual. Each rule runs voice-command (scripts/); when
        that fails, the daemon shows its stderr line in a "Voice command
        “NAME” failed" notification.
        */
        commands = mkIf cfg.voiceCommands.enable {
          # The default list, spelt out: a bare "{domain}" also fires on the
          # few names people dictate that end in one of these ("ASP.NET")
          tlds = ["com" "org" "net" "de" "eu" "at" "ch" "uk" "io" "dev" "app" "ai" "tv" "info"];
          rules =
            {
              weather = {
                phrases = ["Wetter" "Weather" "Whether" "Wetterbericht" "Weather report" "Wettervorhersage" "Weather forecast"];
                run = run ["weather"];
              };
            }
            /*
            "Hey Computer, wie spät ist es?": everything after the greeting
            goes to hey-computer on stdin, which hands it to its daemon and
            returns at once; the answer comes as a notification or a window.
            The greetings are the ones whisper makes of it and that nobody
            starts an ordinary dictation with (no "Mein Computer", nor "Home
            Computer", which the matcher also hears in "Homecomputer").
            */
            // optionalAttrs config.programs.configured.hey-computer.enable {
              assistant = {
                kind = "prefix";
                phrases = [
                  "Hey Computer"
                  "Hay Computer"
                  "Hei Computer"
                  "Hej Computer"
                  "Pay Computer"
                  "Hi Computer"
                  "Hai Computer"
                  "Hello Computer"
                  "Hallo Computer"
                  "Moin Computer"
                  "Hey Komputer"
                  "Hi Komputer"
                  "Hello Komputer"
                  "Hallo Komputer"
                  "Moin Komputer"
                  "Hey Computa"
                ];
                run = [(getExe config.programs.hey-computer.package) "ask"];
              };
            }
            // optionalAttrs (host.windowManager == "hyprland") (
              {
                browser = {
                  phrases = [
                    "Browser"
                    "Brauser"
                    "Web Browser"
                    "Internet"
                    "Open Browser"
                    "Open the Browser"
                    "Öffne Browser"
                    "Öffne den Browser"
                    "Browser öffnen"
                  ];
                  run = run ["browser"];
                };
                # The keybinds stop at 9, so does this: "Workspace 10" is typed
                workspace = {
                  phrases = [
                    "Workspace {n:1-9}"
                    "Workspace Nummer {n:1-9}"
                    "Workspace number {n:1-9}"
                    "Arbeitsbereich {n:1-9}"
                    "Arbeitsfläche {n:1-9}"
                  ];
                  run = run ["workspace" "{n}"];
                };
                # Never a bare direction ("Right." is a reply), nor "nach links"
                # or "go right", which are directions too
                left = {
                  phrases = [
                    "Workspace links"
                    "Workspace nach links"
                    "Workspace left"
                    "Arbeitsbereich links"
                    "linker Workspace"
                    "left Workspace"
                    "vorheriger Workspace"
                    "previous Workspace"
                  ];
                  run = run ["left"];
                };
                right = {
                  phrases = [
                    "Workspace rechts"
                    "Workspace nach rechts"
                    "Workspace right"
                    "Arbeitsbereich rechts"
                    "rechter Workspace"
                    "right Workspace"
                    "nächster Workspace"
                    "next Workspace"
                  ];
                  run = run ["right"];
                };
                site = {
                  phrases = [
                    "{domain}"
                    "open {domain}"
                    "öffne {domain}"
                    "go to {domain}"
                    "gehe zu {domain}"
                    "geh zu {domain}"
                  ];
                  run = run ["site" "{domain}"];
                };
              }
              // optionalAttrs (apps ? whatsapp) {
                whatsapp = {
                  phrases = ["WhatsApp" "Watsapp" "Whatsap" "Open WhatsApp" "Öffne WhatsApp" "WhatsApp öffnen"];
                  run = run ["whatsapp"];
                };
              }
              // optionalAttrs (apps ? obsidian) {
                # The app on workspace 3, not the notes in Neovim on F11
                obsidian = {
                  phrases = ["Obsidian" "Obsidien" "Opsidian" "Open Obsidian" "Öffne Obsidian" "Obsidian öffnen"];
                  run = run ["obsidian"];
                };
              }
            );
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
