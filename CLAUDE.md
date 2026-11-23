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

## Current deployment
- Host `desktop-q31j5nm` (Windows 11, Docker Desktop on WSL 2). WSL is capped at 6 GB in
  `%UserProfile%\.wslconfig`. Immich v3.4.2 runs on port 2283.
- Accounts: Dido (admin), Kiko, Marti and Asya. Each has a storage label, so files land
  in `library/<Name>/`. Per-user API keys are in `.env` as `IMMICH_API_KEY`
  (Dido), `IMMICH_API_KEY_KIKO`, `IMMICH_API_KEY_MARTI` and `IMMICH_API_KEY_ASYA`.
  Comments go on their own line, never after a value.
- Shared album **Family Archive** (owner Dido; the others are editors). An editor can
  only add assets they own, so use each owner's key to add their assets.
- Imports: use the official Immich CLI with sources mounted read-only. Run one batch at
  a time in the foreground, in ~1 GB chunks. Verify by SHA-1 against the owner's
  assets, and leave the original source folders on `D:\` untouched until the user
  says they can go.
- Tailscale on the host: `100.110.169.89`. Linux client `dido-s-pc`: `100.70.18.86`.

## Hard rules
- Never read, write, move or rename anything inside `UPLOAD_LOCATION` directly. Immich owns it.
- Never commit `.env`, API keys, passwords, or any media/database data. Only `.env.example`
  (with placeholder values) is tracked.
- Never suggest `docker compose down -v` (it deletes `pgdata`).
- Keep the service private: LAN plus Tailscale only (`http://100.110.169.89:2283`, see
  `docs/remote-access.md`). Never expose it to the public internet: no router
  port-forwarding advice, no Tailscale Funnel.
- Never commit API keys or Tailscale auth keys, and never print them in output or chat.
  If one is exposed, recommend rotating it.
- Never report a local task (for example deleting `D:\Gallery` or rotating a key) as
  done without checking it.

## Commits
After completing a task, make **clean, focused Conventional Commits**:
- `feat:` new functionality (scripts, frontend features, compose services)
- `fix:` bug fixes
- `docs:` documentation only
- `chore:` config, tooling, dependency/version bumps (e.g. `chore: bump Immich to v3.5.0`)
- Optional scope: `feat(frontend): ...`, `docs(setup): ...`

**Never add Claude attribution** to commits or PRs: no `Co-Authored-By: Claude`
trailer, no `Claude-Session:` line, and no "Generated with Claude Code" footer.

One logical change per commit; imperative, lower-case subject ≤ 72 chars. Before
committing, run `git status` / `git diff --cached` and confirm no `.env` or secrets
are staged.
