# Remote access — Tailscale

Immich is reachable away from home over **Tailscale**, a private WireGuard mesh VPN.
Only devices signed in to the family tailnet can connect. Immich is **not exposed to
the public internet**: no router port-forwarding, no Tailscale Funnel.

| | Address |
|---|---|
| At home (LAN) | `http://<PC-LAN-IP>:2283` (printed by `setup-windows.ps1`) |
| Anywhere (Tailscale) | `http://100.110.169.89:2283` |
| On the PC itself | <http://localhost:2283> |

The PC still has to be on. Uploads wait on the phone until it's reachable.

## Tailnet devices

| Device | OS | Tailscale IP | Role |
|---|---|---|---|
| `desktop-q31j5nm` | Windows 11 | `100.110.169.89` | Immich host (unattended service) |
| `dido-s-pc` | Linux | `100.70.18.86` | Client: browser access and repo work |

Phones join the same tailnet with the Tailscale app. Check who is connected with
`tailscale status`.

## How it works on the PC

- Tailscale is installed for all users and runs as a Windows service in
  `--unattended` mode, so it connects at boot without anyone signed in.
- Windows treats the `Tailscale` adapter as a **Private** network, so the existing
  `Immich (2283)` firewall rule (inbound, Private profile only) covers it. No extra
  rule is needed.
- Check the status from PowerShell:

  ```powershell
  & "C:\Program Files\Tailscale\tailscale.exe" status
  & "C:\Program Files\Tailscale\tailscale.exe" ip -4
  ```

To reinstall:

```powershell
winget install --id Tailscale.Tailscale --exact --silent --scope machine `
  --accept-package-agreements --accept-source-agreements
& "C:\Program Files\Tailscale\tailscale.exe" up --auth-key=<one-time key> --unattended
```

Create auth keys at **login.tailscale.com → Settings → Keys**. Prefer one-time keys,
revoke them after use, and never commit them or paste them into docs.

## Phones and other devices

1. Install the **Tailscale** app and sign in to the same tailnet.
2. In the Immich app, go to **Settings → Networking** and turn on
   **Automatic URL switching**:
   - Local Wi-Fi network: your home Wi-Fi name, mapped to the LAN URL.
   - External URL: `http://100.110.169.89:2283`.
3. Open `http://100.110.169.89:2283` in the phone's browser to confirm it loads.

Keep backup set to **Wi-Fi only** unless mobile-data uploads are wanted.

## Linux client (`dido-s-pc`)

- Open `http://100.110.169.89:2283` in a browser while Tailscale is up.
- To check the connection: `tailscale ping 100.110.169.89` and
  `curl http://100.110.169.89:2283/api/server/ping`, which should return `{"res":"pong"}`.

## Claude Code workflow

- Claude Code (the CLI) runs on the Windows host in `C:\homelab-gallery`, where it can
  reach Docker, `.env` and `D:\`. It follows [CLAUDE.md](../CLAUDE.md).
- `/remote-control` in a running session lets you follow and steer it from another
  device. The work still runs on the host.
- Changes reach GitHub only through reviewed commits. Pull them on other machines with
  `git pull`.

## Rules

- No router port-forwarding, and no Tailscale Funnel or other public exposure.
- Never commit auth keys, or paste them into docs or chat. Rotate any key that was.
- To cut off a lost device, remove it in the Tailscale admin console.
- If the PC's Tailscale IP ever changes, update this page and the phone apps.
