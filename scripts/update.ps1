<#
.SYNOPSIS
  Update Immich to a new pinned release.

.DESCRIPTION
  Immich ships breaking changes between releases - ALWAYS read the release notes
  first: https://github.com/immich-app/immich/releases

  Steps this script does NOT automate (on purpose):
    1. Diff upstream docker-compose.yml / example.env against ours and port changes
       (image digests for valkey/postgres change between releases).
  Steps it does:
    2. Set IMMICH_VERSION in .env
    3. docker compose pull && docker compose up -d

.EXAMPLE
  .\scripts\update.ps1 -Version v3.5.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$envFile = Join-Path $RepoRoot '.env'
if (-not (Test-Path $envFile)) { throw '.env not found - run scripts\setup-windows.ps1 first' }

Write-Host "Upstream files for comparison:" -ForegroundColor Cyan
Write-Host "  https://github.com/immich-app/immich/releases/download/$Version/docker-compose.yml"
Write-Host "  https://github.com/immich-app/immich/releases/download/$Version/example.env"
$answer = Read-Host "Have you read the $Version release notes and synced docker-compose.yml? [y/N]"
if ($answer -notmatch '^[yY]') { Write-Host 'Aborted.'; exit 1 }

$lines = (Get-Content $envFile) | ForEach-Object {
    if ($_ -match '^IMMICH_VERSION=') { "IMMICH_VERSION=$Version" } else { $_ }
}
[System.IO.File]::WriteAllText($envFile, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))

docker compose pull
if ($LASTEXITCODE -ne 0) { throw 'pull failed' }
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw 'up failed' }
docker compose ps
