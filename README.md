# homelab-gallery

Self-hosted family photo & video gallery on a Windows PC at home, built on
[Immich](https://immich.app). Each family member has their own Immich account, and
their phone backs up automatically whenever the PC is on. When it's off, uploads wait
on the phone. A shared **Family Archive** album holds the family's photos for everyone.

- **Phase 1 (now):** official Immich (v3.4.2) via Docker Compose — web UI + mobile app.
- **Phase 2 (later):** custom frontend on Immich's REST API — cinematic timeline,
  GPS map, masonry grid, ambient slideshow, browser upload.

## Status

- ✅ Immich v3.4.2 is running on Docker Desktop (WSL 2) and starts with Windows.
- ✅ Media moved from the old `D:\Gallery` to `D:\homelab\gallery`, verified file by file.
- ✅ Each family account has a storage label, so files are filed under
  `library/<Name>/YYYY/MM/DD/` (storage template migration done).
- ✅ The old photos from USB drives and zips on `D:\` are imported into the right
  person's accounts, checked against Immich by SHA-1 checksum, and added to the
  shared **Family Archive** album (about 14,000 assets). Duplicates were skipped.
- ✅ Remote access through Tailscale (see below).
- ⏳ Not imported yet: screen recordings, game clips and a few unsorted folders.
  The original USB folders on `D:\` are kept until they're confirmed safe to remove.

## Quick start (Windows PC)

```powershell
git clone https://github.com/Dido-G/homelab-gallery.git C:\homelab-gallery
cd C:\homelab-gallery
# elevated PowerShell, Docker Desktop running:
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

Then open <http://localhost:2283>. Full walkthrough: [docs/setup-guide.md](docs/setup-guide.md).

## Access

| From | URL |
|---|---|
| The PC itself | <http://localhost:2283> |
| Home Wi-Fi / LAN | `http://<PC-LAN-IP>:2283` |
| Anywhere, via Tailscale | `http://100.110.169.89:2283` |

Remote access uses [Tailscale](https://tailscale.com). Only devices signed in to the
family tailnet can reach Immich, and nothing is exposed to the public internet: no
router port-forwarding, no Funnel. Setup and phone settings (automatic URL switching):
[docs/remote-access.md](docs/remote-access.md).

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
  mobile-setup.md         Immich app on the family's phones
  remote-access.md        Tailscale access away from home
  architecture.md         How it fits together, design decisions, Phase 2 plan
frontend/                 Phase 2 placeholder
```

## Storage

| Data | Where | Notes |
|---|---|---|
| Photos/videos | `D:\homelab\gallery` (bind mount) | Owned by Immich — don't edit by hand. **Back it up elsewhere.** |
| Postgres | Docker named volume `pgdata` | Not on NTFS, on purpose. Nightly dumps land in `D:\homelab\gallery\backups`. |
| ML models | Docker volume `model-cache` | Re-downloadable. |
