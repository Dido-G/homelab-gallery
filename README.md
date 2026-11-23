# homelab-gallery

Self-hosted family photo & video gallery on a Windows PC at home, built on
[Immich](https://immich.app). Each family member has their own Immich account, and
their phone backs up automatically whenever the PC is on. When it's off, uploads wait
on the phone. A shared **Family Archive** album brings everyone's photos together.
Away from home, the gallery is reached privately over [Tailscale](https://tailscale.com).

- **Phase 1 (now):** official Immich (v3.4.2) via Docker Compose — web UI + mobile app.
- **Phase 2 (later):** custom frontend on Immich's REST API — cinematic timeline,
  GPS map, masonry grid, ambient slideshow, browser upload.

## Infrastructure

| | |
|---|---|
| Host | Windows 11 PC `desktop-q31j5nm`, on demand (not 24/7) |
| Runtime | Docker Desktop on WSL 2. Starts at sign-in, containers use `restart: always` |
| WSL memory | Capped at **6 GB** in `%UserProfile%\.wslconfig` (`memory=6GB`, `maxCrashDumpCount=-1`) |
| Immich | v3.4.2 (pinned) on port **2283**: server, machine learning, Postgres, Redis |
| Media | `D:\homelab\gallery` (bind mount, owned by Immich) |
| Database | Docker named volume `pgdata`, with nightly dumps in `D:\homelab\gallery\backups` |

See [docs/setup-guide.md](docs/setup-guide.md) and [docs/architecture.md](docs/architecture.md).

## Media library

- **Accounts:** **Dido** (admin), **Kiko**, **Marti** and **Asya**. Each account has a
  storage label, so originals are filed as `library/<Name>/YYYY/MM/DD/`.
- **Deduplication:** Immich dedupes per account by **SHA-1** checksum. Re-uploading a
  file the account already has is skipped, so imports are safe to re-run.
- **Old media import:** photos and videos from the old USB folders and zips on `D:\`
  were uploaded into the owner's account through the official Immich CLI. The sources
  were mounted read-only, and every file was re-checked against Immich by SHA-1.
- **Family Archive:** a shared album owned by Dido, with Kiko, Marti and Asya as
  editors. It held **14,149 verified assets** when the import finished, and grows as
  family members add more.
- **Clean-up:** the temporary extraction folder `D:\homelab\import-staging` has been
  removed. The original USB folders and zips on `D:\` are kept for now.

## Access

| From | URL |
|---|---|
| The PC itself | <http://localhost:2283> |
| Home Wi-Fi / LAN | `http://<PC-LAN-IP>:2283` |
| Anywhere, via Tailscale | `http://100.110.169.89:2283` |

**Tailscale** is installed on the Windows host (`desktop-q31j5nm`, `100.110.169.89`,
unattended service) and on the Linux client (`dido-s-pc`, `100.70.18.86`). Any device
on the tailnet can open Immich. Port 2283 is allowed only on Windows *Private* networks
(the home LAN and the Tailscale adapter). Nothing is forwarded on the router, and
nothing is published with Tailscale Funnel, so Immich is **not reachable from the
public internet**. Details: [docs/remote-access.md](docs/remote-access.md).

## Mobile & remote workflow

- **Phones:** install the Immich app and sign in to the person's own account. To keep
  backups working away from home, install Tailscale too and turn on
  **Settings → Networking → Automatic URL switching** in the Immich app:
  - On home Wi-Fi: the LAN URL, `http://<PC-LAN-IP>:2283`.
  - Everywhere else: `http://100.110.169.89:2283` over Tailscale.

  See [docs/mobile-setup.md](docs/mobile-setup.md).
- **Claude Code:** maintenance runs through the Claude Code CLI on the Windows host,
  in `C:\homelab-gallery`, and follows [CLAUDE.md](CLAUDE.md). `/remote-control` lets a
  session be followed and steered from another device. Long jobs such as imports run
  one batch at a time in the foreground, in ~1 GB chunks.

## Security & operations

- `.env` holds the database password and the per-user `IMMICH_API_KEY*` values. It is
  git-ignored and must never be committed. Only `.env.example`, with placeholders, is
  tracked.
- Keep API keys and Tailscale auth keys out of git, docs, issues and chat logs. Any key
  that was pasted somewhere it shouldn't be should be **rotated**: in Immich, go to
  Account Settings → API Keys; in Tailscale, go to login.tailscale.com → Settings → Keys.
  Prefer one-time Tailscale auth keys.
- Never run `docker compose down -v`, because it deletes the database volume.
- A single drive is not a backup. Copy `D:\homelab\gallery` somewhere else regularly.

### Open maintenance tasks (local, not done yet)

- [ ] Delete the old pre-move copy `D:\Gallery`. It's verified and redundant, but has
      to be removed by hand.
- [ ] Rotate the Immich API key and the Tailscale auth key that were shared in chat.
- [ ] Decide on the held-back media: screen recordings, game clips, webcam and
      unsorted folders, and a set of large videos.
- [ ] After that, decide when the original USB folders and zips on `D:\` can be
      removed.

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
