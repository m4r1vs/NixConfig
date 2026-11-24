{pkgs, ...}: {
  transit =
    pkgs.writers.writePython3 "transit" {
      flakeIgnore = ["E501" "W503"];
    } ''
      import argparse
      import datetime as dt
      import json
      import os
      import sys
      import urllib.error
      import urllib.parse
      import urllib.request
      from zoneinfo import ZoneInfo

      API = os.environ.get("TRANSIT_API", "https://api.transitous.org").rstrip("/")
      BIAS = os.environ.get("TRANSIT_BIAS", "53.5511,9.9937")
      TZ = ZoneInfo(os.environ.get("TRANSIT_TZ", "Europe/Berlin"))
      UA = "hey-computer-transit/0.1 (personal NixOS voice assistant; https://github.com/m4r1vs/hey-computer)"
      TIMEOUT = 10

      MODE_GROUPS = {
          "rail": {"HIGHSPEED_RAIL", "LONG_DISTANCE", "REGIONAL_RAIL", "REGIONAL_FAST_RAIL", "NIGHT_RAIL", "RAIL"},
          "subway": {"SUBWAY"},
          "suburban": {"SUBURBAN"},
          "bus": {"BUS", "COACH"},
          "ferry": {"FERRY"},
          "tram": {"TRAM"},
      }

      MODE_LABELS = {
          "HIGHSPEED_RAIL": "ICE/IC",
          "LONG_DISTANCE": "Train",
          "REGIONAL_RAIL": "Regional",
          "REGIONAL_FAST_RAIL": "RE",
          "NIGHT_RAIL": "Night",
          "RAIL": "Rail",
          "SUBURBAN": "S-Bahn",
          "SUBWAY": "U-Bahn",
          "TRAM": "Tram",
          "BUS": "Bus",
          "COACH": "Coach",
          "FERRY": "Ferry",
          "WALK": "Walk",
      }


      def get_json(path, params):
          query = urllib.parse.urlencode([(k, v) for k, v in params.items() if v is not None])
          url = f"{API}{path}?{query}"
          req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
          try:
              with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                  return json.loads(resp.read().decode("utf-8"))
          except urllib.error.HTTPError as e:
              body = e.read().decode("utf-8", errors="replace").strip()[:200]
              sys.exit(f"transit: HTTP {e.code} from {path}: {body or e.reason}")
          except Exception as e:
              sys.exit(f"transit: request failed ({path}): {e}")


      def parse_time(raw):
          if not raw:
              return None
          now = dt.datetime.now(TZ)
          text = raw.strip()
          if len(text) == 5 and text[2] == ":":
              h, m = map(int, text.split(":"))
              local = now.replace(hour=h, minute=m, second=0, microsecond=0)
              if local < now - dt.timedelta(minutes=5):
                  local += dt.timedelta(days=1)
          else:
              local = dt.datetime.fromisoformat(text)
              if local.tzinfo is None:
                  local = local.replace(tzinfo=TZ)
          return local.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


      def parse_iso(raw):
          if not raw:
              return None
          return dt.datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(TZ)


      def fmt_delay(actual, scheduled, real_time, cancelled):
          if cancelled:
              return "CANCELLED"
          parts = []
          if actual and scheduled:
              diff = round((actual - scheduled).total_seconds() / 60)
              if diff > 0:
                  parts.append(f"+{diff}m")
              elif diff < 0:
                  parts.append(f"{diff}m")
              else:
                  parts.append("on time")
          if real_time:
              parts.append("live")
          else:
              parts.append("sched")
          return ", ".join(parts)


      def area_summary(entry):
          areas = [a.get("name", "") for a in entry.get("areas", []) if a.get("name")]
          for preferred in reversed(areas):
              if preferred != "Deutschland":
                  return preferred
          return areas[0] if areas else ""


      def geocode(query, stop_only=False):
          params = {"text": query, "place": BIAS}
          if stop_only:
              params["type"] = "STOP"
          results = get_json("/api/v1/geocode", params)
          if not results and stop_only:
              results = get_json("/api/v1/geocode", {"text": query, "place": BIAS})
          return results


      def looks_like_stop_id(value):
          return "_" in value and (":" in value or value.startswith("de-"))


      def pick_stop(query):
          if looks_like_stop_id(query):
              return {"id": query, "name": query, "type": "STOP"}
          results = geocode(query, stop_only=True)
          if not results:
              sys.exit(f"transit: no stop found for {query!r}")
          # Prefer German DELFI stops when a top match shares the same stop name.
          top_name = results[0].get("name", "").lower()
          for entry in results[:5]:
              if entry.get("id", "").startswith("de-DELFI_") and entry.get("name", "").lower() == top_name:
                  return entry
          return results[0]


      def pick_place(query):
          if looks_like_stop_id(query):
              return query, query
          results = geocode(query, stop_only=False)
          if not results:
              sys.exit(f"transit: no place found for {query!r}")
          top = results[0]
          top_name = top.get("name", "").lower()
          for entry in results[:5]:
              if entry.get("type") == "STOP" and entry.get("id", "").startswith("de-DELFI_") and entry.get("name", "").lower() == top_name:
                  top = entry
                  break
          label = top.get("name", query)
          area = area_summary(top)
          if area and area.lower() not in label.lower():
              label = f"{label} ({area})"
          lat, lon = top.get("lat"), top.get("lon")
          if lat is not None and lon is not None:
              return f"{lat},{lon}", label
          return top["id"], label


      def cmd_stops(args):
          results = geocode(args.query, stop_only=True)
          if not results:
              sys.exit(f"transit: no stops found for {args.query!r}")
          for entry in results[: args.limit]:
              modes = ",".join(entry.get("modes", [])) or "-"
              area = area_summary(entry)
              print(f"{entry.get('name')} ({area}) | {modes} | {entry.get('id')}")


      def cmd_departures(args):
          stop = pick_stop(args.stop)
          allowed_modes = MODE_GROUPS.get(args.mode.lower()) if args.mode else None
          fetch_n = max(args.limit * 8, 60) if allowed_modes else max(args.limit * 2, 12)
          params = {
              "stopId": stop["id"],
              "exactRadius": "false",
              "radius": str(args.radius),
              "n": str(fetch_n),
              "time": parse_time(args.at),
              "mode": ",".join(sorted(allowed_modes)) if allowed_modes else None,
          }
          data = get_json("/api/v1/stoptimes", params)
          raw_times = data.get("stopTimes", [])

          # Deduplicate overlapping feeds (e.g. DELFI + cross-border), preferring realTime=True.
          dedup = {}
          order = []
          for item in raw_times:
              mode = item.get("mode", "")
              if allowed_modes and mode not in allowed_modes:
                  continue
              place = item.get("place", {})
              dep_raw = place.get("departure") or place.get("arrival")
              sched_raw = place.get("scheduledDeparture") or place.get("scheduledArrival") or dep_raw
              line = item.get("displayName") or item.get("routeShortName") or MODE_LABELS.get(mode, mode)
              headsign = item.get("headsign") or item.get("tripTo", {}).get("name") or ""
              key = (line, headsign, sched_raw)
              existing = dedup.get(key)
              if existing is None:
                  dedup[key] = item
                  order.append(key)
              elif item.get("realTime") and not existing.get("realTime"):
                  dedup[key] = item

          items = [dedup[k] for k in order][: args.limit]
          stop_label = stop.get("name", args.stop)
          area = area_summary(stop)
          header = f"Departures: {stop_label}" + (f" ({area})" if area else "")
          print(header)
          if not items:
              print("No upcoming departures found.")
              return

          now = dt.datetime.now(TZ)
          for item in items:
              place = item.get("place", {})
              actual = parse_iso(place.get("departure") or place.get("arrival"))
              sched = parse_iso(place.get("scheduledDeparture") or place.get("scheduledArrival"))
              if not actual:
                  continue
              cancelled = bool(item.get("cancelled") or item.get("tripCancelled") or place.get("cancelled"))
              status = fmt_delay(actual, sched, bool(item.get("realTime")), cancelled)
              time_str = actual.strftime("%H:%M") if actual.date() == now.date() else actual.strftime("%Y-%m-%d %H:%M")
              line = item.get("displayName") or item.get("routeShortName") or MODE_LABELS.get(item.get("mode", ""), "Transit")
              headsign = item.get("headsign") or item.get("tripTo", {}).get("name") or "?"
              track = place.get("track")
              stop_name = place.get("name", "")
              extras = []
              if track:
                  extras.append(f"Pl. {track}")
              if stop_name and stop_name.lower() != stop_label.lower():
                  extras.append(f"@ {stop_name}")
              suffix = f" | {' '.join(extras)}" if extras else ""
              print(f"  {time_str} ({status}) | {line} -> {headsign}{suffix}")


      def cmd_route(args):
          from_place, from_label = pick_place(args.origin)
          to_place, to_label = pick_place(args.destination)
          params = {
              "fromPlace": from_place,
              "toPlace": to_place,
              "numItineraries": str(args.limit),
              "time": parse_time(args.at),
              "arriveBy": "true" if args.arrive_by else "false",
          }
          data = get_json("/api/v1/plan", params)
          itineraries = data.get("itineraries", [])[: args.limit]
          print(f"Route: {from_label} -> {to_label}")
          if not itineraries:
              print("No transit routes found.")
              return

          for idx, itin in enumerate(itineraries, 1):
              start = parse_iso(itin.get("startTime"))
              end = parse_iso(itin.get("endTime"))
              mins = round(itin.get("duration", 0) / 60)
              transfers = itin.get("transfers", 0)
              s_str = start.strftime("%H:%M") if start else "?"
              e_str = end.strftime("%H:%M") if end else "?"
              t_word = "transfer" if transfers == 1 else "transfers"
              print(f"\nOption {idx}: {s_str} -> {e_str} ({mins} min, {transfers} {t_word})")
              for leg in itin.get("legs", []):
                  mode = leg.get("mode", "")
                  f_obj = leg.get("from", {})
                  t_obj = leg.get("to", {})
                  dep = parse_iso(f_obj.get("departure"))
                  s_dep = parse_iso(f_obj.get("scheduledDeparture"))
                  arr = parse_iso(t_obj.get("arrival"))
                  d_str = dep.strftime("%H:%M") if dep else "?"
                  a_str = arr.strftime("%H:%M") if arr else "?"
                  if mode == "WALK":
                      w_mins = max(1, round(leg.get("duration", 0) / 60))
                      print(f"  {d_str}-{a_str}  Walk ({w_mins} min)")
                      continue
                  line = leg.get("displayName") or leg.get("routeShortName") or MODE_LABELS.get(mode, mode)
                  headsign = leg.get("headsign") or t_obj.get("name") or ""
                  status = fmt_delay(dep, s_dep, bool(leg.get("realTime")), bool(leg.get("cancelled")))
                  f_track = f" (Pl. {f_obj['track']})" if f_obj.get("track") else ""
                  t_track = f" (Pl. {t_obj['track']})" if t_obj.get("track") else ""
                  print(
                      f"  {d_str}-{a_str}  {line} -> {headsign} ({status}) | "
                      f"{f_obj.get('name', '?')}{f_track} -> {t_obj.get('name', '?')}{t_track}"
                  )


      def main():
          p = argparse.ArgumentParser(prog="transit", description="Live HVV & DB transit CLI via Transitous (MOTIS 2)")
          sub = p.add_subparsers(dest="cmd", required=True)

          p_stops = sub.add_parser("stops", help="Search stops/stations")
          p_stops.add_argument("query")
          p_stops.add_argument("--limit", type=int, default=5)
          p_stops.set_defaults(func=cmd_stops)

          p_dep = sub.add_parser("departures", help="Live departures at a stop")
          p_dep.add_argument("stop")
          p_dep.add_argument("--limit", type=int, default=8)
          p_dep.add_argument("--mode", choices=sorted(MODE_GROUPS.keys()))
          p_dep.add_argument("--at", help="HH:MM or ISO-8601 local time")
          p_dep.add_argument("--radius", type=int, default=200)
          p_dep.set_defaults(func=cmd_departures)

          p_route = sub.add_parser("route", help="Plan a public transit route")
          p_route.add_argument("origin")
          p_route.add_argument("destination")
          p_route.add_argument("--at", help="HH:MM or ISO-8601 local time")
          p_route.add_argument("--arrive-by", action="store_true")
          p_route.add_argument("--limit", type=int, default=3)
          p_route.set_defaults(func=cmd_route)

          args = p.parse_args()
          args.func(args)


      if __name__ == "__main__":
          main()
    '';
}
