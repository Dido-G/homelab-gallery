# CLAUDE.md

Guidance for Claude Code working in this repo.

## What this is
Self-hosted family photo/video gallery on a **Windows PC** (Docker Desktop + WSL 2),
powered by **Immich**. The PC is on-demand, not 24/7. The Immich mobile app on Dad's
phone queues media and uploads over home Wi-Fi when the PC is up. One-way backup:
phone deletions never remove anything from the gallery.

## Architecture (see docs/architecture.md)
- `docker-compose.yml` is the **official Immich release compose** with a minimal,
  documented diff (listed in its header). Keep it that way:
  - Postgres → Docker **named volume `pgdata`**. Never switch it to an NTFS/`D:\` bind mount.
  - Media → `UPLOAD_LOCATION` = `D:/homelab/gallery` (or `/mnt/d/homelab/gallery` from WSL), bind-mounted to `/data`.
  - No `/etc/localtime` mount; timezone comes from `TZ` in `.env`.
  - `IMMICH_VERSION` is pinned to an exact tag. When upgrading, re-sync image tags and
    digests from that release's `docker-compose.yml` / `example.env` and update the header.
- **Phase 1:** stock Immich web UI + mobile app.
- **Phase 2:** custom UI in `frontend/` using **only Immich's REST API** (API key or user
  session), served same-origin with `/api` reverse-proxied to `immich-server:2283`.
  Planned: parallax horizontal timeline, Leaflet/Mapbox GPS map, masonry grid with hover
  zoom/captions, Ken Burns ambient slideshow, mobile browser upload.
- `scripts/memories.py` — nightly "on this day" feed via the API (stdlib only).
- Windows helpers are PowerShell (`scripts/*.ps1`), must work on Windows PowerShell 5.1.

## Hard rules
- Never read, write, move or rename anything inside `UPLOAD_LOCATION` directly. Immich owns it.
- Never commit `.env`, API keys, passwords, or any media/database data. Only `.env.example`
  (with placeholder values) is tracked.
- Never suggest `docker compose down -v` (it deletes `pgdata`).
- Keep the service LAN-only; no router port-forwarding advice.

## Commits
After completing a task, make **clean, focused Conventional Commits**:
- `feat:` new functionality (scripts, frontend features, compose services)
- `fix:` bug fixes
- `docs:` documentation only
- `chore:` config, tooling, dependency/version bumps (e.g. `chore: bump Immich to v3.5.0`)
- Optional scope: `feat(frontend): ...`, `docs(setup): ...`

One logical change per commit; imperative, lower-case subject ≤ 72 chars. Before
committing, run `git status` / `git diff --cached` and confirm no `.env` or secrets
are staged.
