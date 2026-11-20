# Mobile setup — Dad's phone

Goal: photos and videos upload automatically over home Wi-Fi whenever the PC is
on. If the PC is off, they wait on the phone and go up next time.

## 1. Install & sign in

1. Install **Immich** from the Play Store / App Store.
2. Server URL: `http://<PC-IP>:2283` — the LAN address printed by
   `setup-windows.ps1` (e.g. `http://192.168.1.50:2283`).
   *Tip:* open that URL in the phone's browser first to confirm it loads.
3. Sign in with **Dad's** Immich account (not the admin one).

## 2. Turn on backup

1. Tap the cloud icon (top right) → **Backup**.
2. **Select albums** → choose *Camera* / *Recents* (add WhatsApp etc. if wanted).
3. Turn on **Background backup**.
4. Keep uploads **Wi-Fi only** so mobile data isn't used.

### Android
- Settings → Apps → Immich → Battery → **Unrestricted** (no battery optimisation),
  otherwise Android may kill background uploads.
- Grant **All photos & videos** media access.

### iPhone
- Photos permission → **Full Access** (not "Limited").
- Settings → General → **Background App Refresh** → on for Immich.
- iOS decides when background tasks run; opening the Immich app now and then on
  home Wi-Fi speeds things up.

## 3. One-way backup — how deleting works

- Deleting in the phone's normal **Gallery / Photos** app → stays in Immich. ✅
- Deleting **inside the Immich app** can remove it from the phone *and* the server.
  Rule for Dad: **delete in the normal gallery app, browse in Immich.**
- Leave any "sync deletions" / "free up space" options **off** unless you know
  exactly what they do.

## 4. Check it's working

- The app's Backup screen shows *Backed up / Remainder* counts.
- On the PC, <http://localhost:2283> → log in as Dad → new photos are in the timeline.
