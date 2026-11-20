<#
.SYNOPSIS
  One-time setup of the Immich stack on the Windows gallery PC.

.DESCRIPTION
  - Checks Docker Desktop is installed and running
  - Creates the media folder (default D:\homelab\gallery)
  - Creates .env from .env.example with a random DB password and your timezone
  - Adds a Windows Firewall rule for TCP 2283 on Private networks (needs admin)
  - Pulls images and starts the stack

  Safe to re-run: it never overwrites an existing .env or touches existing media.

.EXAMPLE
  # From the repo root, in an *elevated* PowerShell (for the firewall rule):
  powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
#>
[CmdletBinding()]
param(
    [string]$GalleryPath = 'D:\homelab\gallery',
    [switch]$SkipFirewall
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }

# --- 1. Docker -----------------------------------------------------------------
Write-Step 'Checking Docker Desktop'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'docker not found. Install Docker Desktop (WSL 2 backend) first: https://docs.docker.com/desktop/setup/install/windows-install/'
}
docker info --format '{{.ServerVersion}}' *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop is installed but not running. Start it, wait for "Engine running", then re-run.'
}
docker compose version

# --- 2. Media folder -----------------------------------------------------------
Write-Step "Ensuring media folder $GalleryPath"
if (-not (Test-Path $GalleryPath)) {
    New-Item -ItemType Directory -Path $GalleryPath | Out-Null
    Write-Host "  created $GalleryPath"
} else {
    Write-Host "  exists (left untouched)"
}

# --- 3. .env -------------------------------------------------------------------
Write-Step 'Preparing .env'
$envFile = Join-Path $RepoRoot '.env'
if (Test-Path $envFile) {
    Write-Host '  .env already exists - not overwriting'
} else {
    $chars = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 32
    $rng.GetBytes($bytes)
    $password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })

    # Windows timezone -> IANA. .NET 6+ (PowerShell 7) has a built-in converter;
    # Windows PowerShell 5.1 (.NET Framework) does not, so fall back to the ICU
    # library that ships with Windows 10 1903+ / Windows 11 (icu.dll).
    $tz = 'Etc/UTC'
    $winTz = (Get-TimeZone).Id
    $iana = $null
    if ([System.TimeZoneInfo].GetMethod('TryConvertWindowsIdToIanaId', [type[]]@([string], [string].MakeByRefType()))) {
        [void][System.TimeZoneInfo]::TryConvertWindowsIdToIanaId($winTz, [ref]$iana)
    } else {
        try {
            Add-Type -Namespace HomelabGallery -Name Icu -MemberDefinition @'
[DllImport("icu.dll", CharSet = CharSet.Unicode)]
public static extern int ucal_getTimeZoneIDForWindowsID(string winid, int len,
    [MarshalAs(UnmanagedType.LPStr)] string region, System.Text.StringBuilder id, int cap, ref int status);
'@
            $region = [System.Globalization.RegionInfo]::CurrentRegion.TwoLetterISORegionName
            $sb = New-Object System.Text.StringBuilder 128
            $status = 0
            $len = [HomelabGallery.Icu]::ucal_getTimeZoneIDForWindowsID($winTz, -1, $region, $sb, $sb.Capacity, [ref]$status)
            if ($status -le 0 -and $len -gt 0) { $iana = $sb.ToString() }
        } catch { }
    }
    if ($iana) { $tz = $iana }
    else { Write-Warn "Could not map Windows timezone '$winTz' to IANA; set TZ in .env manually (now $tz)" }

    $uploadPath = $GalleryPath -replace '\\', '/'
    $content = (Get-Content (Join-Path $RepoRoot '.env.example')) | ForEach-Object {
        switch -Regex ($_) {
            '^UPLOAD_LOCATION=' { "UPLOAD_LOCATION=$uploadPath"; break }
            '^DB_PASSWORD='     { "DB_PASSWORD=$password"; break }
            '^TZ='              { "TZ=$tz"; break }
            default             { $_ }
        }
    }
    # LF endings, UTF-8 without BOM (Windows PowerShell 5.1 adds a BOM otherwise)
    [System.IO.File]::WriteAllText($envFile, (($content -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  wrote .env (UPLOAD_LOCATION=$uploadPath, TZ=$tz, random DB_PASSWORD)"
}

# --- 4. Firewall ---------------------------------------------------------------
if (-not $SkipFirewall) {
    Write-Step 'Allowing TCP 2283 on Private networks (Windows Firewall)'
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warn 'Not elevated - skipping. Re-run as Administrator, or add the rule yourself.'
    } elseif (Get-NetFirewallRule -DisplayName 'Immich (2283)' -ErrorAction SilentlyContinue) {
        Write-Host '  rule already present'
    } else {
        New-NetFirewallRule -DisplayName 'Immich (2283)' -Direction Inbound -Protocol TCP `
            -LocalPort 2283 -Action Allow -Profile Private | Out-Null
        Write-Host '  rule added'
    }
    $profiles = Get-NetConnectionProfile | Where-Object NetworkCategory -ne 'Private'
    foreach ($p in $profiles) {
        Write-Warn "Network '$($p.Name)' is '$($p.NetworkCategory)', not Private - phones on it won't reach Immich."
        Write-Warn "  Fix: Settings > Network & internet > (your network) > Network profile type: Private"
    }
}

# --- 5. Start ------------------------------------------------------------------
Write-Step 'Pulling images (first run downloads several GB)'
docker compose pull
if ($LASTEXITCODE -ne 0) { throw 'docker compose pull failed' }

Write-Step 'Starting stack'
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }

docker compose ps

# Only adapters with a default gateway are on the real LAN; this skips
# host-only adapters (VirtualBox/VMware/Hyper-V/WSL) that would print bogus URLs.
$ips = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
    ForEach-Object { $_.IPv4Address.IPAddress } |
    Where-Object { $_ -and $_ -notlike '169.254.*' }

Write-Host ''
Write-Host 'Immich is starting (first boot can take a minute).' -ForegroundColor Green
Write-Host '  On this PC:   http://localhost:2283'
foreach ($ip in $ips) { Write-Host "  On the LAN:   http://${ip}:2283   <- use this in the phone app" }
Write-Host ''
Write-Host 'Next: open the web UI, create the admin account, then follow docs/mobile-setup.md'
