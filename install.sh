#!/usr/bin/env bash
# ============================================================
# install.sh — Phoenix Package Handler
# UnitedSys — United Systems | jwl247
# License: GPL-3.0
#
# Usage:
#   bash install.sh
#   curl -fsSL https://raw.githubusercontent.com/jwl247/Phoenix-Package_handler/main/install.sh | bash
# ============================================================

set -euo pipefail

REPO_URL="https://github.com/jwl247/Phoenix-Package_handler.git"
INSTALL_DIR="${HOME}/Phoenix/package-handler"
CLONEPOOL_DIR="${HOME}/Phoenix/clonepool"
WORKER_URL="https://packages-worker.phoenix-jwl.workers.dev"
ENV_FILE="${HOME}/.phoenix_env"

G="\033[0;32m"; Y="\033[0;33m"; R="\033[0;31m"; N="\033[0m"
ok()   { echo -e "${G}[OK]${N}     $1"; }
log()  { echo -e "${Y}[PHOENIX]${N} $1"; }
err()  { echo -e "${R}[ERROR]${N}  $1"; exit 1; }
warn() { echo -e "${Y}[WARN]${N}   $1"; }

echo ""
echo -e "${Y}================================${N}"
echo -e "${Y}  PHOENIX PACKAGE HANDLER${N}"
echo -e "${Y}  UnitedSys — United Systems${N}"
echo -e "${Y}================================${N}"
echo ""

# ── Detect platform ───────────────────────────────────────────
detect_platform() {
  # WINDIR is always set on Windows regardless of shell
  if [[ -n "${WINDIR:-}" ]] || [[ -n "${windir:-}" ]]; then
    echo "windows"
    return
  fi
  case "$(uname -s)" in
    Linux*)            echo "linux" ;;
    Darwin*)           echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)                 echo "linux" ;;
  esac
}

# ── Check dependencies ────────────────────────────────────────
log "Checking dependencies..."
for dep in git curl; do
  if ! command -v "${dep}" &>/dev/null; then
    if [[ "${PLATFORM}" == "linux" ]]; then
      warn "${dep} not found — attempting install..."
      sudo apt-get install -y "${dep}" &>/dev/null \
        || sudo yum install -y "${dep}" &>/dev/null \
        || sudo dnf install -y "${dep}" &>/dev/null \
        || err "${dep} could not be installed. Please install it manually and re-run."
    else
      err "${dep} is required but not found. Please install it and re-run."
    fi
  fi
done
ok "Dependencies ready"

# ── Clone or update repo ──────────────────────────────────────
log "Fetching Phoenix Package Handler..."
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  git -C "${INSTALL_DIR}" pull --ff-only 2>/dev/null \
    || warn "Could not pull latest — using existing install"
  ok "Repo updated"
else
  mkdir -p "${INSTALL_DIR}"
  git clone "${REPO_URL}" "${INSTALL_DIR}" 2>/dev/null \
    || err "Could not clone repo. Check your internet connection."
  ok "Repo cloned"
fi

# ── Directory structure ───────────────────────────────────────
mkdir -p "${CLONEPOOL_DIR}" "${HOME}/.unitedsys/logs" "${HOME}/.catalog"
ok "Directories ready"

# ── Find best Python (cross-platform, no hardcoded paths) ─────
find_python() {
  for cmd in python3 python python3.13 python3.12 python3.11 python3.10; do
    if command -v "${cmd}" &>/dev/null; then
      echo "${cmd}"
      return 0
    fi
  done
  # Windows Git Bash: search common install locations dynamically
  if [[ "${PLATFORM}" == "gitbash" ]]; then
    local win_user
    win_user=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r' || true)
    for pydir in \
      "${win_user}/AppData/Local/Programs/Python/Python313" \
      "${win_user}/AppData/Local/Programs/Python/Python312" \
      "${win_user}/AppData/Local/Programs/Python/Python311" \
      "/c/Python313" "/c/Python312" "/c/Python311"; do
      if [[ -x "${pydir}/python.exe" ]]; then
        echo "${pydir}/python.exe"
        return 0
      fi
    done
  fi
  echo ""
}

PYTHON_CMD=$(find_python)
if [[ -n "${PYTHON_CMD}" ]]; then
  ok "Python found: ${PYTHON_CMD}"
else
  warn "Python not found — sidecar enrichment will be skipped (non-critical)"
fi

# ── Write environment file ────────────────────────────────────
log "Writing environment config..."
{
  echo "# Phoenix DevOps OS — Environment"
  echo "# Generated $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "export PHOENIX_WORKER_URL=\"${WORKER_URL}\""
  echo "export CLONEPOOL_DIR=\"${CLONEPOOL_DIR}\""
  echo "export PHOENIX_INSTALL_DIR=\"${INSTALL_DIR}\""
  [[ -n "${PYTHON_CMD}" ]] && echo "export PHOENIX_PYTHON=\"${PYTHON_CMD}\""
  echo "export PHOENIX_AUTH=\"${PHOENIX_AUTH:-}\""
} > "${ENV_FILE}"

# Source into .bashrc
if [[ -f "${HOME}/.bashrc" ]]; then
  grep -q "phoenix_env" "${HOME}/.bashrc" 2>/dev/null \
    || echo '[[ -f ~/.phoenix_env ]] && source ~/.phoenix_env' >> "${HOME}/.bashrc"
fi

# Source into .zshrc (macOS default shell)
if [[ -f "${HOME}/.zshrc" ]] || [[ "${PLATFORM}" == "macos" ]]; then
  grep -q "phoenix_env" "${HOME}/.zshrc" 2>/dev/null \
    || echo '[[ -f ~/.phoenix_env ]] && source ~/.phoenix_env' >> "${HOME}/.zshrc" 2>/dev/null || true
fi

# Source into .bash_profile (macOS bash / Git Bash)
if [[ -f "${HOME}/.bash_profile" ]]; then
  grep -q "phoenix_env" "${HOME}/.bash_profile" 2>/dev/null \
    || echo '[[ -f ~/.phoenix_env ]] && source ~/.phoenix_env' >> "${HOME}/.bash_profile"
fi

ok "Environment configured"

# ── Install global intake command ─────────────────────────────
log "Installing global 'intake' command..."
chmod +x "${INSTALL_DIR}/intake.sh"

INTAKE_INSTALLED=false

# Attempt 1: /usr/local/bin (Linux/macOS — needs sudo)
if [[ "${PLATFORM}" != "gitbash" ]]; then
  if sudo ln -sf "${INSTALL_DIR}/intake.sh" /usr/local/bin/intake 2>/dev/null; then
    ok "intake installed → /usr/local/bin/intake"
    INTAKE_INSTALLED=true
  fi
fi

# Attempt 2: ~/.local/bin — ensure it's on PATH before using it
if [[ "${INTAKE_INSTALLED}" == "false" ]]; then
  LOCAL_BIN="${HOME}/.local/bin"
  mkdir -p "${LOCAL_BIN}"
  ln -sf "${INSTALL_DIR}/intake.sh" "${LOCAL_BIN}/intake" 2>/dev/null && INTAKE_INSTALLED=true

  # Make sure ~/.local/bin is on PATH in env file and shell configs
  if [[ "${INTAKE_INSTALLED}" == "true" ]]; then
    # Add to PATH in env file if not already there
    grep -q "local/bin" "${ENV_FILE}" 2>/dev/null \
      || echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${ENV_FILE}"

    # Add to shell configs
    for rc in "${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.zshrc"; do
      [[ -f "${rc}" ]] || continue
      grep -q '\.local/bin' "${rc}" 2>/dev/null \
        || echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${rc}"
    done

    ok "intake installed → ${LOCAL_BIN}/intake"
  fi
fi

# Attempt 3: ~/bin (Git Bash fallback)
if [[ "${INTAKE_INSTALLED}" == "false" ]]; then
  mkdir -p "${HOME}/bin"
  ln -sf "${INSTALL_DIR}/intake.sh" "${HOME}/bin/intake" 2>/dev/null && INTAKE_INSTALLED=true

  if [[ "${INTAKE_INSTALLED}" == "true" ]]; then
    grep -q '"${HOME}/bin"' "${ENV_FILE}" 2>/dev/null \
      || echo 'export PATH="${HOME}/bin:${PATH}"' >> "${ENV_FILE}"
    ok "intake installed → ${HOME}/bin/intake"
  fi
fi

if [[ "${INTAKE_INSTALLED}" == "false" ]]; then
  warn "Could not install intake to any PATH location."
  warn "Add this manually to your shell config:"
  warn "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
fi

# ── Verify the install actually works ─────────────────────────
log "Verifying install..."
source "${ENV_FILE}" 2>/dev/null || true

if command -v intake &>/dev/null; then
  ok "Verified: 'intake' command is globally available"
else
  warn "'intake' is not on PATH yet in this session."
  warn "Run: source ~/.phoenix_env"
  warn "Then open a new terminal — it will work from there."
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${G}================================${N}"
echo -e "${G}  PHOENIX IS ACTIVE${N}"
echo -e "${G}================================${N}"
echo ""
echo "  Platform : ${PLATFORM}"
echo "  Install  : ${INSTALL_DIR}"
echo "  Pool     : ${CLONEPOOL_DIR}"
[[ -n "${PYTHON_CMD}" ]] && echo "  Python   : ${PYTHON_CMD}"
echo ""
echo "  To activate in this session:"
echo -e "    ${Y}source ~/.phoenix_env${N}"
echo ""
echo "  Then use:"
echo -e "    ${Y}intake ./yourfile.sh${N}"
echo -e "    ${Y}intake myfile.py.lol${N}"
echo -e "    ${Y}intake status${N}"
echo ""
