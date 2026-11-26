# Shell-gated proactive automation for hey-computer (#26, #33, #34, plan-my-day):
# - `location`: classifies current environment as `work`, `home`, or `other`
#   using connected monitor descriptions/models (`hyprctl monitors -j`) and
#   optional user-local `~/.config/hey-computer/locations.json` rules (IP prefix,
#   default gateway, monitor substrings, or per-location `{city,latitude,longitude}`
#   overrides — keeping private IPs and network names out of git).
# - `weather [location]`: fetches today's Open-Meteo daily forecast using VPN-safe
#   coordinates, persists 14 days atomically in `weather-history.json`, and emits
#   a deterministic day-over-day delta (`changed`, `unchanged`, or `unavailable`).
# - `workday [--refresh] [--cached-only] [--json|--quiet]`: deterministic 0-token
#   multi-signal 3-calendar workday & StandUp detector backed by a 30-minute TTL
#   cache in `$STATE_DIR/workday.json` (mode `0600`). Queries personal primary,
#   work primary, and `de.german#holiday@group.v.calendar.google.com` via
#   `LocalDirectoryCredentialStore`, emitting `work_windows`, `work_minutes`,
#   `work_mode`, `standup_status`, and `standup_window`.
# - `collect-morning-digest`: fast 0-token pre-collector for hey-computer's native
#   `[scheduler.jobs.morning-digest]` cron (`*/5 5-14 * * *`). Queries
#   `hey-computer schedule show morning-digest --json` (`last_run_at`,
#   `last_status`, and `recent_turns[]`) with fail-closed fallback to
#   scheduler-injected `HEY_COMPUTER_SCHEDULE_*` env vars: exits 0 with empty
#   stdout when state cannot be verified, when today already
#   succeeded/suppressed/is active, when within a 15-minute failure retry
#   cooldown, or while locked/offline (bypassed when
#   `HEY_COMPUTER_SCHEDULE_MANUAL=1`); otherwise prints `date`, `location`,
#   `workday_*` / `work_*` / `standup_*`, and the deterministic `weather_*` block
#   so the scheduler wakes the agent.
# - `collect-pre-daily`: fast 0-token pre-collector for `[scheduler.jobs.pre-daily]`
#   (`weekdays 09:56`). Exits 0 with empty stdout while locked/offline, away from
#   work/home, on a `day_off`, or when `standup_status` is `declined`/`none`
#   (bypassed when `HEY_COMPUTER_SCHEDULE_MANUAL=1`); appends `active_roter_faden`
#   and `active_plan_tasks` when `$STATE_DIR/day-plan-$today.json` has
#   `pre_daily_sync == true`.
# - `collect-day-plan-checkin [slot_id]`: 0-token pre-collector gate for dynamic
#   day-plan reassessment check-ins. Requires `$STATE_DIR/day-plan-$today.json`,
#   defers `in 20m` (<= 2 times, before 18:00 local) if locked/offline or in a
#   live dual-calendar meeting (excluding `Arbeit`, `Focus:`, and day-plan blocks),
#   skips at 0 tokens if all `planned_items` are already ticked off in
#   `Journal/$today.md`, and otherwise prints structured key-values to wake the
#   reassessment turn.
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
  vaultDir =
    if (systemArgs.obsidianVault or null) != null
    then "${hmCfg.home.homeDirectory}/Documents/${systemArgs.obsidianVault}"
    else "";
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
    from urllib.parse import quote
    from zoneinfo import ZoneInfo

    import requests
    from google.auth.transport.requests import Request as GoogleAuthRequest

    logging.getLogger("auth").setLevel(logging.CRITICAL)

    HOLIDAY_CALENDAR_ID = "de.german#holiday@group.v.calendar.google.com"
    DAY_PLAN_TAG = "[hey-computer:day-plan:"

    ARBEIT_RE = re.compile(r"^arbeit(?:\b|[\s:–—-]|$)", re.IGNORECASE)
    HEIMATBUERO_RE = re.compile(
        r"(?:heimatb[uü]ro|home\s*-?\s*office|remote|\bwfh\b)",
        re.IGNORECASE,
    )
    STANDUP_RE = re.compile(r"\b(?:stand[\s-]?up|daily)\b", re.IGNORECASE)
    FOCUS_RE = re.compile(r"^focus:", re.IGNORECASE)
    ABSENCE_RE = re.compile(
        r"(?i)(?:^frei$|\b(?:"
        r"urlaub|vacation|pto|time\s+off|day\s+off|freier?\s+tag|"
        r"gleittag|flex\s+day|sonderurlaub|überstundenabbau|elternzeit|"
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


    def _self_response_status(event: dict) -> str | None:
        for att in event.get("attendees") or []:
            if isinstance(att, dict) and att.get("self") is True:
                status = att.get("responseStatus")
                if isinstance(status, str) and status:
                    return status
        return None


    def _is_declined_by_self(event: dict) -> bool:
        return _self_response_status(event) == "declined"


    def _is_transparent(event: dict) -> bool:
        return (event.get("transparency") or "opaque").strip().lower() == "transparent"


    def _event_span_for_day(
        event: dict,
        today: date,
        day_start: datetime,
        day_end: datetime,
        tz,
    ) -> tuple[bool, datetime, datetime] | None:
        start = event.get("start") or {}
        end = event.get("end") or {}
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
                return None
            if not (start_date <= today < end_date):
                return None
            return True, day_start, day_end

        if "dateTime" in start:
            try:
                ev_start = _parse_iso_dt(start["dateTime"], tz)
                ev_end = (
                    _parse_iso_dt(end["dateTime"], tz)
                    if "dateTime" in end
                    else ev_start
                )
            except (TypeError, ValueError):
                return None
            if ev_end == ev_start:
                if not (day_start <= ev_start < day_end):
                    return None
            elif not (ev_end > day_start and ev_start < day_end):
                return None
            return False, ev_start, ev_end

        return None


    def _merge_windows(
        windows: list[tuple[datetime, datetime]],
        day_start: datetime,
        day_end: datetime,
    ) -> list[tuple[datetime, datetime]]:
        clamped: list[tuple[datetime, datetime]] = []
        for s, e in windows:
            cs = max(s, day_start)
            ce = min(e, day_end)
            if ce > cs:
                clamped.append((cs, ce))
        if not clamped:
            return []
        clamped.sort(key=lambda w: (w[0], w[1]))
        merged = [clamped[0]]
        for s, e in clamped[1:]:
            prev_s, prev_e = merged[-1]
            if s <= prev_e:
                merged[-1] = (prev_s, max(prev_e, e))
            else:
                merged.append((s, e))
        return merged


    def _fmt_window(start: datetime, end: datetime) -> str:
        return f"{start.strftime('%H:%M')}–{end.strftime('%H:%M')}"


    def is_hamburg_legal_holiday(
        event: dict,
        today: date,
        tz=None,
    ) -> bool:
        if not isinstance(event, dict) or event.get("status") == "cancelled":
            return False
        if tz is None:
            tz = get_local_tz()
        day_start = datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=tz)
        next_day = today + timedelta(days=1)
        day_end = datetime(next_day.year, next_day.month, next_day.day, 0, 0, 0, tzinfo=tz)
        if _event_span_for_day(event, today, day_start, day_end, tz) is None:
            return False

        desc = (event.get("description") or "").strip().lower()
        if not desc:
            return False
        if "halbtägiger feiertag" in desc or "halbtaegiger feiertag" in desc:
            return False
        if "gesetzlicher feiertag" in desc:
            return True
        if "feiertag in" in desc and "hamburg" in desc:
            return True
        return False


    def _build_result(
        *,
        today_str: str,
        checked_at: int,
        status: str,
        is_workday: bool,
        reason: str,
        arbeit_event: str | None = None,
        override_event: str | None = None,
        work_windows: str | None = None,
        work_minutes: int = 0,
        work_mode: str | None = None,
        standup_status: str = "none",
        standup_window: str | None = None,
    ) -> dict:
        return {
            "date": today_str,
            "checked_at": checked_at,
            "status": status,
            "is_workday": is_workday,
            "workday": is_workday,
            "reason": reason,
            "arbeit_event": arbeit_event,
            "override_event": override_event,
            "work_windows": work_windows,
            "work_minutes": work_minutes,
            "work_mode": work_mode,
            "standup_status": standup_status,
            "standup_window": standup_window,
        }


    def evaluate_calendars(
        personal_events: list[dict],
        work_events: list[dict],
        holiday_events: list[dict],
        today: date,
        tz=None,
        checked_at: int | None = None,
        work_enabled: bool = True,
        work_calendar_ok: bool = True,
    ) -> dict:
        if tz is None:
            tz = get_local_tz()
        if checked_at is None:
            checked_at = int(time.time())

        today_str = today.isoformat()
        if not work_enabled:
            return _build_result(
                today_str=today_str,
                checked_at=checked_at,
                status="day_off",
                is_workday=False,
                reason="work_disabled",
                standup_status="none",
            )

        if today.isoweekday() in (6, 7):
            return _build_result(
                today_str=today_str,
                checked_at=checked_at,
                status="day_off",
                is_workday=False,
                reason="weekend",
                standup_status="none",
            )

        day_start = datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=tz)
        next_day = today + timedelta(days=1)
        day_end = datetime(next_day.year, next_day.month, next_day.day, 0, 0, 0, tzinfo=tz)

        arbeit_summary: str | None = None
        arbeit_raw_windows: list[tuple[datetime, datetime]] = []
        is_heimatbuero = False
        ooo_candidates: list[tuple[str, datetime, datetime]] = []
        all_day_override: str | None = None
        personal_timed_other: list[tuple[datetime, datetime]] = []

        for ev in personal_events or []:
            if not isinstance(ev, dict) or ev.get("status") == "cancelled":
                continue
            if _is_declined_by_self(ev):
                continue

            span = _event_span_for_day(ev, today, day_start, day_end, tz)
            if span is None:
                continue
            is_all_day, ev_start, ev_end = span
            summary = (ev.get("summary") or "").strip()
            location = (ev.get("location") or "").strip()
            desc = ev.get("description") or ""
            event_type = ev.get("eventType") or "default"

            if is_all_day:
                label = summary or "Out of office"
            else:
                time_span = _fmt_window(ev_start, ev_end)
                label = f"{summary} ({time_span})" if summary else f"Out of office ({time_span})"

            if event_type == "outOfOffice":
                ooo_candidates.append((label, ev_start, ev_end))

            if is_all_day and not _is_transparent(ev) and summary and ABSENCE_RE.search(summary):
                if all_day_override is None:
                    all_day_override = summary

            if not is_all_day and summary and ARBEIT_RE.match(summary):
                if arbeit_summary is None:
                    arbeit_summary = summary
                arbeit_raw_windows.append((ev_start, ev_end))
                if HEIMATBUERO_RE.search(summary) or HEIMATBUERO_RE.search(location):
                    is_heimatbuero = True
            elif (
                not is_all_day
                and event_type not in ("outOfOffice", "workingLocation", "focusTime", "birthday")
                and not FOCUS_RE.match(summary)
                and DAY_PLAN_TAG not in desc
            ):
                personal_timed_other.append((ev_start, ev_end))

        merged_arbeit = _merge_windows(arbeit_raw_windows, day_start, day_end)
        work_windows = (
            ", ".join(_fmt_window(s, e) for s, e in merged_arbeit)
            if merged_arbeit
            else None
        )
        work_minutes = int(
            round(sum((e - s).total_seconds() for s, e in merged_arbeit) / 60.0)
        )
        work_mode = (
            ("heimatbuero" if is_heimatbuero else "office")
            if merged_arbeit
            else None
        )
        arbeit_event = (
            f"{arbeit_summary or 'Arbeit'} ({work_windows})"
            if merged_arbeit and work_windows
            else None
        )

        # Inspect work primary calendar for StandUp, OOO/absence, and other meetings.
        standup_candidates: list[tuple[str, datetime, datetime, str]] = []
        other_work_meetings: list[str] = []

        for ev in work_events or []:
            if not isinstance(ev, dict) or ev.get("status") == "cancelled":
                continue

            span = _event_span_for_day(ev, today, day_start, day_end, tz)
            if span is None:
                continue
            is_all_day, ev_start, ev_end = span
            summary = (ev.get("summary") or "").strip()
            desc = ev.get("description") or ""
            event_type = ev.get("eventType") or "default"
            self_status = _self_response_status(ev)

            if not is_all_day and summary and STANDUP_RE.search(summary):
                st = self_status or "accepted"
                label = f"{summary} ({_fmt_window(ev_start, ev_end)})"
                standup_candidates.append((st, ev_start, ev_end, label))
                continue

            if self_status == "declined":
                continue

            if is_all_day:
                label = summary or "Out of office"
            else:
                time_span = _fmt_window(ev_start, ev_end)
                label = f"{summary} ({time_span})" if summary else f"Out of office ({time_span})"

            if event_type == "outOfOffice":
                ooo_candidates.append((label, ev_start, ev_end))
                continue

            if is_all_day and not _is_transparent(ev) and summary and ABSENCE_RE.search(summary):
                if all_day_override is None:
                    all_day_override = summary
                continue

            if (
                not is_all_day
                and event_type not in ("workingLocation", "focusTime", "birthday")
                and not FOCUS_RE.match(summary)
                and DAY_PLAN_TAG not in desc
            ):
                attendees = [a for a in (ev.get("attendees") or []) if isinstance(a, dict)]
                if len(attendees) > 1 or self_status == "accepted":
                    other_work_meetings.append(label)

        standup_status = "none" if work_calendar_ok else "unknown"
        standup_window: str | None = None
        standup_span: tuple[datetime, datetime] | None = None
        standup_label: str | None = None
        if standup_candidates:
            chosen = next(
                (c for c in standup_candidates if c[0] != "declined"),
                standup_candidates[0],
            )
            standup_status, s_start, s_end, standup_label = chosen
            standup_span = (s_start, s_end)
            standup_window = _fmt_window(s_start, s_end)

        common = dict(
            today_str=today_str,
            checked_at=checked_at,
            arbeit_event=arbeit_event,
            work_windows=work_windows,
            work_minutes=work_minutes,
            work_mode=work_mode,
            standup_status=standup_status,
            standup_window=standup_window,
        )

        # Signal 2: Official Hamburg legal holiday.
        for ev in holiday_events or []:
            if is_hamburg_legal_holiday(ev, today, tz=tz):
                holiday_name = (ev.get("summary") or "Public holiday").strip()
                return _build_result(
                    status="day_off",
                    is_workday=False,
                    reason="public_holiday",
                    override_event=holiday_name,
                    **common,
                )

        # Signal 3: OOO or non-transparent all-day absence override on either calendar.
        override_label: str | None = None
        for label, ooo_start, ooo_end in ooo_candidates:
            clamped_secs = (min(ooo_end, day_end) - max(ooo_start, day_start)).total_seconds()
            overlaps_arbeit = any(
                ooo_end > a_start and ooo_start < a_end
                for a_start, a_end in merged_arbeit
            )
            overlaps_standup = (
                standup_span is not None
                and ooo_end > standup_span[0]
                and ooo_start < standup_span[1]
            )
            if clamped_secs >= 3 * 3600 or overlaps_arbeit or overlaps_standup:
                override_label = label
                break

        if override_label is None and all_day_override is not None:
            override_label = all_day_override

        if override_label is not None:
            return _build_result(
                status="day_off",
                is_workday=False,
                reason="vacation_override",
                override_event=override_label,
                **common,
            )

        # Signal 4: No timed Arbeit event on personal calendar.
        if not merged_arbeit:
            return _build_result(
                status="day_off",
                is_workday=False,
                reason="no_arbeit_event",
                override_event=None,
                **common,
            )

        # Signal 5: Declined recurring StandUp with zero other work meetings
        # and zero overlapping non-Arbeit timed personal events.
        if standup_status == "declined" and standup_span is not None:
            has_overlapping_personal = any(
                p_end > standup_span[0] and p_start < standup_span[1]
                for p_start, p_end in personal_timed_other
            )
            if not other_work_meetings and not has_overlapping_personal:
                return _build_result(
                    status="day_off",
                    is_workday=False,
                    reason="standup_declined",
                    override_event=standup_label,
                    **common,
                )

        return _build_result(
            status="workday",
            is_workday=True,
            reason="arbeit_scheduled",
            override_event=None,
            **common,
        )


    def evaluate_events(
        events: list[dict],
        today: date,
        tz=None,
        checked_at: int | None = None,
    ) -> dict:
        return evaluate_calendars(
            personal_events=events,
            work_events=[],
            holiday_events=[],
            today=today,
            tz=tz,
            checked_at=checked_at,
            work_enabled=True,
            work_calendar_ok=False,
        )


    def _unknown_result(today_str: str, checked_at: int, reason: str) -> dict:
        return _build_result(
            today_str=today_str,
            checked_at=checked_at,
            status="unknown",
            is_workday=True,
            reason=reason,
            standup_status="unknown",
        )


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


    def _load_valid_creds(store, email: str):
        if not email:
            return None, "missing_credentials"
        try:
            creds = store.get_credential(email)
        except Exception:
            return None, "missing_credentials"
        if creds is None:
            return None, "missing_credentials"
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(GoogleAuthRequest(session=_TimeoutSession(timeout=5.0)))
                    creds_path = store._get_credential_path(email)
                    _store_credentials_atomic(creds_path, creds)
                except Exception:
                    return None, "api_error"
            else:
                return None, "missing_credentials"
        return creds, None


    def _fetch_calendar_events(creds, calendar_id: str, day_start: datetime, day_end: datetime) -> list[dict] | None:
        encoded_id = quote(calendar_id, safe="")
        try:
            resp = requests.get(
                f"https://www.googleapis.com/calendar/v3/calendars/{encoded_id}/events",
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
                return None
            return items
        except Exception:
            return None


    def check_calendar_workday(
        personal_email: str,
        work_email: str,
        creds_dir: str,
        today: date,
        cache_path: str,
        work_enabled: bool = True,
    ) -> dict:
        tz = get_local_tz()
        now = int(time.time())
        today_str = today.isoformat()

        if not work_enabled or today.isoweekday() in (6, 7):
            result = evaluate_calendars(
                [], [], [], today, tz=tz, checked_at=now, work_enabled=work_enabled
            )
            write_json_atomic(cache_path, result)
            return result

        if not creds_dir or not os.path.isdir(creds_dir):
            result = _unknown_result(today_str, now, "missing_credentials")
            write_json_atomic(cache_path, result)
            return result

        try:
            from auth.credential_store import LocalDirectoryCredentialStore

            store = LocalDirectoryCredentialStore(creds_dir)
        except Exception:
            result = _unknown_result(today_str, now, "missing_credentials")
            write_json_atomic(cache_path, result)
            return result

        personal_creds, personal_err = _load_valid_creds(store, personal_email)
        if personal_creds is None:
            result = _unknown_result(today_str, now, personal_err or "missing_credentials")
            write_json_atomic(cache_path, result)
            return result

        day_start = datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=tz)
        next_day = today + timedelta(days=1)
        day_end = datetime(next_day.year, next_day.month, next_day.day, 0, 0, 0, tzinfo=tz)

        personal_items = _fetch_calendar_events(personal_creds, "primary", day_start, day_end)
        if personal_items is None:
            result = _unknown_result(today_str, now, "api_error")
            write_json_atomic(cache_path, result)
            return result

        work_items: list[dict] = []
        work_calendar_ok = False
        work_creds = None
        if work_email:
            work_creds, _ = _load_valid_creds(store, work_email)
            if work_creds is not None:
                fetched_work = _fetch_calendar_events(work_creds, "primary", day_start, day_end)
                if fetched_work is not None:
                    work_items = fetched_work
                    work_calendar_ok = True

        holiday_items: list[dict] = []
        if work_creds is not None:
            fetched_holidays = _fetch_calendar_events(
                work_creds, HOLIDAY_CALENDAR_ID, day_start, day_end
            )
            if fetched_holidays is not None:
                holiday_items = fetched_holidays
            else:
                fetched_holidays = _fetch_calendar_events(
                    personal_creds, HOLIDAY_CALENDAR_ID, day_start, day_end
                )
                if fetched_holidays is not None:
                    holiday_items = fetched_holidays
        else:
            fetched_holidays = _fetch_calendar_events(
                personal_creds, HOLIDAY_CALENDAR_ID, day_start, day_end
            )
            if fetched_holidays is not None:
                holiday_items = fetched_holidays

        result = evaluate_calendars(
            personal_events=personal_items,
            work_events=work_items,
            holiday_events=holiday_items,
            today=today,
            tz=tz,
            checked_at=now,
            work_enabled=work_enabled,
            work_calendar_ok=work_calendar_ok,
        )
        write_json_atomic(cache_path, result)
        return result


    def main() -> int:
        if len(sys.argv) == 5:
            personal_email, creds_dir, today_str, cache_path = sys.argv[1:5]
            work_email = ""
        elif len(sys.argv) == 6:
            personal_email, work_email, creds_dir, today_str, cache_path = sys.argv[1:6]
        else:
            sys.stderr.write(
                "Usage: hey-computer-workday.py <personal_email> [work_email] <creds_dir> <YYYY-MM-DD> <cache_path>\n"
            )
            return 2
        today = date.fromisoformat(today_str)
        result = check_calendar_workday(
            personal_email=personal_email,
            work_email=work_email,
            creds_dir=creds_dir,
            today=today,
            cache_path=cache_path,
            work_enabled=True,
        )
        sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n")
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';

  checkinGateScript = pkgs.writeText "hey-computer-checkin-gate.py" ''
    import json
    import logging
    import os
    import re
    import sys
    import tempfile
    from datetime import datetime, timedelta
    from zoneinfo import ZoneInfo

    logging.getLogger("auth").setLevel(logging.CRITICAL)

    DAY_PLAN_TAG = "[hey-computer:day-plan:"
    ARBEIT_RE = re.compile(r"^arbeit(?:\b|[\s:–—-]|$)", re.IGNORECASE)
    FOCUS_RE = re.compile(r"^focus:", re.IGNORECASE)
    UNTICKED_RE = re.compile(r"^\s*[-*]\s+\[\s\]\s+(.+?)\s*$")
    CHECKBOX_PREFIX_RE = re.compile(r"^\s*[-*]\s+\[[ xX]\]\s+")


    def get_local_tz():
        tz_name = os.environ.get("WORKDAY_TZ") or os.environ.get("TZ") or "Europe/Berlin"
        try:
            return ZoneInfo(tz_name)
        except Exception:
            return datetime.now().astimezone().tzinfo


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


    def _write_json_atomic(path: str, payload: dict) -> None:
        parent = os.path.dirname(path) or "."
        os.makedirs(parent, mode=0o700, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(dir=parent, prefix=".tmp-checkin-")
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


    def extract_excluded_event_ids(plan_data: dict) -> set[str]:
        raw = plan_data.get("calendar_event_ids") if isinstance(plan_data, dict) else None
        ids: set[str] = set()
        if isinstance(raw, list):
            for entry in raw:
                if isinstance(entry, str) and entry.strip():
                    ids.add(entry.strip())
                elif isinstance(entry, dict):
                    for key in ("event_id", "id"):
                        val = entry.get(key)
                        if isinstance(val, str) and val.strip():
                            ids.add(val.strip())
        elif isinstance(raw, dict):
            for val in raw.values():
                if isinstance(val, str) and val.strip():
                    ids.add(val.strip())
                elif isinstance(val, dict):
                    for key in ("event_id", "id"):
                        nested = val.get(key)
                        if isinstance(nested, str) and nested.strip():
                            ids.add(nested.strip())
        return ids


    def is_live_meeting_event(
        event: dict,
        now: datetime,
        tz,
        excluded_event_ids: set[str],
    ) -> str | None:
        if not isinstance(event, dict):
            return None
        if event.get("status") == "cancelled":
            return None
        if _is_declined_by_self(event):
            return None
        if (event.get("transparency") or "opaque").strip().lower() == "transparent":
            return None
        if (event.get("eventType") or "default") == "workingLocation":
            return None

        start = event.get("start") or {}
        end = event.get("end") or {}
        if "dateTime" not in start:
            return None

        try:
            ev_start = _parse_iso_dt(start["dateTime"], tz)
            ev_end = (
                _parse_iso_dt(end["dateTime"], tz)
                if "dateTime" in end
                else ev_start
            )
        except (TypeError, ValueError):
            return None

        if not (ev_start <= now < ev_end):
            return None

        ev_id = event.get("id")
        if isinstance(ev_id, str) and ev_id.strip() in excluded_event_ids:
            return None

        summary = (event.get("summary") or "").strip()
        desc = event.get("description") or ""
        if summary and ARBEIT_RE.match(summary):
            return None
        if summary and FOCUS_RE.match(summary):
            return None
        if DAY_PLAN_TAG in desc:
            return None

        return summary or "Meeting"


    def find_live_meeting(
        personal_events: list[dict],
        work_events: list[dict],
        now: datetime,
        tz,
        excluded_event_ids: set[str] | None = None,
    ) -> str | None:
        excluded = excluded_event_ids or set()
        for ev in list(work_events or []) + list(personal_events or []):
            matched = is_live_meeting_event(ev, now, tz, excluded)
            if matched is not None:
                return matched
        return None


    def _normalize_task_text(text: str) -> str:
        stripped = CHECKBOX_PREFIX_RE.sub("", text).strip()
        return re.sub(r"\s+", " ", stripped).lower()


    def _clean_task_display(item) -> str:
        if isinstance(item, str):
            raw = item
        elif isinstance(item, dict):
            raw = item.get("text") or item.get("title") or ""
        else:
            raw = ""
        return CHECKBOX_PREFIX_RE.sub("", str(raw)).strip()


    def find_remaining_planned_items(
        planned_items: list,
        daily_note_text: str | None,
    ) -> list[str]:
        cleaned: list[str] = []
        for item in planned_items or []:
            text = _clean_task_display(item)
            if text:
                cleaned.append(text)
        if not cleaned:
            return []
        if daily_note_text is None:
            return cleaned

        unticked_norms: list[str] = []
        for line in daily_note_text.splitlines():
            m = UNTICKED_RE.match(line)
            if m:
                norm = _normalize_task_text(m.group(1))
                if norm:
                    unticked_norms.append(norm)

        unticked_set = set(unticked_norms)
        remaining: list[str] = []
        for item in cleaned:
            norm_item = _normalize_task_text(item)
            if not norm_item:
                continue
            if norm_item in unticked_set or any(norm_item in u for u in unticked_norms):
                remaining.append(item)
        return remaining


    def evaluate_checkin_gate(
        plan_data: dict,
        daily_note_text: str | None,
        personal_events: list[dict],
        work_events: list[dict],
        now: datetime,
        tz=None,
        skip_meeting_check: bool = False,
    ) -> dict:
        if tz is None:
            tz = get_local_tz()
        if not skip_meeting_check:
            excluded = extract_excluded_event_ids(plan_data)
            meeting = find_live_meeting(personal_events, work_events, now, tz, excluded)
            if meeting is not None:
                return {
                    "action": "defer",
                    "reason": "in_meeting",
                    "meeting": meeting,
                    "remaining_planned_items": [],
                }

        remaining = find_remaining_planned_items(
            plan_data.get("planned_items") or [],
            daily_note_text,
        )
        if not remaining:
            return {
                "action": "skip",
                "reason": "all_planned_done",
                "meeting": None,
                "remaining_planned_items": [],
            }
        return {
            "action": "run",
            "reason": "remaining_items",
            "meeting": None,
            "remaining_planned_items": remaining,
        }


    def _load_valid_creds(store, email: str):
        if not email:
            return None
        try:
            creds = store.get_credential(email)
        except Exception:
            return None
        if creds is None:
            return None
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    import requests
                    from google.auth.transport.requests import Request as GoogleAuthRequest

                    class _TimeoutSession(requests.Session):
                        def __init__(self, timeout: float = 5.0) -> None:
                            super().__init__()
                            self._timeout = timeout

                        def request(self, *args, **kwargs):
                            kwargs.setdefault("timeout", self._timeout)
                            return super().request(*args, **kwargs)

                    creds.refresh(GoogleAuthRequest(session=_TimeoutSession(timeout=5.0)))
                    creds_path = store._get_credential_path(email)
                    _write_json_atomic(
                        creds_path,
                        {
                            "token": creds.token,
                            "refresh_token": creds.refresh_token,
                            "token_uri": creds.token_uri,
                            "client_id": creds.client_id,
                            "client_secret": creds.client_secret,
                            "scopes": list(creds.scopes) if creds.scopes is not None else None,
                            "expiry": creds.expiry.isoformat() if creds.expiry else None,
                        },
                    )
                except Exception:
                    return None
            else:
                return None
        return creds


    def _fetch_primary_events(creds, day_start: datetime, day_end: datetime) -> list[dict]:
        if creds is None:
            return []
        try:
            import requests

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
            items = resp.json().get("items") or []
            return items if isinstance(items, list) else []
        except Exception:
            return []


    def main() -> int:
        if len(sys.argv) != 7:
            sys.stderr.write(
                "Usage: hey-computer-checkin-gate.py <personal_email> <work_email> <creds_dir> <plan_file> <daily_note_path> <skip_meeting_check>\n"
            )
            return 2

        personal_email, work_email, creds_dir, plan_file, daily_note_path, skip_flag = sys.argv[1:7]
        skip_meeting_check = skip_flag == "1"
        tz = get_local_tz()
        now_override = os.environ.get("CHECKIN_NOW_ISO", "").strip()
        now = _parse_iso_dt(now_override, tz) if now_override else datetime.now(tz)

        try:
            with open(plan_file, "r", encoding="utf-8") as fh:
                plan_data = json.load(fh)
            if not isinstance(plan_data, dict):
                plan_data = {}
        except Exception:
            sys.stdout.write(
                json.dumps(
                    {
                        "action": "skip",
                        "reason": "missing_plan",
                        "meeting": None,
                        "remaining_planned_items": [],
                    }
                )
                + "\n"
            )
            return 0

        daily_note_text: str | None = None
        if daily_note_path and os.path.isfile(daily_note_path):
            try:
                with open(daily_note_path, "r", encoding="utf-8") as fh:
                    daily_note_text = fh.read()
            except Exception:
                daily_note_text = None

        personal_events: list[dict] = []
        work_events: list[dict] = []
        if not skip_meeting_check and creds_dir and os.path.isdir(creds_dir):
            try:
                from auth.credential_store import LocalDirectoryCredentialStore

                store = LocalDirectoryCredentialStore(creds_dir)
                day_start = datetime(now.year, now.month, now.day, 0, 0, 0, tzinfo=tz)
                day_end = day_start + timedelta(days=1)
                if work_email:
                    work_events = _fetch_primary_events(
                        _load_valid_creds(store, work_email), day_start, day_end
                    )
                if personal_email:
                    personal_events = _fetch_primary_events(
                        _load_valid_creds(store, personal_email), day_start, day_end
                    )
            except Exception:
                pass

        result = evaluate_checkin_gate(
            plan_data=plan_data,
            daily_note_text=daily_note_text,
            personal_events=personal_events,
            work_events=work_events,
            now=now,
            tz=tz,
            skip_meeting_check=skip_meeting_check,
        )
        sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n")
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';

  morningDigestPromptFile =
    pkgs.writeText "morning-digest-prompt.txt" hcCfg.proactive.prompts.morningDigest;

  preDailyPromptFile =
    pkgs.writeText "pre-daily-prompt.txt" hcCfg.proactive.prompts.preDaily;
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
        WORK_GOOGLE_EMAIL=${lib.escapeShellArg (
          if workEnabled
          then workGoogleEmail
          else ""
        )}
        GOOGLE_CREDS_DIR=${lib.escapeShellArg googleCredsDir}
        DEFAULT_VAULT_DIR=${lib.escapeShellArg vaultDir}
        VAULT_DIR="''${HEY_COMPUTER_VAULT_DIR:-$DEFAULT_VAULT_DIR}"
        DEFAULT_HEY_COMPUTER_BIN=${lib.escapeShellArg heyComputer}
        HEY_COMPUTER_BIN="''${HEY_COMPUTER_BIN:-$DEFAULT_HEY_COMPUTER_BIN}"
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
            notify-send -e --app-name=hey-computer --urgency=normal \
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
          local standup_status="''${6:-none}"
          jq -cn \
            --arg date "$today" \
            --argjson checked_at "$checked_at" \
            --arg status "$status" \
            --argjson is_workday "$is_workday" \
            --arg reason "$reason" \
            --arg standup_status "$standup_status" \
            '{
              date: $date,
              checked_at: $checked_at,
              status: $status,
              is_workday: $is_workday,
              workday: $is_workday,
              reason: $reason,
              arbeit_event: null,
              override_event: null,
              work_windows: null,
              work_minutes: 0,
              work_mode: null,
              standup_status: $standup_status,
              standup_window: null
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
            and has("standup_status")
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
            out=$(make_workday_json "$today" "$now" "day_off" "false" "work_disabled" "none")
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
            out=$(make_workday_json "$today" "$now" "day_off" "false" "weekend" "none")
            write_json_atomic "$WORKDAY_CACHE" "$out" || true
            printf '%s\n' "$out"
            return 0
          fi

          if [ "$refresh" != "1" ] && [ -f "$WORKDAY_CACHE" ]; then
            local meta=() c_date="" c_checked_at="" c_status="" c_has_v2=""
            mapfile -t meta < <(
              jq -r '
                select(type == "object")
                | (.date // ""),
                  ((.checked_at // 0) | tostring),
                  (.status // ""),
                  (if has("standup_status") then "1" else "0" end)
              ' "$WORKDAY_CACHE" 2>/dev/null || true
            )
            c_date="''${meta[0]:-}"
            c_checked_at="''${meta[1]:-}"
            c_status="''${meta[2]:-}"
            c_has_v2="''${meta[3]:-0}"
            if [ "$c_date" = "$today" ] && [ "$c_has_v2" = "1" ]; then
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
            make_workday_json "$today" "$now" "unknown" "true" "cache_miss" "unknown"
            return 0
          fi

          if out=$(PYTHONPATH=${lib.escapeShellArg googleWorkspaceSitePackages} \
            ${googleWorkspacePython}/bin/python3 ${workdayCheckScript} \
            "$PERSONAL_GOOGLE_EMAIL" "$WORK_GOOGLE_EMAIL" "$GOOGLE_CREDS_DIR" "$today" "$WORKDAY_CACHE" 2>/dev/null) \
            && [ -n "$out" ]; then
            printf '%s\n' "$out"
            return 0
          fi

          out=$(make_workday_json "$today" "$now" "unknown" "true" "api_error" "unknown")
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
            | "workday_status: \($st)\n"
              + "workday_reason: \($detail)\n"
              + "arbeit_event: \(.arbeit_event // "none")\n"
              + "work_windows: \(.work_windows // "none")\n"
              + "work_minutes: \((.work_minutes // 0) | tostring)\n"
              + "work_mode: \(.work_mode // "none")\n"
              + "standup_status: \(.standup_status // "none")\n"
              + "standup_window: \(.standup_window // "none")"
          ' <<<"$workday_json" 2>/dev/null || printf 'workday_status: unknown\nworkday_reason: api_error\narbeit_event: none\nwork_windows: none\nwork_minutes: 0\nwork_mode: none\nstandup_status: unknown\nstandup_window: none\n'
        }

        format_pre_daily_plan_context() {
          local today="$1"
          local plan_file="$STATE_DIR/day-plan-$today.json"
          [ -f "$plan_file" ] || return 0
          jq -r --arg today "$today" '
            select(
              type == "object"
              and ((.date // $today) == $today)
              and (
                .pre_daily_sync == true
                or ((.pre_daily_sync | type) == "object" and .pre_daily_sync.enabled == true)
              )
            )
            | ((.roter_faden // .roterFaden // "") | tostring | gsub("[\r\n]+"; " ")) as $rf
            | (
                (.planned_items // [])
                | if type == "array" then
                    map(
                      if type == "string" then .
                      elif type == "object" then (.text // .title // "")
                      else ""
                      end
                    )
                    | map(gsub("[\r\n]+"; " ") | select(length > 0))
                  else []
                  end
              ) as $tasks
            | (if ($rf | length) > 0 then "active_roter_faden: \($rf)\n" else "" end)
              + (if ($tasks | length) > 0 then "active_plan_tasks: \($tasks | join("; "))\n" else "" end)
          ' "$plan_file" 2>/dev/null || true
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
          local today stamp loc workday_json workday_status standup_status workday_block plan_block base_prompt prompt manual
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
          standup_status=$(jq -r '.standup_status // "unknown"' <<<"$workday_json" 2>/dev/null || printf 'unknown')
          if [ "$manual" != "1" ] && { [ "$workday_status" = "day_off" ] || [ "$standup_status" = "declined" ] || [ "$standup_status" = "none" ]; }; then
            exit 0
          fi

          if ! daemon_ready; then
            log_failure "pre-daily" "hey-computer daemon is not ready before the 10:00 daily."
            exit 1
          fi

          workday_block=$(format_workday_block "$workday_json")
          plan_block=$(format_pre_daily_plan_context "$today")
          base_prompt=$(cat ${preDailyPromptFile})
          if [ -n "$plan_block" ]; then
            printf -v prompt '%s\n\n<untrusted_collector_output>\ndate: %s\nlocation: %s\n%s\n%s\n</untrusted_collector_output>' \
              "$base_prompt" "$today" "$loc" "$workday_block" "$plan_block"
          else
            printf -v prompt '%s\n\n<untrusted_collector_output>\ndate: %s\nlocation: %s\n%s\n</untrusted_collector_output>' \
              "$base_prompt" "$today" "$loc" "$workday_block"
          fi

          run_and_wait_task "pre-daily" "$stamp" "$today" "$prompt" || exit 1
        }

        collect_morning_digest() {
          local today stamp sched_json should_skip last_run_at last_status last_date now_ms loc manual workday_json
          today=$(date +%Y-%m-%d)
          stamp="$STATE_DIR/morning-digest.last"
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"

          if [ "$manual" != "1" ]; then
            # Honour legacy stamp file on same-day upgrades.
            if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
              exit 0
            fi

            now_ms=$(( $(date +%s) * 1000 ))
            sched_json=$(${heyComputer} schedule show morning-digest --json 2>/dev/null || true)

            if jq -e 'type == "object"' >/dev/null 2>&1 <<<"$sched_json"; then
              # Suppress if top-level last_run_at is today with status ok/suppressed,
              # if any recent turn created today is completed/suppressed/running/queued,
              # or if a failed run (top-level or today's recent turn) is within the
              # 15-minute (900000 ms) retry cooldown. Fail closed on jq errors.
              should_skip=$(jq -r --arg today "$today" --argjson now_ms "$now_ms" '
                def is_today($ms):
                  ($ms | type == "number")
                  and ($ms > 0)
                  and ((($ms / 1000) | floor | strflocaltime("%Y-%m-%d")) == $today);
                def turn_is_today:
                  if (.created_at_ms | type == "number") and (.created_at_ms > 0) then
                    is_today(.created_at_ms)
                  else
                    (.created_local | type == "string") and (.created_local | startswith($today))
                  end;

                (
                  is_today(.last_run_at)
                  and (.last_status == "ok" or .last_status == "suppressed")
                )
                or (
                  (.last_status == "failed")
                  and (.last_run_at | type == "number")
                  and (.last_run_at > 0)
                  and (($now_ms - .last_run_at) < 900000)
                )
                or (
                  (.recent_turns | if type == "array" then . else [] end)
                  | any(
                      (type == "object")
                      and turn_is_today
                      and (
                        (.status | IN("completed", "suppressed", "running", "queued"))
                        or (
                          .status == "failed"
                          and (
                            (.finished_at_ms // .created_at_ms)
                            | (type == "number") and (. > 0) and (($now_ms - .) < 900000)
                          )
                        )
                      )
                    )
                )
              ' <<<"$sched_json" 2>/dev/null || printf 'error')
              if [ "$should_skip" != "false" ]; then
                exit 0
              fi
            elif [ -n "''${HEY_COMPUTER_SCHEDULE_ID:-}" ]; then
              # Fail-closed fallback to scheduler-injected env vars when `schedule show`
              # is unavailable (e.g. transient config/store issue during rebuild).
              last_run_at="''${HEY_COMPUTER_SCHEDULE_LAST_RUN_AT:-0}"
              last_status="''${HEY_COMPUTER_SCHEDULE_LAST_STATUS:-}"
              if [[ "$last_run_at" =~ ^[0-9]+$ ]] && [ "$last_run_at" -gt 0 ]; then
                last_date=$(date -d "@$((last_run_at / 1000))" +%Y-%m-%d 2>/dev/null || true)
                if [ "$last_date" = "$today" ] && { [ "$last_status" = "ok" ] || [ "$last_status" = "suppressed" ]; }; then
                  exit 0
                fi
                if [ "$last_status" = "failed" ] && [ $((now_ms - last_run_at)) -lt 900000 ]; then
                  exit 0
                fi
              fi
            else
              # Fail closed: never trigger an unwanted LLM brief if schedule state
              # cannot be verified from either `schedule show` or scheduler env vars.
              exit 0
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
          local today stamp loc manual workday_json workday_status standup_status plan_block
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
          standup_status=$(jq -r '.standup_status // "unknown"' <<<"$workday_json" 2>/dev/null || printf 'unknown')
          if [ "$manual" != "1" ] && { [ "$workday_status" = "day_off" ] || [ "$standup_status" = "declined" ] || [ "$standup_status" = "none" ]; }; then
            exit 0
          fi

          printf 'date: %s\nlocation: %s\n' "$today" "$loc"
          format_workday_block "$workday_json"
          plan_block=$(format_pre_daily_plan_context "$today")
          if [ -n "$plan_block" ]; then
            printf '%s\n' "$plan_block"
          fi
        }

        defer_day_plan_checkin() {
          local today="$1"
          local slot_id="$2"
          local defer_file="$STATE_DIR/day-plan-deferrals-$today.json"
          local now_hour now_min now_mins defer_json current_count next_count updated_json job_name

          if [ -n "''${CHECKIN_NOW_ISO:-}" ]; then
            now_hour=$(date -d "$CHECKIN_NOW_ISO" +%H 2>/dev/null || date +%H)
            now_min=$(date -d "$CHECKIN_NOW_ISO" +%M 2>/dev/null || date +%M)
          else
            now_hour=$(date +%H)
            now_min=$(date +%M)
          fi
          now_mins=$(( 10#$now_hour * 60 + 10#$now_min ))

          # Never defer past 18:00 local time.
          if [ $((now_mins + 20)) -ge 1080 ]; then
            return 0
          fi

          defer_json="{}"
          if [ -f "$defer_file" ]; then
            defer_json=$(jq -c 'if type == "object" then . else {} end' "$defer_file" 2>/dev/null || printf '{}')
          fi

          current_count=$(jq -r --arg slot "$slot_id" '(.[$slot] // 0) | tonumber? // 0 | floor' <<<"$defer_json" 2>/dev/null || printf '0')
          if ! [[ "$current_count" =~ ^[0-9]+$ ]] || [ "$current_count" -ge 2 ]; then
            return 0
          fi

          next_count=$((current_count + 1))
          if updated_json=$(jq -c --arg slot "$slot_id" --argjson count "$next_count" '. + {($slot): $count}' <<<"$defer_json" 2>/dev/null); then
            write_json_atomic "$defer_file" "$updated_json" || true
          fi

          job_name="''${HEY_COMPUTER_SCHEDULE_NAME:-day-plan-checkin-$slot_id}"
          "$HEY_COMPUTER_BIN" schedule edit "$job_name" --schedule "in 20m" >/dev/null 2>&1 || true
          return 0
        }

        collect_day_plan_checkin() {
          local slot_id="''${1:-checkin}"
          local today manual plan_file daily_note gate_json gate_action workday_json workday_status work_windows roter_faden remaining_block

          if [ -n "''${CHECKIN_NOW_ISO:-}" ]; then
            today=$(date -d "$CHECKIN_NOW_ISO" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
          else
            today=$(date +%Y-%m-%d)
          fi
          manual="''${HEY_COMPUTER_SCHEDULE_MANUAL:-0}"
          plan_file="$STATE_DIR/day-plan-$today.json"

          # Gate 1: Require today's active day-plan state snapshot.
          if [ ! -f "$plan_file" ] || ! jq -e --arg today "$today" 'type == "object" and ((.date // $today) == $today)' "$plan_file" >/dev/null 2>&1; then
            exit 0
          fi

          # Gate 2: Session unlocked + network online (unless manual).
          if [ "$manual" != "1" ]; then
            if ! session_unlocked || ! network_online; then
              defer_day_plan_checkin "$today" "$slot_id"
              exit 0
            fi
          fi

          # Gates 3 & 4: Dual-calendar live-meeting check + planned_items completion check.
          daily_note=""
          if [ -n "$VAULT_DIR" ]; then
            daily_note="$VAULT_DIR/Journal/$today.md"
          fi
          gate_json=$(PYTHONPATH=${lib.escapeShellArg googleWorkspaceSitePackages} \
            ${googleWorkspacePython}/bin/python3 ${checkinGateScript} \
            "$PERSONAL_GOOGLE_EMAIL" "$WORK_GOOGLE_EMAIL" "$GOOGLE_CREDS_DIR" \
            "$plan_file" "$daily_note" "$manual" 2>/dev/null || true)

          if [ -z "$gate_json" ] || ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$gate_json"; then
            exit 0
          fi

          gate_action=$(jq -r '.action // "skip"' <<<"$gate_json" 2>/dev/null || printf 'skip')
          case "$gate_action" in
          defer)
            if [ "$manual" != "1" ]; then
              defer_day_plan_checkin "$today" "$slot_id"
            fi
            exit 0
            ;;
          skip)
            exit 0
            ;;
          run)
            ;;
          *)
            exit 0
            ;;
          esac

          # Gate 5: Emit structured reassessment payload.
          workday_json=$(resolve_workday 0 0)
          workday_status=$(jq -r '.status // "unknown"' <<<"$workday_json" 2>/dev/null || printf 'unknown')
          work_windows=$(jq -r '.work_windows // "none"' <<<"$workday_json" 2>/dev/null || printf 'none')
          roter_faden=$(jq -r '(.roter_faden // .roterFaden // "") | tostring | gsub("[\r\n]+"; " ")' "$plan_file" 2>/dev/null || true)
          remaining_block=$(jq -r '(.remaining_planned_items // []) | map("- [ ] " + (. | tostring | gsub("[\r\n]+"; " "))) | join("\n")' <<<"$gate_json" 2>/dev/null || true)

          printf 'date: %s\n' "$today"
          printf 'slot_id: %s\n' "$slot_id"
          printf 'workday_status: %s\n' "$workday_status"
          printf 'work_windows: %s\n' "$work_windows"
          printf 'roter_faden: %s\n' "''${roter_faden:-none}"
          printf 'remaining_planned_items:\n%s\n' "$remaining_block"
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
        collect-day-plan-checkin)
          collect_day_plan_checkin "''${2:-checkin}"
          ;;
        morning-digest)
          run_morning_digest
          ;;
        pre-daily)
          run_pre_daily
          ;;
        *)
          echo "Usage: hey-computer-proactive <location|weather|workday|collect-morning-digest|collect-pre-daily|collect-day-plan-checkin|morning-digest|pre-daily>" >&2
          exit 2
          ;;
        esac
      '';
  };
}
