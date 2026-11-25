# Shell-gated proactive automation for hey-computer (#26, #33, #34):
# - `location`: classifies current environment as `work`, `home`, or `other`
#   using connected monitor descriptions/models (`hyprctl monitors -j`) and
#   optional user-local `~/.config/hey-computer/locations.json` rules (IP prefix,
#   default gateway, monitor substrings, or per-location `{city,latitude,longitude}`
#   overrides — keeping private IPs and network names out of git).
# - `weather [location]`: fetches today's Open-Meteo daily forecast using VPN-safe
#   coordinates, persists 14 days atomically in `weather-history.json`, and emits
#   a deterministic day-over-day delta (`changed`, `unchanged`, or `unavailable`).
# - `workday [--refresh] [--cached-only] [--json|--quiet]`: deterministic 0-token
#   workday detector backed by a 30-minute TTL cache in `$STATE_DIR/workday.json`
#   (mode `0600`). Resolves `day_off` in 0 ms when work mode is disabled or on
#   weekends, and queries personal Google Calendar (`events.list`) on weekdays
#   for `"Arbeit"` minus out-of-office / all-day absence overrides.
# - `collect-morning-digest`: fast 0-token pre-collector for hey-computer's native
#   `[scheduler.jobs.morning-digest]` cron (`*/5 5-14 * * *`). Queries
#   `hey-computer schedule show morning-digest --json` (`last_run_at`,
#   `last_status`): exits 0 with empty stdout when today already succeeded/suppressed,
#   when within a 15-minute failure retry cooldown, or while locked/offline
#   (bypassed when `HEY_COMPUTER_SCHEDULE_MANUAL=1`); otherwise prints `date`,
#   `location`, `workday_*`, and the deterministic `weather_*` block so the
#   scheduler wakes the agent.
# - `collect-pre-daily`: fast 0-token pre-collector for `[scheduler.jobs.pre-daily]`
#   (`weekdays 09:56`). Exits 0 with empty stdout while locked/offline, away from
#   work/home, or on a `day_off` (bypassed when `HEY_COMPUTER_SCHEDULE_MANUAL=1`);
#   otherwise prints `date`, `location`, and `workday_*`.
# - `morning-digest` / `pre-daily`: manual CLI runners retained for ad-hoc testing.
{
  pkgs,
  lib,
  config,
  systemArgs,
  helpers,
  ...
}: let
  hmCfg = config.home-manager.users.${systemArgs.username};
  hcCfg = hmCfg.programs.configured.hey-computer;
  heyComputer = lib.getExe hmCfg.programs.hey-computer.package;
  defaultCity = hmCfg.programs.configured.waybar.weatherLocation or "Hamburg";
  defaultLat = toString (hmCfg.services.configured.darkman.latitude or 53.54);
  defaultLon = toString (hmCfg.services.configured.darkman.longitude or 9.98);
  workEnabled = hcCfg.work.enable or (systemArgs.useWorkProfileByDefault or false);
  personalGoogleEmail =
    hcCfg.personalEmail
    or (
      if (systemArgs.useWorkProfileByDefault or false)
      then "marius.niveri@gmail.com"
      else systemArgs.git.email
    );
  workGoogleEmail =
    hcCfg.work.email
    or (
      if (systemArgs.useWorkProfileByDefault or false)
      then systemArgs.git.email
      else "marius@meetovo.de"
    );
  workSlackEmailDmChannel = hcCfg.work.slackEmailDmChannel or "D0BKG91AAAJ";
  googleCredsDir =
    hcCfg.googleWorkspace.credentialsDir
    or "${hmCfg.xdg.stateHome}/google-workspace-mcp/credentials";
  googleWorkspacePython = pkgs.python3.withPackages (_: pkgs.google-workspace-mcp.dependencies);
  googleWorkspaceSitePackages = "${pkgs.google-workspace-mcp}/${pkgs.python3.sitePackages}";

  workdayCheckScript = pkgs.writeText "hey-computer-workday.py" ''
    import json
    import logging
    import os
    import re
    import sys
    import tempfile
    import time
    from datetime import date, datetime, timedelta
    from zoneinfo import ZoneInfo

    import requests
    from google.auth.transport.requests import Request as GoogleAuthRequest

    logging.getLogger("auth").setLevel(logging.CRITICAL)

    ARBEIT_RE = re.compile(r"^arbeit(?:\b|[\s:–—-]|$)", re.IGNORECASE)
    ABSENCE_RE = re.compile(
        r"(?i)(?:^frei$|\b(?:"
        r"urlaub|vacation|pto|time\s+off|day\s+off|freier?\s+tag|"
        r"gleittag|flex\s+day|sonderurlaub|überstundenabbau|"
        r"out\s+of\s+office|ooo|abwesend|krank|krankmeldung|"
        r"sick(?:\s+day|\s+leave)?|feiertag|public\s+holiday|bank\s+holiday"
        r")\b)"
    )


    class _TimeoutSession(requests.Session):
        def __init__(self, timeout: float = 5.0) -> None:
            super().__init__()
            self._timeout = timeout

        def request(self, *args, **kwargs):
            kwargs.setdefault("timeout", self._timeout)
            return super().request(*args, **kwargs)


    def get_local_tz():
        tz_name = os.environ.get("WORKDAY_TZ") or os.environ.get("TZ") or "Europe/Berlin"
        try:
            return ZoneInfo(tz_name)
        except Exception:
            return datetime.now().astimezone().tzinfo


    def write_json_atomic(path: str, payload: dict) -> None:
        parent = os.path.dirname(path) or "."
        os.makedirs(parent, mode=0o700, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(dir=parent, prefix=".tmp-workday-")
        try:
            os.chmod(tmp_path, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump(payload, fh, ensure_ascii=False)
                fh.write("\n")
            os.replace(tmp_path, path)
        except Exception:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise


    def _parse_iso_dt(raw: str, tz) -> datetime:
        dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            return dt.replace(tzinfo=tz)
        return dt.astimezone(tz)


    def _is_declined_by_self(event: dict) -> bool:
        for att in event.get("attendees") or []:
            if isinstance(att, dict) and att.get("self") is True and att.get("responseStatus") == "declined":
                return True
        return False


    def evaluate_events(
        events: list[dict],
        today: date,
        tz=None,
        checked_at: int | None = None,
    ) -> dict:
        if tz is None:
            tz = get_local_tz()
        if checked_at is None:
            checked_at = int(time.time())

        today_str = today.isoformat()
        if today.isoweekday() in (6, 7):
            return {
                "date": today_str,
                "checked_at": checked_at,
                "status": "day_off",
                "is_workday": False,
                "workday": False,
                "reason": "weekend",
                "arbeit_event": None,
                "override_event": None,
            }

        day_start = datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=tz)
        next_day = today + timedelta(days=1)
        day_end = datetime(next_day.year, next_day.month, next_day.day, 0, 0, 0, tzinfo=tz)
        work_win_start = datetime(today.year, today.month, today.day, 8, 0, 0, tzinfo=tz)
        work_win_end = datetime(today.year, today.month, today.day, 18, 0, 0, tzinfo=tz)

        arbeit_label: str | None = None
        arbeit_windows: list[tuple[datetime, datetime]] = []
        ooo_candidates: list[tuple[str, datetime, datetime]] = []
        all_day_override: str | None = None

        for ev in events:
            if not isinstance(ev, dict):
                continue
            if ev.get("status") == "cancelled":
                continue
            if _is_declined_by_self(ev):
                continue

            start = ev.get("start") or {}
            end = ev.get("end") or {}
            summary = (ev.get("summary") or "").strip()
            event_type = ev.get("eventType") or "default"

            is_all_day = "date" in start and "dateTime" not in start
            if is_all_day:
                try:
                    start_date = date.fromisoformat(start["date"])
                    end_date = (
                        date.fromisoformat(end["date"])
                        if "date" in end
                        else start_date + timedelta(days=1)
                    )
                except (TypeError, ValueError):
                    continue
                if not (start_date <= today < end_date):
                    continue
                ev_start = day_start
                ev_end = day_end
                label = summary or "Out of office"
            elif "dateTime" in start:
                try:
                    ev_start = _parse_iso_dt(start["dateTime"], tz)
                    ev_end = (
                        _parse_iso_dt(end["dateTime"], tz)
                        if "dateTime" in end
                        else ev_start
                    )
                except (TypeError, ValueError):
                    continue
                if ev_end == ev_start:
                    if not (day_start <= ev_start < day_end):
                        continue
                elif not (ev_end > day_start and ev_start < day_end):
                    continue
                time_span = f"{ev_start.strftime('%H:%M')}–{ev_end.strftime('%H:%M')}"
                label = f"{summary} ({time_span})" if summary else f"Out of office ({time_span})"
            else:
                continue

            if event_type == "outOfOffice":
                ooo_candidates.append((label, ev_start, ev_end))

            if is_all_day and summary and ABSENCE_RE.search(summary):
                if all_day_override is None:
                    all_day_override = summary

            if summary and ARBEIT_RE.match(summary):
                if arbeit_label is None:
                    arbeit_label = label
                arbeit_windows.append((ev_start, ev_end))

        override_label: str | None = None
        for label, ooo_start, ooo_end in ooo_candidates:
            win_overlap = (
                min(ooo_end, work_win_end) - max(ooo_start, work_win_start)
            ).total_seconds()
            overlaps_arbeit = any(
                ooo_end > a_start and ooo_start < a_end
                for a_start, a_end in arbeit_windows
            )
            if win_overlap >= 4 * 3600 or overlaps_arbeit:
                override_label = label
                break

        if override_label is None and all_day_override is not None:
            override_label = all_day_override

        if arbeit_label is None:
            return {
                "date": today_str,
                "checked_at": checked_at,
                "status": "day_off",
                "is_workday": False,
                "workday": False,
                "reason": "no_arbeit_event",
                "arbeit_event": None,
                "override_event": override_label,
            }

        if override_label is not None:
            return {
                "date": today_str,
                "checked_at": checked_at,
                "status": "day_off",
                "is_workday": False,
                "workday": False,
                "reason": "vacation_override",
                "arbeit_event": arbeit_label,
                "override_event": override_label,
            }

        return {
            "date": today_str,
            "checked_at": checked_at,
            "status": "workday",
            "is_workday": True,
            "workday": True,
            "reason": "arbeit_scheduled",
            "arbeit_event": arbeit_label,
            "override_event": None,
        }


    def _unknown_result(today_str: str, checked_at: int, reason: str) -> dict:
        return {
            "date": today_str,
            "checked_at": checked_at,
            "status": "unknown",
            "is_workday": True,
            "workday": True,
            "reason": reason,
            "arbeit_event": None,
            "override_event": None,
        }


    def _store_credentials_atomic(creds_path: str, creds) -> None:
        creds_data = {
            "token": creds.token,
            "refresh_token": creds.refresh_token,
            "token_uri": creds.token_uri,
            "client_id": creds.client_id,
            "client_secret": creds.client_secret,
            "scopes": list(creds.scopes) if creds.scopes is not None else None,
            "expiry": creds.expiry.isoformat() if creds.expiry else None,
        }
        write_json_atomic(creds_path, creds_data)


    def check_calendar_workday(email: str, creds_dir: str, today: date, cache_path: str) -> dict:
        tz = get_local_tz()
        now = int(time.time())
        today_str = today.isoformat()

        if today.isoweekday() in (6, 7):
            result = evaluate_events([], today, tz=tz, checked_at=now)
            write_json_atomic(cache_path, result)
            return result

        if not creds_dir or not os.path.isdir(creds_dir):
            result = _unknown_result(today_str, now, "missing_credentials")
            write_json_atomic(cache_path, result)
            return result

        try:
            from auth.credential_store import LocalDirectoryCredentialStore

            store = LocalDirectoryCredentialStore(creds_dir)
            creds = store.get_credential(email)
        except Exception:
            result = _unknown_result(today_str, now, "missing_credentials")
            write_json_atomic(cache_path, result)
            return result

        if creds is None:
            result = _unknown_result(today_str, now, "missing_credentials")
            write_json_atomic(cache_path, result)
            return result

        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(GoogleAuthRequest(session=_TimeoutSession(timeout=5.0)))
                    creds_path = store._get_credential_path(email)
                    _store_credentials_atomic(creds_path, creds)
                except Exception:
                    result = _unknown_result(today_str, now, "api_error")
                    write_json_atomic(cache_path, result)
                    return result
            else:
                result = _unknown_result(today_str, now, "missing_credentials")
                write_json_atomic(cache_path, result)
                return result

        day_start = datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=tz)
        next_day = today + timedelta(days=1)
        day_end = datetime(next_day.year, next_day.month, next_day.day, 0, 0, 0, tzinfo=tz)

        try:
            resp = requests.get(
                "https://www.googleapis.com/calendar/v3/calendars/primary/events",
                headers={"Authorization": f"Bearer {creds.token}"},
                params={
                    "singleEvents": "true",
                    "timeMin": day_start.isoformat(),
                    "timeMax": day_end.isoformat(),
                    "maxResults": "100",
                    "orderBy": "startTime",
                },
                timeout=5,
            )
            resp.raise_for_status()
            payload = resp.json()
            items = payload.get("items") or []
            if not isinstance(items, list):
                raise ValueError("Calendar API returned non-list items")
        except Exception:
            result = _unknown_result(today_str, now, "api_error")
            write_json_atomic(cache_path, result)
            return result

        result = evaluate_events(items, today, tz=tz, checked_at=now)
        write_json_atomic(cache_path, result)
        return result


    def main() -> int:
        if len(sys.argv) != 5:
            sys.stderr.write("Usage: hey-computer-workday.py <email> <creds_dir> <YYYY-MM-DD> <cache_path>\n")
            return 2
        email, creds_dir, today_str, cache_path = sys.argv[1:5]
        today = date.fromisoformat(today_str)
        result = check_calendar_workday(email, creds_dir, today, cache_path)
        sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n")
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';

  morningDigestPromptFile = pkgs.writeText "morning-digest-prompt.txt" (
    if workEnabled
    then ''
      Prepare today's Morning Brief using the `date`, `location`, `workday_*`, and `weather_*` fields in `<untrusted_collector_output>`.

      Step 1 — Determine Workday vs. Day Off BEFORE calling any work tools:
      - Read `workday_status` in `<untrusted_collector_output>`:
        - `workday_status: day_off` → Today is a **Weekend / Day Off** (personal-only mode).
        - `workday_status: workday` → Today is a **Working Day** (personal + work mode).
        - `workday_status: unknown` (or absent) → Query **personal** Google Calendar (`${personalGoogleEmail}`) for today FIRST before touching any work tool. Treat today as a **Working Day** ONLY if today is Mon–Fri, has an `"Arbeit"` event on `${personalGoogleEmail}`, and has no all-day vacation / out-of-office override; otherwise treat today as a **Weekend / Day Off**.

      Step 2 — Gather context strictly according to the mode:
      - **Always (Personal):**
        - Today's personal Google Calendar events (`${personalGoogleEmail}`, 24-hour times).
        - Important unread personal Gmail messages (`${personalGoogleEmail}`) since last evening.
        - Overdue or due-today personal Google Tasks (`${personalGoogleEmail}`) and open `- [ ]` items in today's `Journal/<date>.md` if it already exists.
      - **ONLY on a Working Day (strictly SKIP on Weekends / Days Off — do NOT call `slack`, `linear`, `gitlab`, or query `${workGoogleEmail}`):**
        - Today's work Google Calendar events (`${workGoogleEmail}`, 24-hour times).
        - Recent non-noise forwarded work emails in Slack DM `${workSlackEmailDmChannel}` (never Gmail for `${workGoogleEmail}`).
        - Urgent Slack mentions/DMs, active Linear mentions/blockers, and GitLab MRs needing attention (reviews requested, failed pipelines, or new threads).

      If nothing at all is on today's relevant calendar(s) and there are no notable messages, mentions, or due tasks, reply with exactly `HEARTBEAT_OK` and do not modify the daily note.

      Otherwise, write and reply with the full editorial Markdown brief directly (never a 2-sentence summary):
      1. Start with `# Morning Brief — <Weekday>, <D Month>` (e.g. `# Morning Brief — Wednesday, 25 November`).
      2. Immediately below the H1, write a single plain-prose opening paragraph of 3–4 sentences (~50–80 words) beginning with a normal capitalized letter — never a bullet list, blockquote, emoji, quotation mark, bold/italic marker, or code span first (this paragraph renders with a Reforma 1969 editorial drop cap). On days off, let the prose reflect an unhurried off-work day without mentioning skipped work tools.
      3. Opening cadence: warm, observant, lightly poetic editorial prose that notices the real shape and rhythm of the day ahead (open stretches, meeting clusters, transitions). No exclamation marks, and never use clichés such as "tapestry", "symphony", "whispers", "gentle reminder", or "embrace the day".
      4. Weather rule (strict): ONLY if `weather_status: changed` in `<untrusted_collector_output>`, weave `weather_today` and the concrete shift from `weather_delta` naturally into the opening paragraph. If `weather_status` is `unchanged`, `unavailable`, or absent, omit weather completely and silently — do not mention forecasts, temperatures, sky conditions, or that weather is unchanged.
      5. Below the opening paragraph, include crisp, scannable `##` sections (`## Schedule`, `## Mail & Messages`, `## Work & Reviews`, `## Tasks & Focus` as applicable; omit `## Work & Reviews` and any empty section on days off) with 24-hour `HH:MM` times, concrete senders, and concise items.
      6. Widget restraint: call `show_widget` (`calendar_agenda`) at most once, and only when today has 3 or more timed events or a scheduling conflict.
      7. Idempotent daily-note sync: update today's `Journal/<date>.md` in the Obsidian vault. Create the file cleanly if needed, or if a `## Morning Brief` section already exists, replace it in place (up to the next `## ` heading or EOF) without duplicating on re-runs and without disturbing frontmatter, existing `- [ ]` tasks, or other notes. Inside `Journal/<date>.md`, nest the brief under `## Morning Brief` using `###` subheadings.
    ''
    else ''
      Prepare today's Morning Brief using the `date`, `location`, `workday_*`, and `weather_*` fields in `<untrusted_collector_output>`.

      Gather context (personal-only mode):
      - Today's personal Google Calendar events (`${personalGoogleEmail}`, 24-hour times).
      - Important unread personal Gmail messages (`${personalGoogleEmail}`) since last evening.
      - Overdue or due-today personal Google Tasks (`${personalGoogleEmail}`) and open `- [ ]` items in today's `Journal/<date>.md` if it already exists.

      If nothing at all is on today's calendar and there are no notable messages or due tasks, reply with exactly `HEARTBEAT_OK` and do not modify the daily note.

      Otherwise, write and reply with the full editorial Markdown brief directly (never a 2-sentence summary):
      1. Start with `# Morning Brief — <Weekday>, <D Month>` (e.g. `# Morning Brief — Wednesday, 25 November`).
      2. Immediately below the H1, write a single plain-prose opening paragraph of 3–4 sentences (~50–80 words) beginning with a normal capitalized letter — never a bullet list, blockquote, emoji, quotation mark, bold/italic marker, or code span first (this paragraph renders with a Reforma 1969 editorial drop cap).
      3. Opening cadence: warm, observant, lightly poetic editorial prose that notices the real shape and rhythm of the day ahead (open stretches, meeting clusters, transitions). No exclamation marks, and never use clichés such as "tapestry", "symphony", "whispers", "gentle reminder", or "embrace the day".
      4. Weather rule (strict): ONLY if `weather_status: changed` in `<untrusted_collector_output>`, weave `weather_today` and the concrete shift from `weather_delta` naturally into the opening paragraph. If `weather_status` is `unchanged`, `unavailable`, or absent, omit weather completely and silently — do not mention forecasts, temperatures, sky conditions, or that weather is unchanged.
      5. Below the opening paragraph, include crisp, scannable `##` sections (`## Schedule`, `## Mail & Messages`, `## Tasks & Focus` as applicable) with 24-hour `HH:MM` times, concrete senders, and concise items. Omit any empty section.
      6. Widget restraint: call `show_widget` (`calendar_agenda`) at most once, and only when today has 3 or more timed events or a scheduling conflict.
      7. Idempotent daily-note sync: update today's `Journal/<date>.md` in the Obsidian vault. Create the file cleanly if needed, or if a `## Morning Brief` section already exists, replace it in place (up to the next `## ` heading or EOF) without duplicating on re-runs and without disturbing frontmatter, existing `- [ ]` tasks, or other notes. Inside `Journal/<date>.md`, nest the brief under `## Morning Brief` using `###` subheadings.
    ''
  );

  preDailyPromptFile = pkgs.writeText "pre-daily-prompt.txt" ''
    Pre-daily standup brief (10:00 daily, using `date`, `location`, and `workday_*` from `<untrusted_collector_output>`).
    1. Day-off gate (check FIRST before any work tools):
       - If `workday_status: day_off` in `<untrusted_collector_output>`, reply immediately with exactly `HEARTBEAT_OK` without calling any tools.
       - If `workday_status` is `unknown` or absent, query ONLY personal Google Calendar (`${personalGoogleEmail}`) for today first: if today is not Mon–Fri, has no `"Arbeit"` event, or has an all-day vacation / out-of-office override, reply immediately with exactly `HEARTBEAT_OK` without calling Slack, Linear, GitLab, or work Google Calendar.
    2. Next check work Google Calendar (`${workGoogleEmail}`) for today: if I am out of office or there is no 10:00 daily meeting today, reply with exactly `HEARTBEAT_OK`.
    3. Otherwise, summarize in 3–5 concise bullets: (1) my active Linear issues and recent GitLab MR updates since yesterday, (2) relevant Slack mentions since yesterday afternoon, and (3) what is on today's schedule after the daily.
  '';
in {
  hey-computer-proactive = helpers.mkScript {
    name = "hey-computer-proactive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
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
        WEATHER_HISTORY="$STATE_DIR/weather-history.json"
        WEATHER_GEOCACHE="$STATE_DIR/weather-geocache.json"
        WORKDAY_CACHE="$STATE_DIR/workday.json"
        DEFAULT_WEATHER_CITY=${lib.escapeShellArg defaultCity}
        DEFAULT_WEATHER_LAT=${lib.escapeShellArg defaultLat}
        DEFAULT_WEATHER_LON=${lib.escapeShellArg defaultLon}
        WORK_ENABLED=${lib.escapeShellArg (
          if workEnabled
          then "1"
          else "0"
        )}
        PERSONAL_GOOGLE_EMAIL=${lib.escapeShellArg personalGoogleEmail}
        GOOGLE_CREDS_DIR=${lib.escapeShellArg googleCredsDir}
        WORKDAY_TTL_SECS=1800
        WORKDAY_UNKNOWN_TTL_SECS=120
        ALERT_COOLDOWN_SECS=14400 # 4 hours

        install -d -m 700 "$STATE_DIR"

        write_json_atomic() {
          local target="$1"
          local content="$2"
          local tmp
          tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX") || return 1
          chmod 600 "$tmp"
          if printf '%s\n' "$content" > "$tmp" && mv -f "$tmp" "$target"; then
            return 0
          fi
          rm -f "$tmp"
          return 1
        }

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
          dbus-send --print-reply --dest=org.freedesktop.secrets \
            /org/freedesktop/secrets/aliases/default \
            org.freedesktop.DBus.Properties.Get \
            string:org.freedesktop.Secret.Collection \
            string:Locked 2>/dev/null | grep -q "boolean false"
        }

        use_live_hyprland_instance() {
          local instances sig
          instances=$(hyprctl instances -j 2>/dev/null) || return 0
          sig=$(jq -r --arg sig "''${HYPRLAND_INSTANCE_SIGNATURE:-}" --arg wl "''${WAYLAND_DISPLAY:-}" \
            '(map(select(.instance == $sig)) + map(select(.wl_socket == $wl)) + .)[0].instance // empty' <<<"$instances" 2>/dev/null || true)
          if [ -n "$sig" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          fi
        }

        network_online() {
          ip -4 route show default 2>/dev/null | grep -q '^default ' \
            || ip -6 route show default 2>/dev/null | grep -q '^default '
        }

        daemon_ready() {
          local status_json agent
          status_json=$(${heyComputer} status --json 2>/dev/null) || return 1
          agent=$(jq -r '.agent // "down"' <<<"$status_json" 2>/dev/null || printf 'down')
          [ "$agent" != "down" ] && [ "$agent" != "locked" ]
        }

        classify_location() {
          use_live_hyprland_instance
          local monitors_json="" ips="" gateways="" rules_json='{"work":{"monitors":["LS27D70xE","HK2YA02261"]},"home":{"monitors":["27GL850","912NTVSCD959"]}}'
          monitors_json=$(hyprctl monitors -j 2>/dev/null || printf '[]')
          ips=$(ip -4 -o addr show scope global 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))' || printf '[]')
          gateways=$(ip -4 route show default 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))' || printf '[]')

          if [ -f "$CONFIG_FILE" ]; then
            rules_json=$(jq -c --argjson base "$rules_json" '$base * .' "$CONFIG_FILE" 2>/dev/null || printf '%s' "$rules_json")
          fi

          jq -rn \
            --argjson rules "$rules_json" \
            --argjson monitors "$monitors_json" \
            --argjson ips "$ips" \
            --argjson gateways "$gateways" '
            def any_match($haystacks; $needles):
              ($needles // []) as $ns |
              if ($ns | length) == 0 then false
              else any($haystacks[]; . as $h | any($ns[]; . as $n | ($n | length) > 0 and ($h | ascii_downcase | contains($n | ascii_downcase))))
              end;
            ($monitors | map([.name, .description, .make, .model, .serial] | map(select(. != null)) | join(" "))) as $mon_strs |
            if (any_match($ips; $rules.work.ip_prefixes) or any_match($gateways; $rules.work.gateways) or any_match($mon_strs; $rules.work.monitors)) then
              "work"
            elif (any_match($ips; $rules.home.ip_prefixes) or any_match($gateways; $rules.home.gateways) or any_match($mon_strs; $rules.home.monitors)) then
              "home"
            else
              "other"
            end
          ' 2>/dev/null || printf 'other\n'
        }

        run_and_wait_task() {
          local check="$1"
          local stamp="$2"
          local today="$3"
          local prompt="$4"
          local task_id task_json status err_msg deadline

          if ! task_id=$(${heyComputer} ask --background --profile deep --suppress-token HEARTBEAT_OK "$prompt" 2>/dev/null) \
            || ! [[ "$task_id" =~ ^[0-9]+$ ]]; then
            log_failure "$check" "failed to submit $check task to hey-computer."
            return 1
          fi

          # Wait up to 20 minutes for the queued/running background task to
          # reach a terminal status so `.last` is only stamped on real success
          # and execution errors (such as LimitReached) land in failures.log.
          deadline=$(( $(date +%s) + 1200 ))
          while [ "$(date +%s)" -lt "$deadline" ]; do
            sleep 2
            if ! task_json=$(${heyComputer} tasks show "$task_id" --json 2>/dev/null); then
              continue
            fi
            status=$(jq -r '.status // ""' <<<"$task_json" 2>/dev/null || true)
            case "$status" in
            completed|suppressed)
              printf '%s\n' "$today" > "$stamp"
              return 0
              ;;
            failed|cancelled)
              err_msg=$(jq -r '.error_message // .fail_reason // "task failed"' <<<"$task_json" 2>/dev/null || printf 'task failed')
              log_failure "$check" "task #$task_id $status: $err_msg"
              return 1
              ;;
            esac
          done

          log_failure "$check" "timed out waiting for background task #$task_id"
          return 1
        }

        resolve_weather_coords() {
          local loc="$1"
          local city="$DEFAULT_WEATHER_CITY"
          local lat="$DEFAULT_WEATHER_LAT"
          local lon="$DEFAULT_WEATHER_LON"
          local cfg_city="" cfg_lat="" cfg_lon=""

          if [ -f "$CONFIG_FILE" ]; then
            local cfg_lines=()
            mapfile -t cfg_lines < <(
              jq -r --arg loc "$loc" '
                (.[$loc] // {}) as $e |
                (if ($e.city | type) == "string" then $e.city else "" end),
                (if ($e.latitude | type) == "number" then ($e.latitude | tostring) else "" end),
                (if ($e.longitude | type) == "number" then ($e.longitude | tostring) else "" end)
              ' "$CONFIG_FILE" 2>/dev/null || true
            )
            cfg_city="''${cfg_lines[0]:-}"
            cfg_lat="''${cfg_lines[1]:-}"
            cfg_lon="''${cfg_lines[2]:-}"
          fi

          if [ -n "$cfg_lat" ] && [ -n "$cfg_lon" ]; then
            lat="$cfg_lat"
            lon="$cfg_lon"
            if [ -n "$cfg_city" ]; then
              city="$cfg_city"
            fi
          elif [ -n "$cfg_city" ]; then
            if [ "''${cfg_city,,}" = "''${DEFAULT_WEATHER_CITY,,}" ]; then
              city="$cfg_city"
            else
              local city_key="''${cfg_city,,}"
              local cached=()
              if [ -f "$WEATHER_GEOCACHE" ]; then
                mapfile -t cached < <(
                  jq -r --arg k "$city_key" '
                    .[$k] | select(type == "object" and (.lat | type) == "number" and (.lon | type) == "number") |
                    (.lat | tostring), (.lon | tostring)
                  ' "$WEATHER_GEOCACHE" 2>/dev/null || true
                )
              fi
              if [ -n "''${cached[0]:-}" ] && [ -n "''${cached[1]:-}" ]; then
                city="$cfg_city"
                lat="''${cached[0]}"
                lon="''${cached[1]}"
              else
                local geo_resp="" geo_lines=()
                if geo_resp=$(curl -fsSL --connect-timeout 3 --max-time 5 --get \
                  --data-urlencode "name=$cfg_city" \
                  --data-urlencode "count=1" \
                  --data-urlencode "language=en" \
                  --data-urlencode "format=json" \
                  "https://geocoding-api.open-meteo.com/v1/search" 2>/dev/null); then
                  mapfile -t geo_lines < <(
                    jq -r '
                      (.results[0] // empty) |
                      select((.latitude | type) == "number" and (.longitude | type) == "number") |
                      (.latitude | tostring), (.longitude | tostring)
                    ' <<<"$geo_resp" 2>/dev/null || true
                  )
                fi
                if [ -n "''${geo_lines[0]:-}" ] && [ -n "''${geo_lines[1]:-}" ]; then
                  city="$cfg_city"
                  lat="''${geo_lines[0]}"
                  lon="''${geo_lines[1]}"
                  local existing_cache="{}" updated_cache=""
                  if [ -f "$WEATHER_GEOCACHE" ]; then
                    existing_cache=$(jq -c 'if type == "object" then . else {} end' "$WEATHER_GEOCACHE" 2>/dev/null || printf '{}')
                  fi
                  if updated_cache=$(jq -c --arg k "$city_key" --arg city "$city" --argjson lat "$lat" --argjson lon "$lon" \
                    '. + {($k): {city: $city, lat: $lat, lon: $lon}}' <<<"$existing_cache" 2>/dev/null); then
                    write_json_atomic "$WEATHER_GEOCACHE" "$updated_cache" || true
                  fi
                fi
              fi
            fi
          fi

          jq -cn --arg city "$city" --argjson lat "$lat" --argjson lon "$lon" \
            '{city: $city, lat: $lat, lon: $lon}'
        }

        fetch_weather_snapshot() {
          local today="$1"
          local coords_json="$2"
          local city lat lon api_json
          city=$(jq -r '.city' <<<"$coords_json")
          lat=$(jq -r '.lat' <<<"$coords_json")
          lon=$(jq -r '.lon' <<<"$coords_json")

          api_json=$(curl -fsSL --connect-timeout 3 --max-time 5 --get \
            --data-urlencode "latitude=$lat" \
            --data-urlencode "longitude=$lon" \
            --data-urlencode "daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,precipitation_probability_max,wind_gusts_10m_max,sunrise,sunset" \
            --data-urlencode "timezone=auto" \
            --data-urlencode "forecast_days=1" \
            "https://api.open-meteo.com/v1/forecast" 2>/dev/null) || return 1

          jq -c --arg today "$today" --arg city "$city" --argjson lat "$lat" --argjson lon "$lon" '
            def wmo_bucket($c):
              if ($c == 0 or $c == 1) then "clear"
              elif $c == 2 then "partly_cloudy"
              elif $c == 3 then "overcast"
              elif ($c == 45 or $c == 48) then "fog"
              elif ($c == 51 or $c == 53 or $c == 55) then "drizzle"
              elif ($c == 56 or $c == 57 or $c == 66 or $c == 67) then "freezing_rain"
              elif ($c == 61 or $c == 63 or $c == 80 or $c == 81) then "rain"
              elif ($c == 65 or $c == 82) then "heavy_rain"
              elif ($c == 71 or $c == 73 or $c == 75 or $c == 77 or $c == 85 or $c == 86) then "snow"
              elif ($c == 95 or $c == 96 or $c == 99) then "thunderstorm"
              else "unknown"
              end;
            def wmo_label($c):
              if $c == 0 then "clear sky"
              elif $c == 1 then "mainly clear"
              elif $c == 2 then "partly cloudy"
              elif $c == 3 then "overcast"
              elif $c == 45 then "fog"
              elif $c == 48 then "rime fog"
              elif $c == 51 then "light drizzle"
              elif $c == 53 then "drizzle"
              elif $c == 55 then "dense drizzle"
              elif ($c == 56 or $c == 57) then "freezing drizzle"
              elif $c == 61 then "light rain"
              elif $c == 63 then "rain"
              elif $c == 65 then "heavy rain"
              elif ($c == 66 or $c == 67) then "freezing rain"
              elif $c == 71 then "light snow"
              elif $c == 73 then "snow"
              elif $c == 75 then "heavy snow"
              elif $c == 77 then "snow grains"
              elif $c == 80 then "light showers"
              elif $c == 81 then "rain showers"
              elif $c == 82 then "heavy showers"
              elif $c == 85 then "snow showers"
              elif $c == 86 then "heavy snow showers"
              elif $c == 95 then "thunderstorm"
              elif ($c == 96 or $c == 99) then "thunderstorm with hail"
              else "mixed conditions"
              end;
            .daily as $d |
            select(
              ($d | type) == "object"
              and (($d.weather_code[0] // null) | type) == "number"
              and (($d.temperature_2m_max[0] // null) | type) == "number"
              and (($d.temperature_2m_min[0] // null) | type) == "number"
            ) |
            ($d.weather_code[0] | floor) as $code |
            {
              date: $today,
              city: $city,
              lat: $lat,
              lon: $lon,
              weather_code: $code,
              condition: wmo_bucket($code),
              condition_label: wmo_label($code),
              temp_max: $d.temperature_2m_max[0],
              temp_min: $d.temperature_2m_min[0],
              feels_max: ($d.apparent_temperature_max[0] // $d.temperature_2m_max[0]),
              feels_min: ($d.apparent_temperature_min[0] // $d.temperature_2m_min[0]),
              precip_mm: ($d.precipitation_sum[0] // 0),
              precip_prob_pct: ($d.precipitation_probability_max[0] // 0),
              wind_gust_kmh: ($d.wind_gusts_10m_max[0] // 0),
              sunrise: (($d.sunrise[0] // "") | split("T")[1] // .),
              sunset: (($d.sunset[0] // "") | split("T")[1] // .)
            }
          ' <<<"$api_json" 2>/dev/null
        }

        evaluate_weather_delta() {
          local history_json="$1"
          local today="$2"
          local yesterday="$3"

          jq -r --arg today "$today" --arg yesterday "$yesterday" '
            def wmo_bucket($c):
              if ($c == 0 or $c == 1) then "clear"
              elif $c == 2 then "partly_cloudy"
              elif $c == 3 then "overcast"
              elif ($c == 45 or $c == 48) then "fog"
              elif ($c == 51 or $c == 53 or $c == 55) then "drizzle"
              elif ($c == 56 or $c == 57 or $c == 66 or $c == 67) then "freezing_rain"
              elif ($c == 61 or $c == 63 or $c == 80 or $c == 81) then "rain"
              elif ($c == 65 or $c == 82) then "heavy_rain"
              elif ($c == 71 or $c == 73 or $c == 75 or $c == 77 or $c == 85 or $c == 86) then "snow"
              elif ($c == 95 or $c == 96 or $c == 99) then "thunderstorm"
              else "unknown"
              end;
            def round1: ((. * 10) | round) / 10;
            def round2: ((. * 100) | round) / 100;
            def signed1: round1 | if . > 0 then "+\(.)" else "\(.)" end;
            def fmt_day($s):
              ($s.condition_label // (wmo_bucket($s.weather_code // -1) | gsub("_"; " "))) as $cond |
              "\($cond), \($s.temp_min | round1)..\($s.temp_max | round1)°C (feels \($s.feels_min | round1)..\($s.feels_max | round1)°C), precip \($s.precip_mm | round1) mm (\($s.precip_prob_pct | round)%), gusts \($s.wind_gust_kmh | round1) km/h"
              + (if (($s.sunrise // "") != "" and ($s.sunset // "") != "") then ", sun \($s.sunrise)–\($s.sunset)" else "" end);

            (.[$today] // null) as $t |
            (.[$yesterday] // null) as $y |

            if $t == null then
              "weather_status: unavailable\nweather_instruction: Weather data is unavailable — OMIT weather completely (do not mention forecasts, temperatures, sky conditions, or that weather is unavailable)."
            elif $y == null then
              "weather_status: changed\n"
              + "weather_city: \($t.city // "unknown")\n"
              + "weather_today: \(fmt_day($t))\n"
              + "weather_yesterday: none (no prior day recorded)\n"
              + "weather_delta: no baseline recorded for yesterday"
            else
              (wmo_bucket($t.weather_code // -1)) as $tb |
              (wmo_bucket($y.weather_code // -1)) as $yb |
              (($t.lat - $y.lat) | round2 | fabs) as $lat_d |
              (($t.lon - $y.lon) | round2 | fabs) as $lon_d |
              ((($t.city // "") | ascii_downcase) != (($y.city // "") | ascii_downcase)) as $city_changed |
              (($t.precip_mm >= 1.0) or ($t.precip_prob_pct >= 40)) as $t_wet |
              (($y.precip_mm >= 1.0) or ($y.precip_prob_pct >= 40)) as $y_wet |
              (($t.precip_mm - $y.precip_mm) | round2) as $precip_d |
              (($t.precip_prob_pct - $y.precip_prob_pct) | round2) as $prob_d |
              (($t_wet != $y_wet) and ((($precip_d | fabs) >= 1.0) or (($prob_d | fabs) >= 20))) as $wet_flip |
              (($precip_d | fabs) >= 4.0) as $precip_jump |
              (($t.temp_max - $y.temp_max) | round2) as $tmax_d |
              (($t.temp_min - $y.temp_min) | round2) as $tmin_d |
              (($t.feels_max - $y.feels_max) | round2) as $fmax_d |
              (($t.temp_min <= 0.0) != ($y.temp_min <= 0.0)) as $freeze_min |
              (($t.temp_max <= 0.0) != ($y.temp_max <= 0.0)) as $freeze_max |
              (($t.wind_gust_kmh - $y.wind_gust_kmh) | round2) as $gust_d |
              (($t.wind_gust_kmh >= 65.0) != ($y.wind_gust_kmh >= 65.0)) as $crossed_65 |
              ((($t.wind_gust_kmh >= 45.0) != ($y.wind_gust_kmh >= 45.0)) and (($gust_d | fabs) >= 10.0)) as $crossed_45 |

              [
                (if $city_changed then
                  "location changed (\($y.city) -> \($t.city))"
                elif ($lat_d >= 0.25 or $lon_d >= 0.25) then
                  "coordinates shifted (\($y.lat),\($y.lon) -> \($t.lat),\($t.lon))"
                else empty end),

                (if $tb != $yb then
                  "conditions shifted (\($yb | gsub("_"; " ")) -> \($tb | gsub("_"; " ")))"
                else empty end),

                (if $wet_flip then
                  if $t_wet then
                    "turning wet (\($t.precip_mm | round1) mm, \($t.precip_prob_pct | round)% vs \($y.precip_mm | round1) mm, \($y.precip_prob_pct | round)%)"
                  else
                    "drying out (\($t.precip_mm | round1) mm, \($t.precip_prob_pct | round)% vs \($y.precip_mm | round1) mm, \($y.precip_prob_pct | round)%)"
                  end
                elif $precip_jump then
                  "precipitation \($precip_d | signed1) mm (\($y.precip_mm | round1) -> \($t.precip_mm | round1) mm)"
                else empty end),

                (if ($tmax_d | fabs) >= 3.0 then
                  "high \($tmax_d | signed1)°C (\($y.temp_max | round1)°C -> \($t.temp_max | round1)°C)"
                else empty end),

                (if ($tmin_d | fabs) >= 3.0 then
                  "low \($tmin_d | signed1)°C (\($y.temp_min | round1)°C -> \($t.temp_min | round1)°C)"
                else empty end),

                (if ($fmax_d | fabs) >= 4.0 then
                  "feels-like high \($fmax_d | signed1)°C (\($y.feels_max | round1)°C -> \($t.feels_max | round1)°C)"
                else empty end),

                (if $freeze_min then
                  if $t.temp_min <= 0.0 then
                    "overnight low dropping to/below freezing (\($y.temp_min | round1)°C -> \($t.temp_min | round1)°C)"
                  else
                    "overnight low rising above freezing (\($y.temp_min | round1)°C -> \($t.temp_min | round1)°C)"
                  end
                else empty end),

                (if $freeze_max then
                  if $t.temp_max <= 0.0 then
                    "daytime high dropping to/below freezing (\($y.temp_max | round1)°C -> \($t.temp_max | round1)°C)"
                  else
                    "daytime high rising above freezing (\($y.temp_max | round1)°C -> \($t.temp_max | round1)°C)"
                  end
                else empty end),

                (if $crossed_65 then
                  "gale-force gusts \(if $t.wind_gust_kmh >= 65.0 then "arriving" else "easing" end) (\($y.wind_gust_kmh | round1) -> \($t.wind_gust_kmh | round1) km/h)"
                elif $crossed_45 then
                  "strong wind gusts \(if $t.wind_gust_kmh >= 45.0 then "picking up" else "calming" end) (\($y.wind_gust_kmh | round1) -> \($t.wind_gust_kmh | round1) km/h)"
                else empty end)
              ] as $reasons |

              if ($reasons | length) > 0 then
                "weather_status: changed\n"
                + "weather_city: \($t.city // "unknown")\n"
                + "weather_today: \(fmt_day($t))\n"
                + "weather_yesterday: \(fmt_day($y))\n"
                + "weather_delta: \($reasons | join("; "))"
              else
                "weather_status: unchanged\n"
                + "weather_instruction: Weather is unchanged from yesterday — OMIT weather completely (do not mention forecasts, temperatures, sky conditions, or that weather is unchanged)."
              end
            end
          ' <<<"$history_json"
        }

        collect_weather_delta() {
          local loc="$1"
          local today="$2"
          local yesterday history_json coords_json today_snap updated_history

          yesterday=$(date -d "$today - 1 day" +%Y-%m-%d)
          history_json="{}"
          if [ -f "$WEATHER_HISTORY" ]; then
            history_json=$(jq -c 'if type == "object" then . else {} end' "$WEATHER_HISTORY" 2>/dev/null || printf '{}')
          fi

          coords_json=$(resolve_weather_coords "$loc")
          today_snap=""
          if today_snap=$(fetch_weather_snapshot "$today" "$coords_json") && [ -n "$today_snap" ]; then
            if updated_history=$(jq -c --arg today "$today" --argjson snap "$today_snap" '
              (. + {($today): $snap})
              | to_entries
              | map(select(.key | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")))
              | sort_by(.key)
              | .[-14:]
              | from_entries
            ' <<<"$history_json" 2>/dev/null) && [ -n "$updated_history" ]; then
              history_json="$updated_history"
              write_json_atomic "$WEATHER_HISTORY" "$history_json" || true
            fi
          fi

          evaluate_weather_delta "$history_json" "$today" "$yesterday"
        }

        make_workday_json() {
          local today="$1"
          local checked_at="$2"
          local status="$3"
          local is_workday="$4"
          local reason="$5"
          jq -cn \
            --arg date "$today" \
            --argjson checked_at "$checked_at" \
            --arg status "$status" \
            --argjson is_workday "$is_workday" \
            --arg reason "$reason" \
            '{
              date: $date,
              checked_at: $checked_at,
              status: $status,
              is_workday: $is_workday,
              workday: $is_workday,
              reason: $reason,
              arbeit_event: null,
              override_event: null
            }'
        }

        cache_matches_static_day_off() {
          local today="$1"
          local reason="$2"
          [ -f "$WORKDAY_CACHE" ] || return 1
          jq -e --arg date "$today" --arg reason "$reason" '
            type == "object"
            and .date == $date
            and .status == "day_off"
            and .is_workday == false
            and .workday == false
            and .reason == $reason
          ' "$WORKDAY_CACHE" >/dev/null 2>&1
        }

        resolve_workday() {
          local refresh="''${1:-0}"
          local cached_only="''${2:-0}"
          local today now dow out

          today=$(date +%Y-%m-%d)
          now=$(date +%s)

          if [ "$WORK_ENABLED" != "1" ]; then
            if cache_matches_static_day_off "$today" "work_disabled"; then
              jq -c '.' "$WORKDAY_CACHE"
              return 0
            fi
            out=$(make_workday_json "$today" "$now" "day_off" "false" "work_disabled")
            write_json_atomic "$WORKDAY_CACHE" "$out" || true
            printf '%s\n' "$out"
            return 0
          fi

          dow=$(date +%u)
          if [ "$dow" -eq 6 ] || [ "$dow" -eq 7 ]; then
            if cache_matches_static_day_off "$today" "weekend"; then
              jq -c '.' "$WORKDAY_CACHE"
              return 0
            fi
            out=$(make_workday_json "$today" "$now" "day_off" "false" "weekend")
            write_json_atomic "$WORKDAY_CACHE" "$out" || true
            printf '%s\n' "$out"
            return 0
          fi

          if [ "$refresh" != "1" ] && [ -f "$WORKDAY_CACHE" ]; then
            local meta=() c_date="" c_checked_at="" c_status=""
            mapfile -t meta < <(
              jq -r '
                select(type == "object")
                | (.date // ""),
                  ((.checked_at // 0) | tostring),
                  (.status // "")
              ' "$WORKDAY_CACHE" 2>/dev/null || true
            )
            c_date="''${meta[0]:-}"
            c_checked_at="''${meta[1]:-}"
            c_status="''${meta[2]:-}"
            if [ "$c_date" = "$today" ]; then
              if [ "$cached_only" = "1" ]; then
                jq -c '.' "$WORKDAY_CACHE"
                return 0
              fi
              if [[ "$c_checked_at" =~ ^[0-9]+$ ]]; then
                local age=$((now - c_checked_at))
                if { [ "$c_status" = "workday" ] || [ "$c_status" = "day_off" ]; } && [ "$age" -lt "$WORKDAY_TTL_SECS" ]; then
                  jq -c '.' "$WORKDAY_CACHE"
                  return 0
                fi
                if [ "$c_status" = "unknown" ] && [ "$age" -lt "$WORKDAY_UNKNOWN_TTL_SECS" ]; then
                  jq -c '.' "$WORKDAY_CACHE"
                  return 0
                fi
              fi
            fi
          fi

          if [ "$cached_only" = "1" ]; then
            make_workday_json "$today" "$now" "unknown" "true" "cache_miss"
            return 0
          fi

          if out=$(PYTHONPATH=${lib.escapeShellArg googleWorkspaceSitePackages} \
            ${googleWorkspacePython}/bin/python3 ${workdayCheckScript} \
            "$PERSONAL_GOOGLE_EMAIL" "$GOOGLE_CREDS_DIR" "$today" "$WORKDAY_CACHE" 2>/dev/null) \
            && [ -n "$out" ]; then
            printf '%s\n' "$out"
            return 0
          fi

          out=$(make_workday_json "$today" "$now" "unknown" "true" "api_error")
          write_json_atomic "$WORKDAY_CACHE" "$out" || true
          printf '%s\n' "$out"
        }

        format_workday_block() {
          local workday_json="$1"
          jq -r '
            (.status // "unknown") as $st
            | (.reason // "unknown") as $rsn
            | (if $st == "workday" and ((.arbeit_event // "") != "") then
                 "\($rsn) (\(.arbeit_event))"
               elif $st == "day_off" and ((.override_event // "") != "") then
                 "\($rsn) (\(.override_event))"
               else
                 $rsn
               end) as $detail
            | "workday_status: \($st)\nworkday_reason: \($detail)"
          ' <<<"$workday_json" 2>/dev/null || printf 'workday_status: unknown\nworkday_reason: api_error\n'
        }

        cmd_workday() {
          local refresh=0 cached_only=0 mode="text" workday_json status
          while [ "$#" -gt 0 ]; do
            case "$1" in
            --refresh)
              refresh=1
              ;;
            --cached-only)
              cached_only=1
              ;;
            --json)
              mode="json"
              ;;
            --quiet)
              mode="quiet"
              ;;
            *)
              echo "Usage: hey-computer-proactive workday [--refresh] [--cached-only] [--json|--quiet]" >&2
              exit 2
              ;;
            esac
            shift
          done

          workday_json=$(resolve_workday "$refresh" "$cached_only")
          case "$mode" in
          json)
            printf '%s\n' "$workday_json"
            ;;
          quiet)
            status=$(jq -r '.status // "unknown"' <<<"$workday_json" 2>/dev/null || printf 'unknown')
            case "$status" in
            workday) return 0 ;;
            day_off) return 1 ;;
            *) return 2 ;;
            esac
            ;;
          *)
            format_workday_block "$workday_json"
            ;;
          esac
        }

        run_morning_digest() {
          local today stamp loc workday_json workday_block weather_block base_prompt prompt manual
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/morning-digest.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            # Already ran today: silent 0-token no-op.
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            # Wait quietly until the user unlocks the desktop and network is up.
            session_unlocked || exit 0
            network_online || exit 0
          fi

          if ! daemon_ready; then
            log_failure "morning-digest" "hey-computer daemon is not ready; will retry on next tick."
            exit 1
          fi

          loc=$(classify_location)
          workday_json=$(resolve_workday "$manual" 0)
          workday_block=$(format_workday_block "$workday_json")
          weather_block=$(collect_weather_delta "$loc" "$today")
          base_prompt=$(cat ${morningDigestPromptFile})
          printf -v prompt '%s\n\n<untrusted_collector_output>\ndate: %s\nlocation: %s\n%s\n%s\n</untrusted_collector_output>' \
            "$base_prompt" "$today" "$loc" "$workday_block" "$weather_block"

          run_and_wait_task "morning-digest" "$stamp" "$today" "$prompt" || exit 1
        }

        run_pre_daily() {
          local today stamp loc workday_json workday_status workday_block base_prompt prompt manual
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/pre-daily.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            session_unlocked || exit 0
            network_online || exit 0
          fi

          loc=$(classify_location)
          # If the user configured location rules and is neither at work nor home, skip quietly.
          if [ "$manual" != "1" ] && [ -f "$CONFIG_FILE" ] && [ "$loc" = "other" ]; then
            exit 0
          fi

          workday_json=$(resolve_workday "$manual" 0)
          workday_status=$(jq -r '.status // "unknown"' <<<"$workday_json" 2>/dev/null || printf 'unknown')
          if [ "$manual" != "1" ] && [ "$workday_status" = "day_off" ]; then
            exit 0
          fi

          if ! daemon_ready; then
            log_failure "pre-daily" "hey-computer daemon is not ready before the 10:00 daily."
            exit 1
          fi

          workday_block=$(format_workday_block "$workday_json")
          base_prompt=$(cat ${preDailyPromptFile})
          printf -v prompt '%s\n\n<untrusted_collector_output>\ndate: %s\nlocation: %s\n%s\n</untrusted_collector_output>' \
            "$base_prompt" "$today" "$loc" "$workday_block"

          run_and_wait_task "pre-daily" "$stamp" "$today" "$prompt" || exit 1
        }

        collect_morning_digest() {
          local today stamp sched_json last_run_at last_status last_date now_ms loc manual workday_json
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/morning-digest.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            # Honour legacy stamp file on same-day upgrades.
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            if sched_json=$(${heyComputer} schedule show morning-digest --json 2>/dev/null); then
              last_run_at=$(jq -r '.last_run_at // 0' <<<"$sched_json" 2>/dev/null || printf '0')
              last_status=$(jq -r '.last_status // ""' <<<"$sched_json" 2>/dev/null || true)
              if [[ "$last_run_at" =~ ^[0-9]+$ ]] && [ "$last_run_at" -gt 0 ]; then
                last_date=$(date -d "@$((last_run_at / 1000))" +%Y-%m-%d 2>/dev/null || true)
                if [ "$last_date" = "$today" ] && { [ "$last_status" = "ok" ] || [ "$last_status" = "suppressed" ]; }; then
                  exit 0
                fi
                if [ "$last_status" = "failed" ]; then
                  now_ms=$(( $(date +%s) * 1000 ))
                  if [ $((now_ms - last_run_at)) -lt 900000 ]; then
                    exit 0
                  fi
                fi
              fi
            fi

            session_unlocked || exit 0
            network_online || exit 0
          fi

          loc=$(classify_location)
          workday_json=$(resolve_workday "$manual" 0)
          printf 'date: %s\nlocation: %s\n' "$today" "$loc"
          format_workday_block "$workday_json"
          collect_weather_delta "$loc" "$today"
        }

        collect_pre_daily() {
          local today stamp loc manual workday_json workday_status
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/pre-daily.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            session_unlocked || exit 0
            network_online || exit 0
          fi

          loc=$(classify_location)
          if [ "$manual" != "1" ] && [ -f "$CONFIG_FILE" ] && [ "$loc" = "other" ]; then
            exit 0
          fi

          workday_json=$(resolve_workday "$manual" 0)
          workday_status=$(jq -r '.status // "unknown"' <<<"$workday_json" 2>/dev/null || printf 'unknown')
          if [ "$manual" != "1" ] && [ "$workday_status" = "day_off" ]; then
            exit 0
          fi

          printf 'date: %s\nlocation: %s\n' "$today" "$loc"
          format_workday_block "$workday_json"
        }

        case "''${1-}" in
        location)
          classify_location
          ;;
        weather)
          loc="''${2:-}"
          if [ -z "$loc" ]; then
            loc=$(classify_location)
          fi
          collect_weather_delta "$loc" "$(date +%Y-%m-%d)"
          ;;
        workday)
          shift
          cmd_workday "$@"
          ;;
        collect-morning-digest)
          collect_morning_digest
          ;;
        collect-pre-daily)
          collect_pre_daily
          ;;
        morning-digest)
          run_morning_digest
          ;;
        pre-daily)
          run_pre_daily
          ;;
        *)
          echo "Usage: hey-computer-proactive <location|weather|workday|collect-morning-digest|collect-pre-daily|morning-digest|pre-daily>" >&2
          exit 2
          ;;
        esac
      '';
  };
}
