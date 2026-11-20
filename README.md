# homelab-gallery

Self-hosted family photo & video gallery on a Windows PC at home, built on
[Immich](https://immich.app). Dad's phone backs up automatically over home Wi-Fi
whenever the PC is on; when it's off, uploads wait on the phone.

- **Phase 1 (now):** official Immich (v3.4.2) via Docker Compose — web UI + mobile app.
- **Phase 2 (later):** custom frontend on Immich's REST API — cinematic timeline,
  GPS map, masonry grid, ambient slideshow, browser upload.

## Quick start (Windows PC)

```powershell
git clone https://github.com/Dido-G/homelab-gallery.git C:\homelab-gallery
cd C:\homelab-gallery
# elevated PowerShell, Docker Desktop running:
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

Then open <http://localhost:2283>. Full walkthrough: [docs/setup-guide.md](docs/setup-guide.md).

## Layout

```
docker-compose.yml        Immich stack (official file + Windows tweaks, see header)
.env.example              Copy to .env — media path, TZ, version, DB password
scripts/
  setup-windows.ps1       One-time setup: folder, .env, firewall, compose up
  update.ps1              Bump pinned IMMICH_VERSION and redeploy
  memories.py             "On this day" feed via the Immich API (stdlib only)
docs/
  setup-guide.md          Windows PC install & operations
  mobile-setup.md         Immich app on Dad's phone
  architecture.md         How it fits together, design decisions, Phase 2 plan
frontend/                 Phase 2 placeholder
```

## Storage

| Data | Where | Notes |
|---|---|---|
| Photos/videos | `D:\Gallery` (bind mount) | Owned by Immich — don't edit by hand. **Back it up elsewhere.** |
| Postgres | Docker named volume `pgdata` | Not on NTFS, on purpose. Nightly dumps land in `D:\Gallery\backups`. |
| ML models | Docker volume `model-cache` | Re-downloadable. |
