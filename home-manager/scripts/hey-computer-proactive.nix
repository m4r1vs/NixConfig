/*
Shell-gated proactive automation for hey-computer (#26):
- `location`: classifies current environment as `work`, `home`, or `other`
  using connected monitor descriptions/models (`hyprctl monitors -j`) and
  optional user-local `~/.config/hey-computer/locations.json` rules (IP prefix,
  default gateway, Wi-Fi SSID, or monitor substrings — keeping private IPs and
  network names out of git).
- `morning-digest`: once-per-day post-wake digest gated on unlocked session,
  online network, ready daemon, and daily stamp file; asks hey-computer in the
  background (`-b -p deep --suppress-token HEARTBEAT_OK`) to write today's brief
  to `Journal/YYYY-MM-DD.md` and/or notify.
- `pre-daily`: workday 09:56 pre-standup brief gated on unlocked session,
  work/home location (or work schedule override), network, and ready daemon.
- Split failure routing: clean no-ops (`HEARTBEAT_OK` / skipped pre-checks)
  stay silent; hard errors (daemon down, non-zero exit, failed task) append to
  `$XDG_STATE_HOME/hey-computer/proactive/failures.log` and emit a rate-limited
  failure alert (at most once per 4 hours per check).
*/
{
  pkgs,
  lib,
  config,
  systemArgs,
  helpers,
  ...
}: let
  heyComputer = lib.getExe config.home-manager.users.${systemArgs.username}.programs.hey-computer.package;
in {
  hey-computer-proactive = helpers.mkScript {
    name = "hey-computer-proactive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dbus
      pkgs.gnugrep
      pkgs.hyprland
      pkgs.iproute2
      pkgs.jq
      pkgs.libnotify
      pkgs.procps
    ];
    text =
      # bash
      ''
        STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/hey-computer/proactive"
        CONFIG_FILE="''${XDG_CONFIG_HOME:-$HOME/.config}/hey-computer/locations.json"
        FAIL_LOG="$STATE_DIR/failures.log"
        ALERT_COOLDOWN_SECS=14400 # 4 hours

        install -d -m 700 "$STATE_DIR"

        log_failure() {
          local check="$1"
          local msg="$2"
          local ts
          ts=$(date -Iseconds)
          printf '%s [%s] %s\n' "$ts" "$check" "$msg" >> "$FAIL_LOG"

          local stamp="$STATE_DIR/last-alert-$check"
          local now last=0
          now=$(date +%s)
          if [ -f "$stamp" ]; then
            last=$(cat "$stamp" 2>/dev/null || printf '0')
          fi
          if [ $((now - last)) -ge "$ALERT_COOLDOWN_SECS" ]; then
            printf '%s\n' "$now" > "$stamp"
            notify-send --app-name=hey-computer --urgency=normal \
              "Proactive check failed ($check)" "$msg" >/dev/null 2>&1 || true
          fi
        }

        session_unlocked() {
          if pgrep -x hyprlock >/dev/null 2>&1; then
            return 1
          fi
          if dbus-send --print-reply --dest=org.freedesktop.secrets \
            /org/freedesktop/secrets/aliases/default \
            org.freedesktop.DBus.Properties.Get \
            string:org.freedesktop.Secret.Collection \
            string:Locked 2>/dev/null | grep -q "boolean true"; then
            return 1
          fi
          return 0
        }

        network_online() {
          ip -4 route show default 2>/dev/null | grep -q '^default ' \
            || ip -6 route show default 2>/dev/null | grep -q '^default '
        }

        daemon_ready() {
          local status_json agent
          status_json=$(${heyComputer} status --json 2>/dev/null) || return 1
          agent=$(jq -r '.agent // "down"' <<<"$status_json" 2>/dev/null || printf 'down')
          [ "$agent" != "down" ]
        }

        classify_location() {
          local monitors_json="" ips="" gateways=""
          monitors_json=$(hyprctl monitors -j 2>/dev/null || printf '[]')
          ips=$(ip -4 -o addr show scope global 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))' || printf '[]')
          gateways=$(ip -4 route show default 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))' || printf '[]')

          if [ -f "$CONFIG_FILE" ]; then
            local matched
            matched=$(jq -r \
              --argjson monitors "$monitors_json" \
              --argjson ips "$ips" \
              --argjson gateways "$gateways" '
              def any_match($haystacks; $needles):
                ($needles // []) as $ns |
                if ($ns | length) == 0 then false
                else any($haystacks[]; . as $h | any($ns[]; . as $n | ($n | length) > 0 and ($h | ascii_downcase | contains($n | ascii_downcase))))
                end;
              ($monitors | map([.name, .description, .make, .model, .serial] | map(select(. != null)) | join(" "))) as $mon_strs |
              if (any_match($ips; .work.ip_prefixes) or any_match($gateways; .work.gateways) or any_match($mon_strs; .work.monitors)) then
                "work"
              elif (any_match($ips; .home.ip_prefixes) or any_match($gateways; .home.gateways) or any_match($mon_strs; .home.monitors)) then
                "home"
              else
                "other"
              end
            ' "$CONFIG_FILE" 2>/dev/null || printf 'other')
            printf '%s\n' "$matched"
            return 0
          fi

          printf 'other\n'
        }

        run_morning_digest() {
          local today stamp loc prompt
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/morning-digest.last"

          # Already ran today: silent 0-token no-op.
          if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
            exit 0
          fi

          # Wait quietly until the user unlocks the desktop and network is up.
          session_unlocked || exit 0
          network_online || exit 0

          if ! daemon_ready; then
            log_failure "morning-digest" "hey-computer daemon is not ready; will retry on next tick."
            exit 1
          fi

          loc=$(classify_location)
          prompt="Morning digest for $today (detected location: $loc). Check today's Google Calendar events, important unread Gmail messages since last evening, and any urgent Slack/Linear mentions if available. Append a concise '## Morning Brief' section to today's daily note Journal/$today.md (creating it cleanly if needed) and reply with a short 2-3 sentence spoken-style summary. If nothing at all is on the calendar and there are no notable messages or mentions, reply with exactly HEARTBEAT_OK."

          if ${heyComputer} ask --background --profile deep --suppress-token HEARTBEAT_OK "$prompt" >/dev/null 2>&1; then
            printf '%s\n' "$today" > "$stamp"
          else
            log_failure "morning-digest" "failed to submit morning digest task to hey-computer."
            exit 1
          fi
        }

        run_pre_daily() {
          local today stamp loc prompt
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/pre-daily.last"

          if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
            exit 0
          fi

          session_unlocked || exit 0
          network_online || exit 0

          loc=$(classify_location)
          # If the user configured location rules and is neither at work nor home, skip quietly.
          if [ -f "$CONFIG_FILE" ] && [ "$loc" = "other" ]; then
            exit 0
          fi

          if ! daemon_ready; then
            log_failure "pre-daily" "hey-computer daemon is not ready before the 10:00 daily."
            exit 1
          fi

          prompt="Pre-daily standup brief (10:00 daily, $today, location: $loc). First check today's Google Calendar: if I am out of office / on vacation or there is no 10:00 daily today, reply with exactly HEARTBEAT_OK. Otherwise, summarize in 3-5 concise bullets: (1) my active Linear issues / recent GitLab MR updates from yesterday, (2) any relevant Slack mentions since yesterday afternoon, and (3) what is on today's schedule after the daily."

          if ${heyComputer} ask --background --profile deep --suppress-token HEARTBEAT_OK "$prompt" >/dev/null 2>&1; then
            printf '%s\n' "$today" > "$stamp"
          else
            log_failure "pre-daily" "failed to submit pre-daily brief task to hey-computer."
            exit 1
          fi
        }

        case "''${1-}" in
        location)
          classify_location
          ;;
        morning-digest)
          run_morning_digest
          ;;
        pre-daily)
          run_pre_daily
          ;;
        *)
          echo "Usage: hey-computer-proactive <location|morning-digest|pre-daily>" >&2
          exit 2
          ;;
        esac
      '';
  };
}
