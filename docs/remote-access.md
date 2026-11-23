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

## Rules

- No router port-forwarding, and no Tailscale Funnel or other public exposure.
- To cut off a lost device, remove it in the Tailscale admin console.
- If the PC's Tailscale IP ever changes, update this page and the phone apps.
