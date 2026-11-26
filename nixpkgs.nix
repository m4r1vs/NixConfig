{
  pkgs,
  config,
  lib,
  systemArgs,
  inputs,
  ...
}:
with lib; let
  # Safe inside the overlay: configured.host never depends on pkgs
  inherit (config.configured.host) isDesktop isDarwin;
  pkgsUnstable = import inputs.nixpkgs_unstable {
    inherit (systemArgs) system;
    config.allowUnfree = true;
  };
  pkgsMaster = import inputs.nixpkgs_master {
    inherit (systemArgs) system;
    config.allowUnfree = true;
  };
in {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      (_final: prev:
        with prev; {
          /*
          Own packages / not in nixpkgs
          */

          atai = inputs.atai.packages.${stdenv.hostPlatform.system}.atai;
          gitlab-mcp = inputs.gitlab-mcp.packages.${stdenv.hostPlatform.system}.default;
          golazo = inputs.golazo.packages.${stdenv.hostPlatform.system}.default;
          hyprland-which-key = inputs.hyprland-which-key.packages.${stdenv.hostPlatform.system}.default;

          slack-mcp-server = buildGoModule (finalAttrs: {
            pname = "slack-mcp-server";
            version = "1.3.0";

            src = fetchFromGitHub {
              owner = "korotovsky";
              repo = "slack-mcp-server";
              tag = "v${finalAttrs.version}";
              hash = "sha256-I4f6yKV0BXtaxnqi/XNID+Pwl2mWjSqxIHhb07U7sc4=";
            };

            vendorHash = "sha256-+uQRODO9oL8mGKBmdghTxE6R9Fz+3GJFVTi17306gT8=";

            subPackages = ["cmd/slack-mcp-server"];

            ldflags = [
              "-s"
              "-w"
              "-X github.com/korotovsky/slack-mcp-server/pkg/version.Version=v${finalAttrs.version}"
              "-X github.com/korotovsky/slack-mcp-server/pkg/version.CommitHash=4bf92874c9ee7add948117f11cc7e4d92c5ca29c"
              "-X github.com/korotovsky/slack-mcp-server/pkg/version.BuildTime=1970-01-01T00:00:00Z"
              "-X github.com/korotovsky/slack-mcp-server/pkg/version.BinaryName=slack-mcp-server"
            ];

            # Run unit tests only (skip *Integration* tests requiring live Slack credentials)
            checkFlags = ["-run=.*Unit.*"];

            meta = {
              description = "Model Context Protocol (MCP) server for Slack workspaces";
              homepage = "https://github.com/korotovsky/slack-mcp-server";
              license = lib.licenses.mit;
              mainProgram = "slack-mcp-server";
            };
          });

          google-workspace-mcp = python3Packages.buildPythonApplication (finalAttrs: {
            pname = "google-workspace-mcp";
            version = "1.30.1";
            pyproject = true;

            src = fetchFromGitHub {
              owner = "taylorwilsdon";
              repo = "google_workspace_mcp";
              tag = "v${finalAttrs.version}";
              hash = "sha256-VFPDLdno/N3UdznpQQZGtr0PpLGvhA8AqY3lVOQuXW8=";
            };

            build-system = with python3Packages; [
              setuptools
              wheel
            ];

            # In stdio mode, Python's webbrowser.open() spawns xdg-open via
            # BackgroundBrowser without redirecting stdout/stderr, so browsers
            # like Chromium/Brave write "Opening in existing browser session."
            # directly onto the MCP JSON-RPC stdout pipe, crashing the server
            # and killing its localhost:8000 OAuth callback listener before the
            # browser redirects. Launch the browser with stdin/stdout/stderr
            # attached to DEVNULL instead.
            postPatch = ''
              python3 - <<'PY'
              from pathlib import Path

              path = Path("auth/google_auth.py")
              src = path.read_text(encoding="utf-8")

              helper = """
              def _open_browser_stdio_safe(url: str) -> bool:
                  \"\"\"Open a URL without letting the browser inherit stdio MCP pipes.\"\"\"
                  import shlex
                  import shutil
                  import subprocess
                  import sys

                  candidates: list[list[str]] = []
                  env_browser = os.environ.get("BROWSER", "")
                  for entry in env_browser.split(os.pathsep):
                      entry = entry.strip()
                      if not entry:
                          continue
                      parts = shlex.split(entry)
                      if not parts:
                          continue
                      if any("%s" in p for p in parts):
                          candidates.append([p.replace("%s", url) for p in parts])
                      else:
                          candidates.append([*parts, url])
                  if not candidates:
                      if sys.platform == "darwin" and shutil.which("open"):
                          candidates.append(["open", url])
                      elif shutil.which("xdg-open"):
                          candidates.append(["xdg-open", url])
                  for cmd in candidates:
                      try:
                          proc = subprocess.Popen(
                              cmd,
                              stdin=subprocess.DEVNULL,
                              stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL,
                              close_fds=True,
                              start_new_session=True,
                          )
                          try:
                              if proc.wait(timeout=0.05) != 0:
                                  continue
                          except subprocess.TimeoutExpired:
                              pass
                          return True
                      except OSError:
                          continue
                  return False


              async def start_auth_flow("""

              anchor = "async def start_auth_flow("
              call_old = "browser_opened = await asyncio.to_thread(webbrowser.open, auth_url)"
              call_new = "browser_opened = await asyncio.to_thread(_open_browser_stdio_safe, auth_url)"

              assert anchor in src, "start_auth_flow anchor missing"
              assert call_old in src, "webbrowser.open call missing"
              src = src.replace(anchor, helper.lstrip("\n"), 1)
              src = src.replace(call_old, call_new, 1)
              path.write_text(src, encoding="utf-8")
              PY
            '';

            pythonRelaxDeps = true;

            dependencies = with python3Packages; [
              cryptography
              defusedxml
              email-validator
              fastapi
              fastmcp
              google-api-python-client
              google-auth-httplib2
              google-auth-oauthlib
              httpx
              markdown-it-py
              py-key-value-aio
              pyjwt
              pypdf
              python-dotenv
              pytz
              pyyaml
              tzdata
              urllib3
            ];

            # Tests rely on network access and optional GCS/Valkey backends.
            doCheck = false;

            meta = {
              description = "Model Context Protocol (MCP) server for Google Workspace (Calendar, Gmail, Drive, Docs, Sheets)";
              homepage = "https://github.com/taylorwilsdon/google_workspace_mcp";
              license = lib.licenses.mit;
              mainProgram = "workspace-mcp";
            };
          });

          reforma-fonts = stdenv.mkDerivation {
            name = "Reforma Fonts";
            src = ./assets/fonts/reforma;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p "$out/share/fonts/opentype/Reforma 1918"
              cp $src/1918/*.otf "$out/share/fonts/opentype/Reforma 1918"
              mkdir -p "$out/share/fonts/opentype/Reforma 1969"
              cp $src/1969/*.otf "$out/share/fonts/opentype/Reforma 1969"
              mkdir -p "$out/share/fonts/opentype/Reforma 2018"
              cp $src/2018/*.otf "$out/share/fonts/opentype/Reforma 2018"

              runHook postInstall
            '';
          };

          fcsp-fonts = stdenv.mkDerivation {
            name = "FC Sans Pauli Font";
            src = ./assets/fonts/fcsp;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/fonts/truetype
              cp $src/*.ttf "$out/share/fonts/truetype"

              runHook postInstall
            '';
          };

          apple-color-emoji = stdenv.mkDerivation {
            name = "Apple Color Emoji Font";
            src = fetchurl {
              url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260722-484daf4e/AppleColorEmoji-Linux.ttf";
              hash = "sha256-43x69iZaxKCvbVe8ZehhCad22ZZug0MzRVf2PaSCUW8=";
            };
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/fonts/truetype
              cp $src $out/share/fonts/truetype/AppleColorEmoji.ttf

              runHook postInstall
            '';
          };

          samsung-clock-font = stdenv.mkDerivation {
            name = "Samsung Classic Clock Font";
            src = ./assets/fonts/samsung/samsung-clock-classic.ttf;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/fonts/truetype
              cp $src $out/share/fonts/truetype/SamsungClockClassic.ttf

              runHook postInstall
            '';
          };

          sf-pro-nerd-font = stdenv.mkDerivation {
            name = "San Francisco Pro Nerd Font";
            src = fetchFromGitHub {
              owner = "sahibjotsaggu";
              repo = "San-Francisco-Pro-Fonts";
              rev = "8bfea09aa6f1139479f80358b2e1e5c6dc991a58";
              hash = "sha256-mAXExj8n8gFHq19HfGy4UOJYKVGPYgarGd/04kUIqX4=";
            };
            nativeBuildInputs = [
              nerd-font-patcher
              lsd
            ];
            installPhase = ''
              runHook preInstall

              rm SF-Pro-Rounded*.otf

              find \( -name \*.otf \) -execdir nerd-font-patcher --no-progressbars -c {} \;

              mkdir -p "$out/share/fonts/opentype/SFProText Nerd Font"
              cp ./SFProTextNerdFont*.otf "$out/share/fonts/opentype/SFProText Nerd Font"
              mkdir -p "$out/share/fonts/opentype/SFProDisplay Nerd Font"
              cp ./SFProDisplayNerdFont*.otf "$out/share/fonts/opentype/SFProDisplay Nerd Font"

              runHook postInstall
            '';
          };

          # TODO: add PR to add to nixpkgs
          skhd-zig = with pkgs;
            stdenv.mkDerivation {
              pname = "skhd-zig";
              version = "0.0.17";
              buildInputs = [
                lsd
              ];
              src = fetchTarball {
                url = "https://github.com/jackielii/skhd.zig/releases/download/v0.0.17/skhd-arm64-macos.tar.gz";
                sha256 = "sha256:1d4z1a83b77hfl0ddpphrfdzq35mniqm7ssifsg9qyxr7llzcfk0";
              };
              installPhase = ''
                runHook preInstall
                mkdir -p $out/bin
                cp ./skhd-arm64-macos $out/bin/skhd
                runHook postInstall
              '';
            };

          /*
          From unstable/master Nixpkgs
          */

          inherit (pkgsMaster) claude-code;
          inherit (pkgsMaster) antigravity-cli;
          clippy-darwin = pkgsUnstable.clippy-copy;
          ghostty =
            if isDarwin
            then pkgsUnstable.ghostty-bin
            else pkgsUnstable.ghostty;
          inherit (pkgsUnstable) hyprsunset;
          inherit (pkgsUnstable) inter-nerdfont;
          inherit (pkgsUnstable) neovim;
          inherit (pkgsUnstable) neovim-unwrapped;
          inherit (pkgsUnstable) nerd-font-patcher;
          inherit (pkgsUnstable) nerd-fonts;
          inherit (pkgsUnstable) mcp-nixos;
          inherit (pkgsUnstable) opencode;
          inherit (pkgsUnstable) openhue-cli;
          inherit (pkgsUnstable) swayimg;
          inherit (pkgsUnstable) tlrc;

          /*
          Temporary Fixes / Updates
          */

          # zathura builds with appstream, which since 1.2.3 on nixos-unstable needs
          # wayland, and nixpkgs has no wayland on darwin: nixbook stops evaluating.
          # Fixed on master by NixOS/nixpkgs#591085; back to
          # `inherit (pkgsUnstable) zathura;` once nixos-unstable has it.
          zathura =
            if isDarwin
            then pkgsMaster.zathura
            else pkgsUnstable.zathura;

          # Waybar 0.15.0 sends legacy `dispatch workspace N` on workspace click, which
          # Hyprland's Lua config rejects. Backport of Alexays/Waybar#5013 (first commit,
          # via Gentoo's hyproverlay), released in 0.16.0; delete this and the patch once
          # nixpkgs has it.
          waybar =
            if lib.versionOlder prev.waybar.version "0.16.0"
            then
              prev.waybar.overrideAttrs (oldAttrs: {
                patches = (oldAttrs.patches or []) ++ [./patches/waybar-0.15.0-hyprland-lua-ipc.patch];
              })
            else prev.waybar;

          # Hyprtasking is not packaged in nixos-26.05 (and unstable targets Hyprland 0.57+);
          # build the v0.55.4-pinned commit against our Hyprland with macOS Tahoe linear styling.
          hyprlandPlugins =
            prev.hyprlandPlugins
            // lib.optionalAttrs (!(prev.hyprlandPlugins ? hyprtasking)) {
              hyprtasking = prev.hyprlandPlugins.mkHyprlandPlugin {
                pluginName = "hyprtasking";
                version = "0-unstable-2026-06-11";
                src = fetchFromGitHub {
                  owner = "raybbian";
                  repo = "hyprtasking";
                  rev = "765575445ce34989575a99f304d0b279e6a980b6";
                  hash = "sha256-7CvSvTEk6rAX/K56QoPbWe7tr+9KGBAugXYJGc6eOEg=";
                };
                patches = [./patches/hyprtasking-macos-tahoe.patch];
                nativeBuildInputs = [
                  meson
                  ninja
                ];
                meta = {
                  homepage = "https://github.com/raybbian/hyprtasking";
                  description = "Powerful workspace management plugin for Hyprland";
                  license = lib.licenses.bsd3;
                  platforms = lib.platforms.linux;
                };
              };
            };

          # Fix cursor landing N columns right of target on tmux 3.7+ (schasse/tmux-jump#50)
          tmuxPlugins =
            prev.tmuxPlugins
            // {
              jump = prev.tmuxPlugins.jump.overrideAttrs {
                version = "2026-10-31";
                src = fetchFromGitHub {
                  owner = "schasse";
                  repo = "tmux-jump";
                  rev = "b547c5ec10fc33baa75953479892007e8eca34a0";
                  hash = "sha256-ia9AfVa6akDEzZVcESVqwnY3nB1uLbxU1ZlBH1j1/tk=";
                };
              };
            };

          /*
          Own Forks
          */

          # Hold-and-enrich notifications, JSON notification queries, and DND/muted sound fixes
          swaynotificationcenter = prev.swaynotificationcenter.overrideAttrs {
            src = fetchFromGitHub {
              owner = "m4r1vs";
              repo = "SwayNotificationCenter";
              rev = "6c2ee36d4c92b44f7ad1d409d3e02389e9ecce86";
              hash = "sha256-l++hbjG7Mn/a60uXYUSuYVjv5+i3XDN1FEx3izXQf0s=";
            };
          };

          # Add support for zsh-vi-mode
          oh-my-posh = pkgsUnstable.buildGo126Module (finalAttrs: {
            pname = "oh-my-posh";
            version = "29.9.1";

            src = pkgsUnstable.fetchFromGitHub {
              owner = "m4r1vs";
              repo = "oh-my-posh";
              rev = "a483019234881c039e5b51ac0d61094bbd3d6857";
              hash = "sha256-1axqKMFHUGApH+kRKHaxo4csnJmopEWb1BDp+NeZElc=";
            };

            vendorHash = "sha256-0pxVRDXdvImA2B3yonnl01Y1UuEKNb6UCVH4enohu2I=";

            sourceRoot = "${finalAttrs.src.name}/src";

            ldflags = [
              "-s"
              "-w"
              "-X github.com/m4r1vs/oh-my-posh/src/build.Version=${finalAttrs.version}"
              "-X github.com/m4r1vs/oh-my-posh/src/build.Date=1970-01-01T00:00:00Z"
            ];

            tags = [
              "netgo"
              "osusergo"
              "static_build"
            ];

            postPatch = ''
              # these tests requires internet access
              rm cli/image/image_test.go config/migrate_glyphs_test.go cli/upgrade/notice_test.go segments/upgrade_test.go
            '';

            postInstall = ''
              mv $out/bin/{src,oh-my-posh}
              mkdir -p $out/share/oh-my-posh
              cp -r $src/themes $out/share/oh-my-posh/
            '';

            meta = {
              description = "Prompt theme engine for any shell";
              mainProgram = "oh-my-posh";
              license = lib.licenses.mit;
            };
          });

          # Make border between panes invisible
          # tmux = tmux.overrideAttrs {
          #   src = pkgs.fetchFromGitHub {
          #     owner = "m4r1vs";
          #     repo = "tmux";
          #     rev = "4e4c003a27e4872e080f5c5f5ade5ba86dc68ae9";
          #     hash = "sha256-H2SXYD2IGQLSOkiyPW2yFnlv905Aw8J4NbPWuTqKt60=";
          #   };
          # };

          # Add title, add playing animation and fix podcasts not loading
          spotify-player = inputs.spotify-player.packages.${stdenv.hostPlatform.system}.default.override (
            {withSixel = false;}
            // (
              if isDesktop
              then {withAudioBackend = "pulseaudio";}
              else {
                withAudioBackend = "";
                withStreaming = false;
                withDaemon = false;
                withMediaControl = false;
                withNotify = false;
              }
            )
          );

          # # Add fn-X and fn-Y shortcuts to resize/move windows
          yabai = pkgsUnstable.yabai.overrideAttrs {
            version = "7.1.25";
            src = fetchFromGitHub {
              owner = "m4r1vs";
              repo = "yabai";
              rev = "6ec767d29d37072c95df942cc1a3da609ffd5f8a";
              hash = "sha256-iR8rhrTSWzT4hRomP4vj3w/TGDQdYOM749V0zZf3Q7k=";
            };
          };

          /*
          Mods to packages
          */

          # Silence premature in-app arrival chimes (SwayNC plays the single notification
          # sound when the held/enriched card actually renders) and retain Electron
          # Notification instances in a bounded Set until "close" so V8 GC does not
          # destroy notifications and break click actions after ~6s.
          whatsapp-electron =
            if stdenv.hostPlatform.isLinux
            then
              stdenv.mkDerivation {
                inherit (prev.whatsapp-electron) pname version meta;
                dontUnpack = true;
                nativeBuildInputs = [
                  asar
                  nodejs
                  python3
                ];
                buildCommand = ''
                  mkdir -p "$out/bin" "$out/share/whatsapp-electron/resources"
                  ln -s "${prev.whatsapp-electron}/share/applications" "$out/share/applications"
                  ln -s "${prev.whatsapp-electron}/share/icons" "$out/share/icons"
                  ln -s "${prev.whatsapp-electron}/share/whatsapp-electron/locales" "$out/share/whatsapp-electron/locales"
                  ln -s "${prev.whatsapp-electron}/share/whatsapp-electron/resources.pak" "$out/share/whatsapp-electron/resources.pak"

                  asar extract "${prev.whatsapp-electron}/share/whatsapp-electron/resources/app.asar" ./app

                  python3 - <<'PY'
                  from pathlib import Path

                  index_path = Path("app/src/index.js")
                  index_src = index_path.read_text(encoding="utf-8")

                  old_noti = """\t\tipcMain.on(Constants.event.newRendererNotification, (event, data) => {
                  \t\t\t//console.log("New Renderer Notification...", data);
                  \t\t\tconst n = new Notification({
                  \t\t\t\ttitle: `[''${this.instances[data.id].name}] :: ''${data.title}`,
                  \t\t\t\tbody: data.options.body,
                  \t\t\t\ticon: nativeImage.createFromDataURL(data.icon)
                  \t\t\t});
                  \t\t\tn.on("click", (event) => {
                  \t\t\t\t//console.log("Notification Clicked...", data.id, data.options.tag);
                  \t\t\t\tthis.showHide(false);
                  \t\t\t\tthis.setCurrentView(data.id);
                  \t\t\t\tthis.instances[data.id].view.webContents.send(Constants.event.fireNotificationClick, data.options.tag);
                  \t\t\t});
                  \t\t\tn.show();
                  \t\t});"""

                  new_noti = """\t\tipcMain.on(Constants.event.newRendererNotification, (event, data) => {
                  \t\t\t//console.log("New Renderer Notification...", data);
                  \t\t\tconst n = new Notification({
                  \t\t\t\ttitle: `[''${this.instances[data.id].name}] :: ''${data.title}`,
                  \t\t\t\tbody: data.options.body,
                  \t\t\t\ticon: nativeImage.createFromDataURL(data.icon),
                  \t\t\t\tsilent: true
                  \t\t\t});
                  \t\t\tthis.activeNotifications = this.activeNotifications || new Set();
                  \t\t\tthis.activeNotifications.add(n);
                  \t\t\twhile (this.activeNotifications.size > 50) {
                  \t\t\t\tconst oldest = this.activeNotifications.values().next().value;
                  \t\t\t\tthis.activeNotifications.delete(oldest);
                  \t\t\t}
                  \t\t\tn.once("close", () => {
                  \t\t\t\tthis.activeNotifications.delete(n);
                  \t\t\t});
                  \t\t\tn.on("click", (event) => {
                  \t\t\t\t//console.log("Notification Clicked...", data.id, data.options.tag);
                  \t\t\t\tthis.showHide(false);
                  \t\t\t\tthis.setCurrentView(data.id);
                  \t\t\t\tthis.instances[data.id].view.webContents.send(Constants.event.fireNotificationClick, data.options.tag);
                  \t\t\t});
                  \t\t\tn.show();
                  \t\t});"""

                  assert old_noti in index_src, "whatsapp-electron newRendererNotification block not found"
                  index_path.write_text(index_src.replace(old_noti, new_noti, 1), encoding="utf-8")

                  preload_path = Path("app/src/preload-bv.js")
                  preload_src = preload_path.read_text(encoding="utf-8")

                  audio_guard = """// Suppress automatic message-notification arrival chimes while preserving
                  // voice-note <audio> playback and WebRTC voice/video calls + ringtones.
                  (() => {
                  \tif (window.__hcAudioGuardInstalled) return;
                  \twindow.__hcAudioGuardInstalled = true;

                  \tlet lastMediaGestureAt = 0;
                  \tlet lastVoiceNoteActivityAt = 0;
                  \tlet lastNotificationAt = 0;

                  \twindow.__hcMarkNotification = () => {
                  \t\tlastNotificationAt = Date.now();
                  \t};

                  \tconst isTextInput = (el) => {
                  \t\tif (!el || typeof el !== "object") return false;
                  \t\tif (el.isContentEditable) return true;
                  \t\tconst tag = (el.tagName || "").toUpperCase();
                  \t\treturn tag === "INPUT" || tag === "TEXTAREA";
                  \t};

                  \twindow.addEventListener("pointerdown", () => {
                  \t\tlastMediaGestureAt = Date.now();
                  \t}, true);
                  \twindow.addEventListener("click", () => {
                  \t\tlastMediaGestureAt = Date.now();
                  \t}, true);
                  \twindow.addEventListener("keydown", (ev) => {
                  \t\tif ((ev.key === "Enter" || ev.key === " ") && !isTextInput(ev.target)) {
                  \t\t\tlastMediaGestureAt = Date.now();
                  \t\t}
                  \t}, true);

                  \tconst trackVoiceNote = (el) => {
                  \t\tif (el.__hcTrackedVoiceNote) return;
                  \t\tel.__hcTrackedVoiceNote = true;
                  \t\tconst bump = () => {
                  \t\t\tlastVoiceNoteActivityAt = Date.now();
                  \t\t};
                  \t\tel.addEventListener("timeupdate", bump);
                  \t\tel.addEventListener("ended", bump);
                  \t\tel.addEventListener("pause", bump);
                  \t};

                  \tif (typeof HTMLMediaElement !== "undefined" && HTMLMediaElement.prototype.play) {
                  \t\tconst origPlay = HTMLMediaElement.prototype.play;
                  \t\tHTMLMediaElement.prototype.play = function (...args) {
                  \t\t\tconst now = Date.now();
                  \t\t\tconst src = String(this.currentSrc || this.src || "");
                  \t\t\tconst isVideo = typeof HTMLVideoElement !== "undefined" && this instanceof HTMLVideoElement;
                  \t\t\tconst isStreamOrRingtone = Boolean(this.srcObject) || Boolean(this.loop);
                  \t\t\tconst isDomPlayer = Boolean(this.isConnected) || Boolean(this.controls) || Boolean(this.__hcTrackedVoiceNote);
                  \t\t\tconst isBlobVoiceNote = src.startsWith("blob:") && (
                  \t\t\t\t(now - lastMediaGestureAt) < 2500 || (now - lastVoiceNoteActivityAt) < 5000
                  \t\t\t);
                  \t\t\tconst isDirectUserMedia = (now - lastMediaGestureAt) < 1200 && (now - lastNotificationAt) > 1500;

                  \t\t\tif (isVideo || isStreamOrRingtone || isDomPlayer || isBlobVoiceNote || isDirectUserMedia) {
                  \t\t\t\tif (!isVideo && !this.loop && !this.srcObject) {
                  \t\t\t\t\tlastVoiceNoteActivityAt = now;
                  \t\t\t\t\ttrackVoiceNote(this);
                  \t\t\t\t}
                  \t\t\t\treturn origPlay.apply(this, args);
                  \t\t\t}
                  \t\t\treturn Promise.resolve();
                  \t\t};
                  \t}

                  \tif (typeof AudioBufferSourceNode !== "undefined" && AudioBufferSourceNode.prototype.start) {
                  \t\tconst origStart = AudioBufferSourceNode.prototype.start;
                  \t\tconst origConnect = AudioBufferSourceNode.prototype.connect;
                  \t\tif (typeof origConnect === "function") {
                  \t\t\tAudioBufferSourceNode.prototype.connect = function (...args) {
                  \t\t\t\tif (this.__hcMutedChime) return args[0];
                  \t\t\t\treturn origConnect.apply(this, args);
                  \t\t\t};
                  \t\t}
                  \t\tAudioBufferSourceNode.prototype.start = function (...args) {
                  \t\t\tconst now = Date.now();
                  \t\t\tconst dur = this.buffer && typeof this.buffer.duration === "number" ? this.buffer.duration : 0;
                  \t\t\tconst allow = Boolean(this.loop) || (
                  \t\t\t\tdur > 5 && (now - lastMediaGestureAt) < 1500 && (now - lastNotificationAt) > 1500
                  \t\t\t);
                  \t\t\tif (!allow) {
                  \t\t\t\tthis.__hcMutedChime = true;
                  \t\t\t\ttry { this.disconnect(); } catch (_) {}
                  \t\t\t}
                  \t\t\treturn origStart.apply(this, args);
                  \t\t};
                  \t}
                  })();
                  """

                  noti_ctor_old = "\tconstructor(title, options)\n\t{\n\t\t//console.log(\"New NotificationServer...\", title, options);\n\t\tthis._processOptions(title, options);\n\t}"
                  noti_ctor_new = "\tconstructor(title, options = {})\n\t{\n\t\tif (typeof window.__hcMarkNotification === \"function\") window.__hcMarkNotification();\n\t\tthis._processOptions(title, { ...options, silent: true });\n\t}"

                  assert noti_ctor_old in preload_src, "NotificationServer constructor anchor not found"
                  preload_src = audio_guard + "\n" + preload_src.replace(noti_ctor_old, noti_ctor_new, 1)
                  preload_path.write_text(preload_src, encoding="utf-8")
                  PY

                  node --check app/src/index.js
                  node --check app/src/preload-bv.js

                  asar pack ./app "$out/share/whatsapp-electron/resources/app.asar" --unpack-dir assets

                  substitute "${prev.whatsapp-electron}/bin/whatsapp-electron" "$out/bin/whatsapp-electron" \
                    --replace-fail "${prev.whatsapp-electron}" "$out"
                  chmod +x "$out/bin/whatsapp-electron"
                '';
              }
            else prev.whatsapp-electron;

          # Silence Signal Desktop's premature message/reaction/unread-reminder arrival chime
          # in NotificationService while preserving RingRTC call ringtones, IncomingGroupCall
          # alerts, and voice-note playback. SwayNC plays the single notification sound on release.
          signal-desktop =
            if stdenv.hostPlatform.isLinux
            then
              stdenv.mkDerivation {
                inherit (prev.signal-desktop) pname version meta passthru;
                dontUnpack = true;
                nativeBuildInputs = [
                  asar
                  nodejs
                  python3
                ];
                buildCommand = ''
                  mkdir -p "$out/bin" "$out/share/signal-desktop"
                  ln -s "${prev.signal-desktop}/share/applications" "$out/share/applications"
                  ln -s "${prev.signal-desktop}/share/icons" "$out/share/icons"
                  ln -s "${prev.signal-desktop}/share/polkit-1" "$out/share/polkit-1"
                  ln -s "${prev.signal-desktop}/share/signal-desktop/app-update.yml" "$out/share/signal-desktop/app-update.yml"
                  ln -s "${prev.signal-desktop}/share/signal-desktop/default_app.asar" "$out/share/signal-desktop/default_app.asar"

                  asar extract "${prev.signal-desktop}/share/signal-desktop/app.asar" ./app

                  python3 - <<'PY'
                  import re
                  from pathlib import Path

                  preload_bundle = Path("app/bundles/preload/main.js")
                  src = preload_bundle.read_text(encoding="utf-8")

                  # In NotificationService.#d(), Signal reads `!!e.get("audio-notification")`
                  # solely to pass `silent: !c` into `rawNotify(...)` for Message, Reaction,
                  # and UnreadReminder notifications (IncomingGroupCall and RingRTC ringtones
                  # do not go through this check and continue playing normally).
                  pattern = re.compile(r'!!\w+\.get\(["\'`]audio-notification["\'`]\)')
                  patched, count = pattern.subn('!1', src)
                  assert count == 1, f"expected exactly 1 audio-notification check in NotificationService, found {count}"
                  preload_bundle.write_text(patched, encoding="utf-8")
                  PY

                  node --check app/bundles/preload/main.js

                  asar pack ./app "$out/share/signal-desktop/app.asar" --unpack "*.node"

                  substitute "${prev.signal-desktop}/bin/signal-desktop" "$out/bin/signal-desktop" \
                    --replace-fail "${prev.signal-desktop}" "$out"
                  chmod +x "$out/bin/signal-desktop"
                '';
              }
            else prev.signal-desktop;

          # wttr.in's TLS certificate expired (seen 2026-09-15), and wttrbar reacts
          # to any request error with a 20-step backoff loop that burns ~95s before
          # giving up. hyprlock blocks its own exit on that, so the lock screen stuck
          # around for ~2min after being dismissed. Accept the stale cert, give the
          # client a real timeout and drop the retry budget to one attempt.
          # Once wttr.in fixes its cert, danger_accept_invalid_certs can be dropped.
          wttrbar = wttrbar.overrideAttrs (oldAttrs: {
            postPatch =
              (oldAttrs.postPatch or "")
              + ''
                substituteInPlace src/main.rs \
                  --replace-fail 'let client = Client::new();' 'let client = Client::builder().danger_accept_invalid_certs(true).timeout(Duration::from_secs(2)).build().unwrap();' \
                  --replace-fail 'let threshold = 20;' 'let threshold = 1;'
              '';
          });

          rofi =
            if isDarwin
            then inputs.rofi-darwin.packages.${stdenv.hostPlatform.system}.default
            else prev.rofi;

          menubar-compat =
            if isDarwin
            then inputs.menubar-compat.packages.${stdenv.hostPlatform.system}.default
            else null;

          rofi-unwrapped = rofi-unwrapped.overrideAttrs (_oldAttrs: {
            patchPhase = ''
              echo "NoDisplay=true" >> ./data/rofi-theme-selector.desktop
              echo "NoDisplay=true" >> ./data/rofi.desktop
            '';
          });

          polybar = polybar.override {
            nlSupport = true; # networking
            iwSupport = true; # WiFi
            i3Support = true;
            pulseSupport = true;
            alsaSupport = true;
            githubSupport = true;
          };

          /*
          tuxedo-drivers 4.20.1 doesn't build on Linux 7.3 (NixOS/nixpkgs#576266).
          Turns itself off once the 26.05 backport (NixOS/nixpkgs#583561) lands.
          */
          kernelPackagesExtensions =
            prev.kernelPackagesExtensions
            ++ [
              (_kfinal: kprev: {
                tuxedo-drivers =
                  if versionOlder kprev.tuxedo-drivers.version "4.25.0"
                  then
                    kprev.tuxedo-drivers.overrideAttrs (old: {
                      version = "4.25.0";
                      src = fetchFromGitLab {
                        group = "tuxedocomputers";
                        owner = "development/packages";
                        repo = "tuxedo-drivers";
                        rev = "v4.25.0";
                        hash = "sha256-AER+JPl3lem1OFV51VdOZAnr3Uy1BFSpEJNrE+shYis=";
                      };
                      # upstream moved usr/ to files/usr/ in 4.21.0
                      postInstall = builtins.replaceStrings ["usr/lib/udev"] ["files/usr/lib/udev"] old.postInstall;
                    })
                  else kprev.tuxedo-drivers;
              })
            ];
        })

      # hyprlandPlugins.macos-zoom, built against the Hyprland above
      inputs.hyprland-macos-zoom.overlays.default
    ];
  };
}
