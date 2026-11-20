#!/usr/bin/env python3
"""
memories.py — build an "On this day" feed from Immich.

For every past year (up to --years back), asks Immich for assets taken on
today's month/day and writes a JSON feed the Phase 2 frontend can render as a
slideshow. Read-only: only uses the REST API, never touches UPLOAD_LOCATION.

Config (env vars, or read from the repo's .env if unset):
    IMMICH_URL      e.g. http://localhost:2283
    IMMICH_API_KEY  Immich web UI -> Account Settings -> API Keys
                    (needs at least the asset.read permission)

Usage:
    python scripts/memories.py                       # today, writes scripts/output/memories.json
    python scripts/memories.py --date 2026-07-04     # a specific day
    python scripts/memories.py --years 20 --out D:/homelab/gallery-feeds/memories.json

Schedule nightly on Windows (Task Scheduler), e.g.:
    schtasks /Create /TN "Immich Memories" /SC DAILY /ST 06:00 ^
      /TR "py -3 C:\\path\\to\\homelab-gallery\\scripts\\memories.py"

Stdlib only — no pip install needed.

Note: verified against the Immich API shape used by v1.1xx–v3 (POST
/api/search/metadata). If a future release changes it, check
http://<host>:2283/doc for the current OpenAPI spec.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PAGE_SIZE = 250


def load_dotenv(path: Path) -> None:
    """Minimal .env reader: KEY=VALUE lines, does not override real env vars."""
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


class Immich:
    def __init__(self, base_url: str, api_key: str, timeout: float = 30.0):
        self.base = base_url.rstrip("/")
        self.key = api_key
        self.timeout = timeout

    def _request(self, method: str, path: str, body: dict | None = None) -> dict:
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            f"{self.base}/api{path}",
            data=data,
            method=method,
            headers={
                "x-api-key": self.key,
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:500]
            raise SystemExit(f"Immich API {method} {path} -> HTTP {e.code}: {detail}") from None
        except urllib.error.URLError as e:
            raise SystemExit(f"Cannot reach Immich at {self.base}: {e.reason}") from None

    def ping(self) -> None:
        self._request("GET", "/server/ping")

    def assets_taken_between(self, start: dt.datetime, end: dt.datetime) -> list[dict]:
        items: list[dict] = []
        page: int | None = 1
        while page:
            res = self._request(
                "POST",
                "/search/metadata",
                {
                    "takenAfter": start.isoformat(),
                    "takenBefore": end.isoformat(),
                    "withExif": True,
                    "order": "asc",
                    "size": PAGE_SIZE,
                    "page": page,
                },
            )
            assets = res.get("assets", {})
            items.extend(assets.get("items", []))
            nxt = assets.get("nextPage")
            page = int(nxt) if nxt else None
        return items


def same_day_in_year(day: dt.date, year: int) -> dt.date | None:
    try:
        return day.replace(year=year)
    except ValueError:  # Feb 29 in a non-leap year
        return None


def summarise(asset: dict, base_url: str) -> dict:
    exif = asset.get("exifInfo") or {}
    aid = asset["id"]
    return {
        "id": aid,
        "type": asset.get("type"),  # IMAGE | VIDEO
        "takenAt": asset.get("localDateTime") or asset.get("fileCreatedAt"),
        "fileName": asset.get("originalFileName"),
        "description": exif.get("description") or None,
        "city": exif.get("city"),
        "country": exif.get("country"),
        "lat": exif.get("latitude"),
        "lon": exif.get("longitude"),
        # Relative API paths; the frontend adds the base URL + auth.
        "thumbnail": f"/api/assets/{aid}/thumbnail?size=preview",
        "original": f"/api/assets/{aid}/original",
        "webUrl": f"{base_url.rstrip('/')}/photos/{aid}",
    }


def main() -> int:
    load_dotenv(REPO_ROOT / ".env")

    ap = argparse.ArgumentParser(description="Build an 'On this day' feed from Immich.")
    ap.add_argument("--date", type=dt.date.fromisoformat, default=dt.date.today(),
                    help="Reference date (YYYY-MM-DD). Default: today.")
    ap.add_argument("--years", type=int, default=30, help="How many years back to look.")
    ap.add_argument("--out", type=Path, default=REPO_ROOT / "scripts" / "output" / "memories.json")
    ap.add_argument("--url", default=os.environ.get("IMMICH_URL", "http://localhost:2283"))
    ap.add_argument("--api-key", default=os.environ.get("IMMICH_API_KEY", ""))
    args = ap.parse_args()

    if not args.api_key:
        print("IMMICH_API_KEY is not set (env var or .env).", file=sys.stderr)
        return 2

    client = Immich(args.url, args.api_key)
    client.ping()

    tz = dt.datetime.now().astimezone().tzinfo  # local timezone of this PC
    groups = []
    for back in range(1, args.years + 1):
        year = args.date.year - back
        day = same_day_in_year(args.date, year)
        if day is None:
            continue
        start = dt.datetime.combine(day, dt.time.min, tzinfo=tz)
        end = start + dt.timedelta(days=1)
        assets = client.assets_taken_between(start, end)
        if assets:
            groups.append({
                "yearsAgo": back,
                "date": day.isoformat(),
                "count": len(assets),
                "assets": [summarise(a, args.url) for a in assets],
            })

    feed = {
        "generatedAt": dt.datetime.now(tz).isoformat(timespec="seconds"),
        "referenceDate": args.date.isoformat(),
        "total": sum(g["count"] for g in groups),
        "groups": groups,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(feed, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"{feed['total']} memories across {len(groups)} year(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
