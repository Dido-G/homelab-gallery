# Setup guide — Windows gallery PC

Target: Windows 10 22H2+ / Windows 11, Docker Desktop on WSL 2, media on `D:\homelab\gallery`.
Estimated time: ~30–45 min, mostly downloads.

## 1. Prerequisites (one time)

1. **Enable WSL 2** — elevated PowerShell:
   ```powershell
   wsl --install
   ```
   Reboot when asked. (`wsl --status` should show *Default Version: 2*.)
2. **Install Docker Desktop** — <https://docs.docker.com/desktop/setup/install/windows-install/>
   - Keep *Use WSL 2 instead of Hyper-V* checked.
   - Settings → General → enable **Start Docker Desktop when you sign in**.
     All Immich containers use `restart: always`, so they come up whenever Docker does.
3. **Install Git for Windows** — `winget install Git.Git`
4. *(Optional, for `scripts/memories.py`)* **Python 3** — `winget install Python.Python.3.12`

## 2. Get the repo

Clone it to a normal Windows path (PowerShell):

```powershell
cd C:\
git clone https://github.com/Dido-G/homelab-gallery.git
cd C:\homelab-gallery
```

> Prefer working inside WSL instead? Clone into `~/` in your WSL distro and set
> `UPLOAD_LOCATION=/mnt/d/homelab/gallery` in `.env`. Pick one side and always run
> `docker compose` from there, so the paths in `.env` match.

## 3. Run the setup script

Elevated PowerShell (needed only for the firewall rule):

```powershell
cd C:\homelab-gallery
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

It will:
- check Docker is running,
- create `D:\homelab\gallery`,
- create `.env` with a random `DB_PASSWORD` and your timezone,
- allow inbound TCP **2283** on *Private* networks,
- `docker compose pull` + `up -d`, and print the LAN URL.

Doing it by hand instead:
```powershell
Copy-Item .env.example .env     # then edit DB_PASSWORD and TZ
New-Item -ItemType Directory D:\homelab\gallery -Force
docker compose up -d
```

## 4. First login

1. Open <http://localhost:2283> and create the **admin** account (that's you).
2. Administration → Users → create an account for Dad. He backs up into his own account.
3. Account Settings → API Keys → create a key for automation; paste it into
   `.env` as `IMMICH_API_KEY` (used by `scripts/memories.py` / Phase 2 only).

Then follow [mobile-setup.md](mobile-setup.md) on Dad's phone.

## 5. Make the PC reachable & predictable

- **Network profile = Private**: Settings → Network & internet → your adapter → *Private*.
  On *Public* the firewall rule doesn't apply and the phone can't connect.
- **Stable IP**: create a DHCP reservation for this PC in your router, so the
  address the phone app uses never changes.
- **Sign-in**: Docker Desktop starts only after a Windows user signs in. If the PC
  is on but nobody has signed in since boot, Immich is not running.
- **Sleep**: uploads pause when the PC sleeps and resume next time it's on — nothing
  is lost. If big video uploads keep getting cut off, lengthen the sleep timeout.

## 6. Day-to-day

| Task | Command (repo folder) |
|---|---|
| Status | `docker compose ps` |
| Logs | `docker compose logs -f immich-server` |
| Stop | `docker compose stop` |
| Start | `docker compose up -d` |
| Update | `.\scripts\update.ps1 -Version vX.Y.Z` (read release notes first) |

## 7. Backups — read this

Phone → Immich is a **one-way backup**: once Dad deletes a photo from his phone,
`D:\homelab\gallery` may be the **only copy**. A single drive is not a backup.

- `D:\homelab\gallery` holds originals, thumbnails, and Immich's automatic nightly
  **database dumps** (`D:\homelab\gallery\backups`). Copy the whole folder somewhere else
  regularly (USB drive, NAS or cloud — e.g. a weekly `robocopy /MIR` job).
- The live database is in the Docker volume `pgdata` (inside Docker Desktop's
  disk image on C:). As long as the dumps in `D:\homelab\gallery\backups` are kept, it can be
  restored: <https://docs.immich.app/administration/backup-and-restore>.
- **Never** run `docker compose down -v` — `-v` deletes `pgdata`.

## 8. Optional tuning

- **RAM**: machine learning can use a few GB. This PC caps WSL with
  `%UserProfile%\.wslconfig` (a hidden file):
  ```ini
  [wsl2]
  memory=6GB
  maxCrashDumpCount=-1
  ```
  then `wsl --shutdown` and restart Docker Desktop. During big imports, pausing
  Immich's metadata, thumbnail and ML queues (Administration → Jobs) keeps the hard
  drive free for uploads. Resume them afterwards.
- **GPU acceleration**: see the `extends:` comments in `docker-compose.yml`. On WSL use
  the `-wsl` variants (`vaapi-wsl`, `openvino-wsl`) or `nvenc`/`cuda` for NVIDIA. Requires
  downloading the `hwaccel.*.yml` files from the same Immich release into this folder.

## Troubleshooting

| Symptom | Check |
|---|---|
| Phone can't connect | Same Wi-Fi? Network profile Private? Does `http://<ip>:2283` load in the phone's browser? Away from home: is Tailscale on? See [remote-access.md](remote-access.md). |
| `immich_postgres` restarting | `docker compose logs database`. Make sure the DB is on `pgdata`, not a `D:\` path. |
| Empty `UPLOAD_LOCATION` error | `.env` missing, or not in the folder you ran `docker compose` from. |
| Wrong photo times | `TZ` in `.env`, then `docker compose up -d` to apply. |
