# ============================================================
# install.ps1 — Phoenix Package Handler
# Works on a FRESH Windows 10 install (PS 5.1, nothing else)
# Installs: PS7, Git, Python3 — then clones and sets up Phoenix
#
# ONE-LINER TRIGGER (paste in any cmd or PS window):
#   powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/jwl247/Phoenix-Package_handler/main/install.ps1 | iex"
# ============================================================

$ErrorActionPreference = "Stop"

# ── Config ───────────────────────────────────────────────────
$WORKER_URL  = "https://pho-installer-worker.phoenix-jwl.workers.dev"
$REPO_URL    = "https://github.com/jwl247/Phoenix-Package_handler.git"
$INSTALL_DIR = "$env:USERPROFILE\Phoenix\package-handler"
$ENV_FILE    = "$env:USERPROFILE\.phoenix_env.ps1"
$TEMP_DIR    = "$env:TEMP\phoenix-install"

# Download URLs — pinned stable releases, no winget needed
$PS7_URL     = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi"
$GIT_URL     = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
$PYTHON_URL  = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"

$GIT_PATH    = "$env:ProgramFiles\Git\cmd\git.exe"
$PYTHON_PATH = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$PS7_PATH    = "$env:ProgramFiles\PowerShell\7\pwsh.exe"

# ── Helpers ──────────────────────────────────────────────────
function PHX-Banner {
    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor Cyan
    Write-Host "   Phoenix Package Handler Installer   " -ForegroundColor Cyan
    Write-Host "   UnitedSys / Phoenix DevOps OS       " -ForegroundColor Cyan
    Write-Host "  ======================================" -ForegroundColor Cyan
    Write-Host ""
}

function PHX-Info    { param($m) Write-Host "[PHX] $m" -ForegroundColor Cyan }
function PHX-OK      { param($m) Write-Host "[OK]  $m" -ForegroundColor Green }
function PHX-Warn    { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function PHX-Error   { param($m) Write-Host "[ERR] $m" -ForegroundColor Red; exit 1 }

function Download-File {
    param([string]$Url, [string]$Dest)
    PHX-Info "Downloading $(Split-Path $Dest -Leaf)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($Url, $Dest)
    if (-not (Test-Path $Dest)) { PHX-Error "Download failed: $Url" }
    PHX-OK "Downloaded."
}

New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null

PHX-Banner

# ── STAGE 1: If we're in PS 5.1, install PS7 and relaunch ────
if ($PSVersionTable.PSVersion.Major -lt 7) {
    PHX-Info "Running in PS $($PSVersionTable.PSVersion) — upgrading to PS7..."

    if (-not (Test-Path $PS7_PATH)) {
        $ps7Installer = "$TEMP_DIR\ps7.msi"
        Download-File $PS7_URL $ps7Installer
        PHX-Info "Installing PowerShell 7 (silent)..."
        Start-Process msiexec.exe -ArgumentList "/i `"$ps7Installer`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1" -Wait
        if (-not (Test-Path $PS7_PATH)) { PHX-Error "PS7 install failed." }
        PHX-OK "PowerShell 7 installed."
    } else {
        PHX-OK "PS7 already installed."
    }

    PHX-Info "Relaunching installer in PS7..."
    $scriptUrl = "https://raw.githubusercontent.com/jwl247/Phoenix-Package_handler/main/install.ps1"
    $localScript = "$TEMP_DIR\install.ps1"
    Download-File $scriptUrl $localScript
    & $PS7_PATH -ExecutionPolicy Bypass -File $localScript
    exit $LASTEXITCODE
}

# ── STAGE 2: Running in PS7 from here down ───────────────────
PHX-Info "Running in PS $($PSVersionTable.PSVersion) — good."

# ── Health check ─────────────────────────────────────────────
PHX-Info "Checking worker health..."
try {
    Invoke-RestMethod -Uri "$WORKER_URL/health" -TimeoutSec 10 | Out-Null
    PHX-OK "Worker is live."
} catch {
    PHX-Error "Worker unreachable. Check your internet connection."
}

# ── Install Git ───────────────────────────────────────────────
if (-not (Test-Path $GIT_PATH)) {
    PHX-Info "Git not found — installing..."
    $gitInstaller = "$TEMP_DIR\git.exe"
    Download-File $GIT_URL $gitInstaller
    Start-Process $gitInstaller -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait
    if (-not (Test-Path $GIT_PATH)) { PHX-Error "Git install failed." }
    PHX-OK "Git installed."
} else {
    PHX-OK "Git already installed."
}
$env:PATH = "$env:ProgramFiles\Git\cmd;$env:PATH"

# ── Install Python ────────────────────────────────────────────
if (-not (Test-Path $PYTHON_PATH)) {
    PHX-Info "Python not found — installing..."
    $pyInstaller = "$TEMP_DIR\python.exe"
    Download-File $PYTHON_URL $pyInstaller
    Start-Process $pyInstaller -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=0 Include_test=0" -Wait
    if (-not (Test-Path $PYTHON_PATH)) { PHX-Error "Python install failed." }
    PHX-OK "Python installed."
} else {
    PHX-OK "Python already installed."
}
$env:PATH = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:LOCALAPPDATA\Programs\Python\Python312\Scripts;$env:PATH"

# ── Persist to system PATH ────────────────────────────────────
PHX-Info "Updating system PATH..."
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$pathsToAdd = @(
    "$env:ProgramFiles\Git\cmd",
    "$env:ProgramFiles\PowerShell\7",
    "$env:LOCALAPPDATA\Programs\Python\Python312",
    "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts"
)
foreach ($p in $pathsToAdd) {
    if ($machinePath -notlike "*$p*") { $machinePath = "$machinePath;$p" }
}
[System.Environment]::SetEnvironmentVariable("Path", $machinePath, "Machine")
PHX-OK "System PATH updated."

# ── Clone repo ────────────────────────────────────────────────
PHX-Info "Installing to $INSTALL_DIR ..."
if (Test-Path "$INSTALL_DIR\.git") {
    PHX-Warn "Repo already exists — pulling latest..."
    & "$GIT_PATH" -C $INSTALL_DIR pull --ff-only
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $INSTALL_DIR) | Out-Null
    & "$GIT_PATH" clone $REPO_URL $INSTALL_DIR
}
if (-not (Test-Path "$INSTALL_DIR\.git")) { PHX-Error "Clone failed." }
PHX-OK "Repo cloned to $INSTALL_DIR"

# ── Directory structure ───────────────────────────────────────
PHX-Info "Creating directory structure..."
@("clonepool", "logs", "sidecars") | ForEach-Object {
    New-Item -ItemType Directory -Force -Path "$INSTALL_DIR\$_" | Out-Null
}
PHX-OK "Directories ready."

# ── PHOENIX_AUTH ──────────────────────────────────────────────
if (Test-Path $ENV_FILE) {
    . $ENV_FILE
    PHX-Info "Loaded existing config from $ENV_FILE"
}

if (-not $env:PHOENIX_AUTH) {
    Write-Host ""
    Write-Host "  Enter your PHOENIX_AUTH token." -ForegroundColor Yellow
    Write-Host "  (Cloudflare -> pho-installer-worker -> Settings -> Variables)" -ForegroundColor DarkGray
    Write-Host ""
    $secureToken = Read-Host "  PHOENIX_AUTH" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    if (-not $plainToken) { PHX-Error "PHOENIX_AUTH cannot be empty." }
    $env:PHOENIX_AUTH = $plainToken
}

# ── Write env file ────────────────────────────────────────────
PHX-Info "Writing $ENV_FILE ..."
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
@"
# Phoenix Package Handler environment — generated $timestamp
`$env:PHOENIX_AUTH        = "$($env:PHOENIX_AUTH)"
`$env:PHOENIX_WORKER_URL  = "$WORKER_URL"
`$env:PHOENIX_INSTALL_DIR = "$INSTALL_DIR"
"@ | Set-Content -Path $ENV_FILE -Encoding UTF8
icacls $ENV_FILE /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
PHX-OK "Env file written and secured."

# ── PS7 profile injection ─────────────────────────────────────
$ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType Directory -Force -Path (Split-Path $ps7Profile) | Out-Null
if (-not (Test-Path $ps7Profile)) { New-Item -ItemType File -Force -Path $ps7Profile | Out-Null }
$existing = Get-Content $ps7Profile -Raw -ErrorAction SilentlyContinue
if ($existing -notmatch "phoenix_env") {
    Add-Content -Path $ps7Profile -Value ""
    Add-Content -Path $ps7Profile -Value "# Phoenix Package Handler"
    Add-Content -Path $ps7Profile -Value ". `"$ENV_FILE`""
    PHX-OK "Sourced into PS7 profile."
}

# ── System-wide intake shim ───────────────────────────────────
# Writes intake.cmd to System32 so `intake` works from cmd, PS, anywhere
$intakeShim = "$env:WINDIR\System32\intake.cmd"
if (Test-Path "$INSTALL_DIR\intake.sh") {
    PHX-Info "Creating system-wide intake command..."
@"
@echo off
bash "$INSTALL_DIR\intake.sh" %*
"@ | Set-Content -Path $intakeShim -Encoding ASCII
    PHX-OK "intake available system-wide (intake <file> from any terminal)."
} else {
    PHX-Warn "intake.sh not in repo yet — shim skipped."
}

# ── Register machine ──────────────────────────────────────────
PHX-Info "Registering this machine with D1..."
$regBody = @{
    hostname     = $env:COMPUTERNAME
    os           = "Windows"
    version      = (Get-CimInstance Win32_OperatingSystem).Caption
    installed_by = "install.ps1"
    install_dir  = $INSTALL_DIR
} | ConvertTo-Json

try {
    $reg = Invoke-WebRequest `
        -Uri "$WORKER_URL/installed/register" `
        -Method POST `
        -Headers @{ "X-Phoenix-Auth" = $env:PHOENIX_AUTH; "Content-Type" = "application/json" } `
        -Body $regBody -UseBasicParsing -TimeoutSec 15
    if ($reg.StatusCode -in @(200,201)) { PHX-OK "Machine registered." }
    else { PHX-Warn "Registration HTTP $($reg.StatusCode)." }
} catch {
    PHX-Warn "Registration failed: $_ — continuing."
}

# ── Fetch glossary ────────────────────────────────────────────
PHX-Info "Fetching package glossary..."
try {
    $g = Invoke-RestMethod -Uri "$WORKER_URL/glossary" `
        -Headers @{ "X-Phoenix-Auth" = $env:PHOENIX_AUTH } -TimeoutSec 10
    $pkgs = if ($g.results) { $g.results } elseif ($g.glossary) { $g.glossary } else { @() }
    PHX-OK "Glossary loaded — $($pkgs.Count) packages available."
} catch {
    PHX-Warn "Could not fetch glossary: $_"
}

# ── Cleanup ───────────────────────────────────────────────────
Remove-Item -Recurse -Force $TEMP_DIR -ErrorAction SilentlyContinue

# ── Done ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ======================================" -ForegroundColor Green
Write-Host "   Phoenix installed successfully.      " -ForegroundColor Green
Write-Host "  ======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Open a NEW terminal, then:" -ForegroundColor Yellow
Write-Host "    pwsh                  <- PS7" -ForegroundColor Cyan
Write-Host "    intake <file>         <- run intake from anywhere" -ForegroundColor Cyan
Write-Host ""
