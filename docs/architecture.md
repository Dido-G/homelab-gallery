# Architecture

```
 Dad's phone (Immich app)                     Any browser on the LAN
   │ background upload over Wi-Fi                │ Phase 1: Immich web UI  :2283
   │ http://<PC-IP>:2283                         │ Phase 2: custom frontend (below)
   ▼                                             ▼
┌──────────────────────── Windows PC (on-demand) ────────────────────────────┐
│ Docker Desktop (WSL 2 backend)                                              │
│                                                                             │
│  immich_server ──────► immich_machine_learning   (faces, smart search)      │
│     │   │                     └─ volume: model-cache                        │
│     │   └──────────────► immich_redis (Valkey 9)  (job queue)               │
│     └──────────────────► immich_postgres (PG14 + VectorChord)               │
│     │                         └─ named volume: pgdata  (in WSL VHDX on C:)  │
│     ▼                                                                       │
│  bind mount  D:\Gallery  ⇄  /data   (originals, thumbnails, encoded video,  │
│                                      nightly DB dumps in backups/)          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key decisions

| Decision | Why |
|---|---|
| Official Immich compose, minimal diff | Easy upgrades; the header of `docker-compose.yml` lists every local change. |
| Postgres in named volume `pgdata` | NTFS bind mounts via Docker Desktop don't keep the Unix permissions / fsync behaviour Postgres needs → permission errors or corruption. |
| Media on `D:\Gallery` bind mount | Big drive, files visible from Windows. Slower than a volume (crosses the WSL file-share boundary) — fine for a family gallery. |
| `/etc/localtime` mount removed, `TZ` in `.env` | That file doesn't exist on Windows. |
| `IMMICH_VERSION` pinned to an exact tag | PC is unattended and on-demand; updates happen deliberately via `scripts/update.ps1`. |
| One-way backup | Phone deletions don't propagate, so `D:\Gallery` must itself be backed up elsewhere. |
| On-demand host | Mobile app queues uploads; nothing is lost while the PC is off. |

## Phase 2 — custom frontend

```
 browser ──► gallery-web (Caddy/nginx, e.g. :8080)
               ├─ /        → static build of frontend/
               └─ /api/*   → reverse proxy → immich-server:2283/api/*
```

- Same-origin proxy avoids CORS problems and keeps the API key on one origin.
- REST API only (OpenAPI docs at `http://<PC-IP>:2283/doc`): search/timeline
  (`/api/search/metadata`), thumbnails (`/api/assets/{id}/thumbnail`), GPS
  (`exifInfo.latitude/longitude`, `/api/map/markers`), upload (`POST /api/assets`).
- **Never** reads or writes `D:\Gallery` directly — Immich's layout is internal and
  can change between versions.
- `scripts/memories.py` runs nightly (Task Scheduler) and writes a JSON feed the
  slideshow uses. (Immich's own app/UI also has a built-in memories feature.)

## Exposure

LAN only. Port 2283 is allowed on Windows *Private* networks only. Don't port-forward
it on the router; if remote access is ever needed, use a VPN (Tailscale/WireGuard).
