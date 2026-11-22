/*
What npu-dictate's voice commands run (see modules/npu-dictate.nix).

  voice-command browser | whatsapp | obsidian   focus the app's window, or start it
  voice-command workspace N                     N from 1 to 9
  voice-command left | right                    the neighbouring workspace
  voice-command site DOMAIN                     https://DOMAIN in the default browser
  voice-command weather                         wttr.in as a notification

A failure exits non-zero with one line on stderr, which the daemon shows in its
"Voice command “NAME” failed" notification.

`apps` maps a subcommand to { title, workspace, match, launch }: match is a
window rule match (initial_class, initial_title, class, title -> regex),
launch a Lua dispatcher expression that starts the app, or null.
`openUrl` is a Lua dispatcher expression with @URL@ in place of the address.
*/
{
  pkgs,
  lib,
  helpers,
  scripts,
  ...
}: {
  voice-command = {
    apps,
    openUrl,
    weatherLocation,
  }:
    helpers.mkScript {
      name = "voice-command";
      runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.hyprland pkgs.jq];
      text =
        # bash
        ''
          die() {
            printf '%s\n' "$*" >&2
            exit 1
          }

          # The daemon is a long-running service: the signature it inherited
          # may name a Hyprland that is gone (hyprctl then exits 4).
          # `hyprctl instances` does not read it and lists only running ones.
          use_live_instance() {
            local instances sig
            instances=$(hyprctl instances -j 2>/dev/null) || die "cannot list the running Hyprland instances"
            sig=$(jq -r --arg sig "''${HYPRLAND_INSTANCE_SIGNATURE:-}" --arg wl "''${WAYLAND_DISPLAY:-}" \
              '(map(select(.instance == $sig)) + map(select(.wl_socket == $wl)) + .)[0].instance // empty' <<<"$instances")
            [ -n "$sig" ] || die "Hyprland is not running"
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          }

          # A dispatch that worked prints "ok". One that did not prints a
          # warning or a Lua error, and hyprctl still exits 0.
          dispatch() {
            local out
            if ! out=$(hyprctl dispatch "$1" 2>&1); then
              die "hyprctl dispatch failed: ''${out%%$'\n'*}"
            fi
            [ "$out" = ok ] || die "Hyprland: ''${out%%$'\n'*}"
          }

          focus_workspace() {
            dispatch "hl.dsp.focus({ workspace = $1 })"
          }

          # The address of the app's window, one on its own workspace first,
          # then the one focused last; empty when it has none
          find_window() {
            local clients address
            clients=$(hyprctl clients -j 2>/dev/null) || die "cannot list Hyprland's windows"
            address=$(jq -r --argjson app "$1" '
              def field($key):
                if $key == "initial_class" then .initialClass
                elif $key == "initial_title" then .initialTitle
                elif $key == "class" then .class
                elif $key == "title" then .title
                else null end;
              [ .[] | . as $c
                | select($app.match | to_entries | all(. as $m | ($c | field($m.key)) // "" | test($m.value))) ]
              | sort_by([.workspace.id != $app.workspace, .focusHistoryID])
              | .[0].address // empty' <<<"$clients")
            # It ends up inside a Lua string
            [[ -z "$address" || "$address" =~ ^0x[0-9a-f]+$ ]] || die "unexpected window address from hyprctl"
            printf '%s' "$address"
          }

          # Started through Hyprland, never as a child of this script: the
          # dictation service takes its whole control group down when it stops.
          focus_or_launch() {
            local app=$1 address launch
            address=$(find_window "$app")
            if [ -n "$address" ]; then
              dispatch "hl.dsp.focus({ window = 'address:$address' })"
              return
            fi
            launch=$(jq -r '.launch // empty' <<<"$app")
            [ -n "$launch" ] || die "$(jq -r .title <<<"$app") is not running"
            dispatch "$launch"
            focus_workspace "$(jq -r .workspace <<<"$app")"
          }

          weather() {
            local report
            # -f: an HTTP error is a failure; no -S: the message below is the one line
            report=$(curl -fs --max-time 10 ${lib.escapeShellArg "https://wttr.in/${lib.escapeURL weatherLocation}?m&format=%c+%t+(feels+like+%f),+%w,+%p"}) ||
              die "wttr.in did not answer (curl exit status $?)"
            report=''${report%%$'\n'*}
            [ -n "$report" ] || die "wttr.in sent an empty answer"
            ${scripts.nixos-notify} -e -u low -t 10000 -h string:synchronous:voice-weather \
              ${lib.escapeShellArg "Weather in ${weatherLocation}"} "$report" ||
              die "could not show the weather notification"
          }

          case "''${1:-}" in
          ${lib.concatStrings (lib.mapAttrsToList (name: app: ''
              ${name})
                use_live_instance
                focus_or_launch ${lib.escapeShellArg (builtins.toJSON app)}
                ;;
            '')
            apps)}
          workspace)
            case "''${2:-}" in
            [1-9])
              use_live_instance
              focus_workspace "$2"
              ;;
            *) die "no workspace \"''${2:-}\" (1 to 9)" ;;
            esac
            ;;
          left)
            use_live_instance
            focus_workspace '"m-1"'
            ;;
          right)
            use_live_instance
            focus_workspace '"m+1"'
            ;;
          ${lib.optionalString (apps ? browser) ''
            site)
              # The daemon hands over a checked domain. Check again: it ends up
              # inside a Lua string and a shell line.
              domain=''${2:-}
              domain=''${domain,,}
              [[ "$domain" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] ||
                die "not a domain: \"''${2:-}\""
              use_live_instance
              # The browser opens the page in the window it was focused in last
              address=$(find_window ${lib.escapeShellArg (builtins.toJSON apps.browser)})
              [ -z "$address" ] || dispatch "hl.dsp.focus({ window = 'address:$address' })"
              url_lua=${lib.escapeShellArg openUrl}
              dispatch "''${url_lua//@URL@/https://$domain}"
              [ -n "$address" ] || focus_workspace ${toString apps.browser.workspace}
              ;;
          ''}
          weather) weather ;;
          *) die "unknown voice command: ''${1:-}" ;;
          esac
        '';
    };
}
