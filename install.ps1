#Requires -Version 5.1
# ============================================================
# Phoenix-Install.ps1 — Phoenix DevOps OS / UnitedSys
# Project:   Phoenix Package Handler
# Author:    jwl247 / Phoenix DevOps LLC
# License:   GPL-3.0
# Version:   1.0.0
# ============================================================
# PURPOSE:
#   Double-click installer for Windows.
#   Works on clean and fresh machines.
#   No manual setup. No terminal knowledge needed.
#   Just works.
#
# USAGE:
#   Right-click → Run with PowerShell
#   OR: powershell -ExecutionPolicy Bypass -File Phoenix-Install.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

# ── Config ────────────────────────────────────────────────────
$INSTALLER_URL  = "https://pho-installer-worker.phoenix-jwl.workers.dev"
$WORKER_URL     = "https://packages-worker.phoenix-jwl.workers.dev"
$REPO_URL       = "https://github.com/jwl247/Phoenix-Package_handler.git"
$INSTALL_DIR    = "$env:USERPROFILE\Phoenix\package-handler"
$CLONEPOOL_DIR  = "$env:USERPROFILE\Phoenix\clonepool"
$ENV_FILE       = "$env:USERPROFILE\.phoenix_env.ps1"
$LOG_FILE       = "$env:USERPROFILE\Phoenix\install-log.txt"

# ── Colors ────────────────────────────────────────────────────
function Write-Phoenix { param([string]$Msg, [string]$Color = 'Cyan')
    Write-Host "  [PHOENIX] $Msg" -ForegroundColor $Color
    Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] [PHOENIX] $Msg" -ErrorAction SilentlyContinue
}
function Write-Ok   { param([string]$Msg) Write-Host "  [OK]    $Msg" -ForegroundColor Green;  Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] [OK] $Msg" -ErrorAction SilentlyContinue }
function Write-Warn { param([string]$Msg) Write-Host "  [WARN]  $Msg" -ForegroundColor Yellow; Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] [WARN] $Msg" -ErrorAction SilentlyContinue }
function Write-Err  { param([string]$Msg) Write-Host "  [ERROR] $Msg" -ForegroundColor Red;    Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] [ERROR] $Msg" -ErrorAction SilentlyContinue; Read-Host "Press Enter to exit"; exit 1 }

# ── Header ────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor DarkYellow
Write-Host "   PHOENIX PACKAGE HANDLER — WINDOWS        " -ForegroundColor DarkYellow
Write-Host "   USys — United Systems | jwl247            " -ForegroundColor DarkYellow
Write-Host "   Version 1.0.0                             " -ForegroundColor DarkYellow
Write-Host "  ==========================================" -ForegroundColor DarkYellow
Write-Host ""

# ── Create dirs early so log works ───────────────────────────
New-Item -ItemType Directory -Path "$env:USERPROFILE\Phoenix" -Force | Out-Null

# ── Detect machine state ──────────────────────────────────────
$isFresh = -not (Test-Path "$INSTALL_DIR\.git")
if ($isFresh) {
    Write-Phoenix "Clean machine detected — running full install" Green
} else {
    Write-Phoenix "Existing install detected — updating" Cyan
}

# ── Health check ──────────────────────────────────────────────
Write-Phoenix "Connecting to Phoenix infrastructure..."
try {
    $health = Invoke-RestMethod -Uri "$INSTALLER_URL/health" -Method GET -TimeoutSec 10
    if ($health.ok) {
        Write-Ok "Connected — pho-installer-worker v$($health.version)"
    } else {
        Write-Err "Worker responded but health check failed"
    }
} catch {
    Write-Err "Cannot reach Phoenix worker. Check your internet connection and try again."
}

# ── Check / install Git ───────────────────────────────────────
Write-Phoenix "Checking dependencies..."
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitPath) {
    Write-Warn "Git not found — attempting install via winget..."
    try {
        winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        Write-Ok "Git installed"
    } catch {
        Write-Warn "winget install failed — downloading Git installer..."
        $gitInstaller = "$env:TEMP\git-installer.exe"
        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe" -OutFile $gitInstaller
        Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT /NORESTART" -Wait
        Write-Ok "Git installed"
    }
} else {
    Write-Ok "Git found — $($gitPath.Source)"
}

# ── Clone or update repo ──────────────────────────────────────
Write-Phoenix "Setting up Phoenix Package Handler..."
try {
    if ($isFresh) {
        New-Item -ItemType Directory -Path (Split-Path $INSTALL_DIR) -Force | Out-Null
        git clone $REPO_URL $INSTALL_DIR 2>&1 | Out-Null
        Write-Ok "Repo cloned to $INSTALL_DIR"
    } else {
        git -C $INSTALL_DIR pull --ff-only 2>&1 | Out-Null
        Write-Ok "Repo updated"
    }
} catch {
    Write-Err "Could not clone/update repo: $_"
}

# ── Directory structure ───────────────────────────────────────
Write-Phoenix "Creating directory structure..."
@(
    $CLONEPOOL_DIR,
    "$env:USERPROFILE\.catalog",
    "$env:USERPROFILE\.unitedsys\logs",
    "$env:USERPROFILE\Phoenix\sidecars"
) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
Write-Ok "Directories ready"

# ── Auth token ────────────────────────────────────────────────
Write-Host ""
Write-Phoenix "Phoenix Auth Token setup" White
Write-Host "  Your PHOENIX_AUTH token controls write access to the Phoenix databases." -ForegroundColor Gray
Write-Host "  Leave blank for read-only mode — you can add it later." -ForegroundColor Gray
Write-Host ""

# Check if already have a token saved
$existingAuth = ""
if (Test-Path $ENV_FILE) {
    $existingAuth = (Get-Content $ENV_FILE | Where-Object { $_ -match 'PHOENIX_AUTH' } | Select-Object -First 1) -replace '.*=\s*"?([^"]*)"?.*', '$1'
}

if ($existingAuth -and $existingAuth -ne "") {
    Write-Ok "Existing auth token found"
    $useExisting = Read-Host "  Use existing token? (Y/n)"
    if ($useExisting -eq 'n') {
        $USER_AUTH = Read-Host "  Enter new PHOENIX_AUTH token"
    } else {
        $USER_AUTH = $existingAuth
    }
} else {
    $USER_AUTH = Read-Host "  Enter PHOENIX_AUTH token (or press Enter to skip)"
}
Write-Host ""

# ── Write env file ────────────────────────────────────────────
Write-Phoenix "Writing environment config..."
@"
# Phoenix DevOps OS — Environment
# Generated by Phoenix-Install.ps1 $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
`$env:PHOENIX_WORKER_URL    = "$WORKER_URL"
`$env:PHOENIX_INSTALLER_URL = "$INSTALLER_URL"
`$env:CLONEPOOL_DIR         = "$CLONEPOOL_DIR"
`$env:PHOENIX_AUTH          = "$USER_AUTH"
`$env:PHOENIX_INSTALL_DIR   = "$INSTALL_DIR"
"@ | Set-Content -Path $ENV_FILE -Encoding UTF8
Write-Ok "Env written to $ENV_FILE"

# ── Add to PowerShell profile ─────────────────────────────────
Write-Phoenix "Adding Phoenix to PowerShell profile..."
$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

if (-not (Select-String -Path $PROFILE -Pattern "phoenix_env" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $PROFILE -Value ""
    Add-Content -Path $PROFILE -Value "# Phoenix DevOps OS"
    Add-Content -Path $PROFILE -Value "if (Test-Path `"$ENV_FILE`") { . `"$ENV_FILE`" }"
    Write-Ok "Added to PowerShell profile"
} else {
    Write-Ok "Already in PowerShell profile"
}

# Source it now for this session
. $ENV_FILE

# ── Register machine with Phoenix ─────────────────────────────
Write-Phoenix "Registering machine with Phoenix..."
try {
    $regBody = @{
        package_name = "phoenix-package-handler"
        version      = "1.0.0"
        host         = $env:COMPUTERNAME
        state        = "active"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "$INSTALLER_URL/installed/register" `
        -Method POST `
        -Body $regBody `
        -ContentType "application/json" `
        -TimeoutSec 10 | Out-Null

    Write-Ok "$env:COMPUTERNAME registered in D1"
} catch {
    Write-Warn "Registration failed — worker may be busy. You can re-run to retry."
}

# ── Load glossary / package list ──────────────────────────────
Write-Phoenix "Loading package catalog..."
try {
    $catalog = Invoke-RestMethod -Uri "$INSTALLER_URL/glossary" -Method GET -TimeoutSec 10
    $count = if ($catalog.results) { $catalog.results.Count } else { 0 }
    Write-Ok "$count packages available in catalog"
} catch {
    Write-Warn "Could not load catalog — continuing"
    $count = 0
}

# ── Self-intake — register this install ───────────────────────
if ($USER_AUTH -and $USER_AUTH -ne "") {
    Write-Phoenix "Intaking Phoenix Package Handler into catalog..."
    try {
        $intakeBody = @{
            hex         = "70686f656e69782d7061636b6167652d68616e646c6572"
            name        = "phoenix-package-handler"
            description = "Universal file intake authority for Phoenix DevOps OS. Every asset cataloged."
            version     = "v1.0.0"
            state       = "white"
            category_hex= "73637269707473"
            platform    = $env:OS
            backend     = "phoenix-installer"
            pool_path   = $INSTALL_DIR
        } | ConvertTo-Json

        $intakeResult = Invoke-RestMethod -Uri "$INSTALLER_URL/intake" `
            -Method POST `
            -Body $intakeBody `
            -ContentType "application/json" `
            -Headers @{ "X-Phoenix-Auth" = $USER_AUTH } `
            -TimeoutSec 10

        if ($intakeResult.ok) {
            Write-Ok "Intake complete — catalog: $($intakeResult.catalog) | devdb: $($intakeResult.devdb)"
        } else {
            Write-Warn "Intake returned errors: $($intakeResult.errors -join ', ')"
        }
    } catch {
        Write-Warn "Intake failed — you can run 'intake' manually after setup"
    }
} else {
    Write-Warn "No auth token — skipping intake (read-only mode)"
}

# ── Create intake shortcut on Desktop ─────────────────────────
Write-Phoenix "Creating desktop shortcut..."
try {
    $shortcutPath = "$env:USERPROFILE\Desktop\Phoenix Intake.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $sc  = $wsh.CreateShortcut($shortcutPath)
    $sc.TargetPath       = "powershell.exe"
    $sc.Arguments        = "-ExecutionPolicy Bypass -NoExit -Command `". '$ENV_FILE'; Write-Host 'Phoenix ready. Use: intake <file>' -ForegroundColor Green`""
    $sc.WorkingDirectory = $INSTALL_DIR
    $sc.IconLocation     = "powershell.exe"
    $sc.Description      = "Phoenix DevOps OS — Intake Terminal"
    $sc.Save()
    Write-Ok "Desktop shortcut created — Phoenix Intake"
} catch {
    Write-Warn "Could not create shortcut — not critical"
}

# ── Done ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor DarkYellow
Write-Host "   PHOENIX IS ACTIVE" -ForegroundColor Green
Write-Host "   Machine : $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "   Install : $INSTALL_DIR" -ForegroundColor Green
Write-Host "   Pool    : $CLONEPOOL_DIR" -ForegroundColor Green
Write-Host "   Catalog : $count packages" -ForegroundColor Green
Write-Host "   Log     : $LOG_FILE" -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  Restart PowerShell or run:" -ForegroundColor Gray
Write-Host "    . `"$ENV_FILE`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Then use intake:" -ForegroundColor Gray
Write-Host "    intake .\myfile.ps1" -ForegroundColor Cyan
Write-Host "    intake status" -ForegroundColor Cyan
Write-Host ""

Read-Host "  Press Enter to close"
