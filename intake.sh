#!/usr/bin/env bash
# ============================================================
# intake.sh — Phoenix DevOps / UnitedSys
# Author: jwl247 / Phoenix DevOps LLC
# License: GPL-3.0
# Version: 1.4.0
# ============================================================
# PIPELINE IN:
#   file → hex → sidecar → clonepool → custody → D1
# PIPELINE OUT:
#   name → hex → clonepool latest → working directory → custody → D1
# ============================================================

set -euo pipefail

VERSION="1.4.0"
SCRIPT_NAME="intake"
SCRIPT_HEX="737363726970747332f696e74616b65"

# ── Config ────────────────────────────────────────────────────
CLONEPOOL_DIR="${CLONEPOOL_DIR:-${HOME}/Phoenix/clonepool}"
CATALOG_DB="${HOME}/.catalog/catalog.db"
LOG_DIR="${HOME}/.unitedsys/logs"
LOG_FILE="${LOG_DIR}/intake.log"get latest file

WORKER_URL="${PHOENIX_WORKER_URL:-https://packages-worker.phoenix-jwl.workers.dev}"
PHOENIX_AUTH="${PHOENIX_AUTH:-}"

# ── Python detection ──────────────────────────────────────────
_find_python() {
  for cmd in python3 python python3.13 python3.12 python3.11 python3.10; do
    command -v "${cmd}" &>/dev/null && { echo "${cmd}"; return 0; }
  done
  if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
    local win_user
    win_user=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null \
      | tr -d '\r\n' | sed 's|\\|/|g' | sed 's|C:|/c|' || true)
    for pydir in \
      "${win_user}/AppData/Local/Programs/Python/Python313" \
      "${win_user}/AppData/Local/Programs/Python/Python312" \
      "${win_user}/AppData/Local/Programs/Python/Python311" \
      "/c/Python313" "/c/Python312" "/c/Python311"; do
      [[ -x "${pydir}/python.exe" ]] && { echo "${pydir}/python.exe"; return 0; }
    done
  fi
  echo ""
}
PYTHON_CMD="${PHOENIX_PYTHON:-$(_find_python)}"

# ── Bootstrap ─────────────────────────────────────────────────
mkdir -p "${LOG_DIR}" "${CLONEPOOL_DIR}" "$(dirname "${CATALOG_DB}")"

# ── Logging ───────────────────────────────────────────────────
log() {
  local level="$1"; shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [intake:${level}] $*" | tee -a "${LOG_FILE}"
}

# ── Hex helpers ───────────────────────────────────────────────
to_hex() { echo -n "$1" | xxd -p | tr -d '\n'; }

# ── File size ─────────────────────────────────────────────────
get_size() { wc -c < "${1}" 2>/dev/null | tr -d ' ' || echo "0"; }

# ── Filetype detection ────────────────────────────────────────
detect_filetype() {
  local ext="${1##*.}"
  case "${ext,,}" in
    sh|bash|zsh)   echo "script:shell" ;;
    py)            echo "script:python" ;;
    js|mjs|cjs)    echo "script:javascript" ;;
    ts)            echo "script:typescript" ;;
    json)          echo "config:json" ;;
    yaml|yml)      echo "config:yaml" ;;
    toml)          echo "config:toml" ;;
    env)           echo "config:env" ;;
    conf|cfg|ini)  echo "config:conf" ;;
    service)       echo "systemd:service" ;;
    timer)         echo "systemd:timer" ;;
    socket)        echo "systemd:socket" ;;
    sql)           echo "database:sql" ;;
    md|markdown)   echo "docs:markdown" ;;
    txt)           echo "docs:text" ;;
    xml)           echo "config:xml" ;;
    html|htm)      echo "web:html" ;;
    css)           echo "web:css" ;;
    c|h)           echo "source:c" ;;
    cpp|hpp)       echo "source:cpp" ;;
    rs)            echo "source:rust" ;;
    go)            echo "source:go" ;;
    ps1)           echo "script:powershell" ;;
    *)             echo "unknown:unknown" ;;
  esac
}

filetype_to_category() {
  case "${1}" in
    script:*)   echo "73637269707473" ;;
    config:*)   echo "6461746162617365" ;;
    systemd:*)  echo "73797374656d" ;;
    database:*) echo "6461746162617365" ;;
    docs:*)     echo "6d65646961" ;;
    web:*)      echo "776f726b657273" ;;
    source:c)   echo "737562737973" ;;
    binary:*)   echo "7061636b61676573" ;;
    *)          echo "756e6b6e6f776e" ;;
  esac
}

# ── Companion detection ───────────────────────────────────────
detect_companions() {
  local filepath="$1"
  local dir; dir=$(dirname "${filepath}")
  local name; name=$(basename "${filepath}"); name="${name%.*}"
  local companion_exts=("service" "timer" "socket" "conf" "env" "yaml" "yml" "toml" "json" "md")
  for ext in "${companion_exts[@]}"; do
    local candidate="${dir}/${name}.${ext}"
    if [[ -f "${candidate}" && "${candidate}" != "${filepath}" ]]; then
      echo "${candidate}"
      log "INFO" "companion found: ${candidate}"
    fi
  done
}

# ── Version helpers ───────────────────────────────────────────
get_next_version() {
  local dir="$1"
  [[ ! -d "${dir}" ]] && { echo "v1"; return; }
  local files; files=$(ls "${dir}"/v*_* 2>/dev/null || true)
  [[ -z "${files}" ]] && { echo "v1"; return; }
  local last_num
  last_num=$(echo "${files}" \
    | xargs -I{} basename {} \
    | grep -o 'v[0-9]*' | grep -o '[0-9]*' \
    | sort -n | tail -1 || echo "0")
  echo "v$((last_num + 1))"
}

# Get the latest versioned file for a given name in a pool dir
get_latest_file() {
  local pool_dir="$1"
  local name="$2"
  ls "${pool_dir}"/v*_"${name}" 2>/dev/null \
    | while read -r f; do
        num=$(basename "${f}" | grep -o 'v[0-9]*' | grep -o '[0-9]*')
        echo "${num} ${f}"
      done \
    | sort -n \
    | tail -1 \
    | cut -d' ' -f2-
}

# ── Write sidecar ─────────────────────────────────────────────
write_sidecar_basic() {
  local sidecar="$1" hex="$2" orig="$3" version="$4"
  local filetype="$5" category_hex="$6" size="$7"
  local backend="${8:-direct}" notes="${9:-}"
  local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "${sidecar}")"
  cat > "${sidecar}" <<SIDECAR
{
  "usys_intake": "1.4",
  "hex_name": "${hex}",
  "original_name": "${orig}",
  "state": "white",
  "version": "${version}",
  "filetype": "${filetype}",
  "category_hex": "${category_hex}",
  "size_bytes": ${size},
  "backend": "${backend}",
  "notes": "${notes}",
  "pool_path": "${CLONEPOOL_DIR}/${hex}",
  "companions": [],
  "qr": {
    "header": {"role": "state", "state": "white"},
    "footer": {"role": "location", "tier": 1}
  },
  "auto_hotswap": false,
  "registered_at": "${now}",
  "updated_at": "${now}",
  "clone_history": [{"version": "${version}", "at": "${now}"}]
}
SIDECAR
  log "INFO" "sidecar written: ${sidecar}"
}

enrich_sidecar_companions() {
  local sidecar="$1" companions_str="$2"
  [[ -z "${PYTHON_CMD}" ]] && return 0
  "${PYTHON_CMD}" - "${sidecar}" "${companions_str}" <<'PYEOF'
import json, sys, os
sidecar_path = sys.argv[1]
companions_str = sys.argv[2] if len(sys.argv) > 2 else ""
with open(sidecar_path) as f:
    d = json.load(f)
companions = []
if companions_str.strip():
    for line in companions_str.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        ext = line.rsplit('.', 1)[-1] if '.' in line else 'unknown'
        companions.append({
            'file': os.path.basename(line),
            'path': line,
            'type': ext,
            'editable': ext in ('service','timer','socket','conf','env','yaml','yml','toml','json')
        })
d['companions'] = companions
with open(sidecar_path, 'w') as f:
    json.dump(d, f, indent=2)
PYEOF
}

# ── Local custody log ─────────────────────────────────────────
custody_log_local() {
  local hex="$1" name="$2" action="$3" version="$4" \
        src="$5" dst="$6" state="$7" actor="$8"
  command -v sqlite3 &>/dev/null || return 0
  sqlite3 "${CATALOG_DB}" 2>/dev/null <<SQL
CREATE TABLE IF NOT EXISTS custody (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hex_id TEXT NOT NULL, name TEXT NOT NULL, action TEXT NOT NULL,
  version TEXT, source TEXT, destination TEXT,
  state TEXT DEFAULT 'white', actor TEXT DEFAULT 'usys',
  validated INTEGER DEFAULT 0,
  intaked_at TEXT DEFAULT (datetime('now'))
);
INSERT INTO custody (hex_id, name, action, version, source, destination, state, actor)
VALUES ('${hex}','${name}','${action}','${version}','${src}','${dst}','${state}','${actor}');
SQL
}

# ── D1 reporter ───────────────────────────────────────────────
post_to_d1() {
  local endpoint="$1" payload="$2"
  [[ -z "${PHOENIX_AUTH}" ]] && { log "WARN" "PHOENIX_AUTH not set — skipping D1 report"; return 0; }
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${PHOENIX_AUTH}" \
    -d "${payload}" \
    "${WORKER_URL}${endpoint}" 2>/dev/null)
  http_code=$(echo "${response}" | tail -1)
  body=$(echo "${response}" | head -1)
  [[ "${http_code}" == "200" ]] \
    && log "INFO" "D1 OK → ${endpoint}" \
    || log "WARN" "D1 failed (${http_code}) → ${endpoint}: ${body}"
}

report_clonepool() {
  post_to_d1 "/clonepool" \
    "{\"hex_id\":\"${1}\",\"b58\":\"${1}\",\"name\":\"${2}\",\"version\":\"${3}\",\"state\":\"${4}\",\"pool_path\":\"${5}\",\"sidecar_path\":\"${6}\",\"tier\":${7},\"size\":${8}}"
}
report_custody() {
  post_to_d1 "/custody" \
    "{\"hex_id\":\"${1}\",\"name\":\"${2}\",\"action\":\"${3}\",\"state\":\"${4}\",\"actor\":\"${5}\"}"
}
report_glossary() {
  post_to_d1 "/glossary" \
    "{\"hex\":\"${1}\",\"name\":\"${2}\",\"description\":\"${3}\",\"category_hex\":\"${4}\",\"version\":\"${5}\",\"size\":${6},\"pool_path\":\"${7}\",\"state\":\"white\"}"
}

# ── Self registration ─────────────────────────────────────────
self_register() {
  local dir="${CLONEPOOL_DIR}/${SCRIPT_HEX}"
  local sidecar="${dir}/${SCRIPT_HEX}.sidecar.json"
  [[ -f "${sidecar}" ]] && { log "INFO" "self: already registered"; return 0; }
  log "INFO" "self: first run — registering intake into clonepool"
  mkdir -p "${dir}"
  local self_path; self_path=$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${0}")
  local size; size=$(get_size "${self_path}")
  cp "${self_path}" "${dir}/v1_${SCRIPT_NAME}"
  write_sidecar_basic "${dir}/${SCRIPT_HEX}.sidecar.json" \
    "${SCRIPT_HEX}" "${SCRIPT_NAME}" "v1" \
    "script:shell" "73637269707473" "${size}" "self" \
    "intake script — self registered on first run"
  custody_log_local "${SCRIPT_HEX}" "${SCRIPT_NAME}" "self_register" "v1" \
    "${self_path}" "${dir}/v1_${SCRIPT_NAME}" "white" "intake"
  report_clonepool "${SCRIPT_HEX}" "${SCRIPT_NAME}" "v1" "white" "${dir}" \
    "${dir}/${SCRIPT_HEX}.sidecar.json" "1" "${size}"
  report_custody  "${SCRIPT_HEX}" "${SCRIPT_NAME}" "self_register" "white" "intake"
  report_glossary "${SCRIPT_HEX}" "${SCRIPT_NAME}" \
    "Intake script: registers new software into the glossary and clonepool" \
    "73637269707473" "${VERSION}" "${size}" "${dir}"
  echo "[intake:OK] Self registered: ${SCRIPT_NAME} → clonepool"
}

# ══════════════════════════════════════════════════════════════
# IN — intake a file into the clonepool
# ══════════════════════════════════════════════════════════════
intake_file() {
  local filepath="${1:-}" backend="${2:-direct}" notes="${3:-}"

  [[ -z "${filepath}" ]] && { echo "[intake] Usage: intake <file> [backend] [notes]"; return 1; }
  [[ ! -f "${filepath}" ]] && { echo "[intake:MISS] File not found: ${filepath}"; return 1; }

  local orig; orig=$(basename "${filepath}")
  local hex;  hex=$(to_hex "${orig}")
  local pool_dir="${CLONEPOOL_DIR}/${hex}"
  local sidecar="${pool_dir}/${hex}.sidecar.json"

  mkdir -p "${pool_dir}"
  local version; version=$(get_next_version "${pool_dir}")
  local filetype; filetype=$(detect_filetype "${orig}")
  local category_hex; category_hex=$(filetype_to_category "${filetype}")
  local size; size=$(get_size "${filepath}")

  log "INFO" "intaking: ${orig} (${filetype}) as ${version}"

  local companion_list=""
  companion_list=$(detect_companions "${filepath}" || true)

  if [[ -n "${companion_list}" ]]; then
    while IFS= read -r companion; do
      [[ -z "${companion}" ]] && continue
      local comp_name; comp_name=$(basename "${companion}")
      cp "${companion}" "${pool_dir}/${version}_${comp_name}"
      log "INFO" "companion intaked: ${comp_name}"
    done <<< "${companion_list}"
  fi

  cp "${filepath}" "${pool_dir}/${version}_${orig}"
  log "INFO" "stored: ${pool_dir}/${version}_${orig}"

  write_sidecar_basic "${sidecar}" "${hex}" "${orig}" "${version}" \
    "${filetype}" "${category_hex}" "${size}" "${backend}" "${notes}"
  enrich_sidecar_companions "${sidecar}" "${companion_list}"
  custody_log_local "${hex}" "${orig}" "intake" "${version}" \
    "${filepath}" "${pool_dir}/${version}_${orig}" "white" "${backend}"
  report_clonepool "${hex}" "${orig}" "${version}" "white" \
    "${pool_dir}" "${sidecar}" "1" "${size}"
  report_custody  "${hex}" "${orig}" "intake" "white" "${backend}"
  report_glossary "${hex}" "${orig}" "Intaked via ${backend}: ${filetype}" \
    "${category_hex}" "${version}" "${size}" "${pool_dir}"

  echo "[intake:OK] ${orig} → clonepool ${version}"
  echo "[intake:OK] hex:  ${hex}"
  echo "[intake:OK] type: ${filetype}"
  [[ -n "${companion_list}" ]] && \
    echo "[intake:OK] companions: $(echo "${companion_list}" | wc -l | tr -d ' ')"
  return 0
}

# ══════════════════════════════════════════════════════════════
# OUT — clone latest version to your current working directory
# ══════════════════════════════════════════════════════════════
intake_clone() {
  local name="${1:-}"

  if [[ -z "${name}" ]]; then
    echo "[intake] Usage: intake clone <filename>"
    echo "         e.g.:  intake clone myfile.py"
    echo "                intake clone myfile.py.lol"
    return 1
  fi

  # Strip .lol if used in clone too
  [[ "${name}" == *.lol ]] && name="${name%.lol}"

  local hex; hex=$(to_hex "${name}")
  local pool_dir="${CLONEPOOL_DIR}/${hex}"

  if [[ ! -d "${pool_dir}" ]]; then
    echo "[intake:MISS] '${name}' not found in clonepool"
    echo "              Have you intaked it yet? Run: intake ${name}"
    return 1
  fi

  # Find the latest versioned file
  local latest
  latest=$(get_latest_file "${pool_dir}" "${name}")

  if [[ -z "${latest}" ]]; then
    echo "[intake:MISS] No versioned files found for '${name}' in clonepool"
    return 1
  fi

  local version; version=$(basename "${latest}" | grep -oP '^v\d+')
  local dest="${PWD}/${name}"

  # Warn if about to overwrite
  if [[ -f "${dest}" ]]; then
    echo "[intake:WARN] '${name}' already exists in current directory — overwriting with ${version}"
  fi

  cp "${latest}" "${dest}"

  log "INFO" "clone out: ${name} ${version} → ${dest}"
  custody_log_local "${hex}" "${name}" "clone_out" "${version}" \
    "${latest}" "${dest}" "white" "user"
  report_custody "${hex}" "${name}" "clone_out" "white" "user"

  echo "[intake:OK] ${name} ${version} → ${PWD}/"
  echo "[intake:OK] This is the latest version — ready to use"
  return 0
}

# ── Intake from backend ───────────────────────────────────────
intake_from_backend() {
  local pkg_name="${1:-}" backend="${2:-unknown}" \
        version="${3:-unknown}" install_path="${4:-}"

  [[ -z "${pkg_name}" ]] && {
    echo "[intake] Usage: intake backend <pkg_name> <backend> <version> [install_path]"
    return 1
  }

  log "INFO" "backend intake: ${pkg_name} from ${backend} ${version}"

  if [[ -n "${install_path}" && -f "${install_path}" ]]; then
    intake_file "${install_path}" "${backend}" "installed from ${backend} ${version}"
    return $?
  fi

  local hex; hex=$(to_hex "${pkg_name}")
  local pool_dir="${CLONEPOOL_DIR}/${hex}"
  local sidecar="${pool_dir}/${hex}.sidecar.json"

  mkdir -p "${pool_dir}"
  write_sidecar_basic "${sidecar}" "${hex}" "${pkg_name}" "${version}" \
    "package:${backend}" "7061636b61676573" "0" "${backend}" "installed from ${backend}"
  custody_log_local "${hex}" "${pkg_name}" "backend_install" "${version}" \
    "${backend}" "${pool_dir}" "white" "${backend}"
  report_clonepool "${hex}" "${pkg_name}" "${version}" "white" \
    "${pool_dir}" "${sidecar}" "1" "0"
  report_custody  "${hex}" "${pkg_name}" "backend_install" "white" "${backend}"
  report_glossary "${hex}" "${pkg_name}" "Package installed from ${backend} v${version}" \
    "7061636b61676573" "${version}" "0" "${pool_dir}"

  echo "[intake:OK] ${pkg_name} (${backend} ${version}) → D1"
}

# ── Status ────────────────────────────────────────────────────
intake_status() {
  local total white grey black
  total=$(find "${CLONEPOOL_DIR}" -name "*.sidecar.json" 2>/dev/null | wc -l | tr -d ' ')
  white=$(find "${CLONEPOOL_DIR}" -name "*.sidecar.json" \
    -exec grep -l '"state": "white"' {} \; 2>/dev/null | wc -l | tr -d ' ')
  grey=$(find  "${CLONEPOOL_DIR}" -name "*.sidecar.json" \
    -exec grep -l '"state": "grey"'  {} \; 2>/dev/null | wc -l | tr -d ' ')
  black=$(find "${CLONEPOOL_DIR}" -name "*.sidecar.json" \
    -exec grep -l '"state": "black"' {} \; 2>/dev/null | wc -l | tr -d ' ')
  echo ""
  echo " ╔══════════════════════════════════════╗"
  echo " ║     INTAKE / CLONEPOOL STATUS        ║"
  echo " ╚══════════════════════════════════════╝"
  echo " Worker  : ${WORKER_URL}"
  echo " Pool    : ${CLONEPOOL_DIR}"
  [[ -n "${PYTHON_CMD}" ]] \
    && echo " Python  : ${PYTHON_CMD}" \
    || echo " Python  : not found (non-critical)"
  echo " Total   : ${total}"
  echo " White   : ${white} (active)"
  echo " Grey    : ${grey} (deprecated)"
  echo " Black   : ${black} (retired)"
  echo ""
}

# ── Help ──────────────────────────────────────────────────────
show_help() {
  cat <<EOF

██╗███╗   ██╗████████╗ █████╗ ██╗  ██╗███████╗
██║████╗  ██║╚══██╔══╝██╔══██╗██║ ██╔╝██╔════╝
██║██╔██╗ ██║   ██║   ███████║█████╔╝ █████╗
██║██║╚██╗██║   ██║   ██╔══██║██╔═██╗ ██╔══╝
██║██║ ╚████║   ██║   ██║  ██║██║  ██╗███████╗
╚═╝╚═╝  ╚═══╝  ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝

  Phoenix DevOps — intake v${VERSION}

  IN  (file → clonepool):
    intake <file>                    Intake a file into the clonepool
    intake <file.ext.lol>            Short syntax — strips .lol, same result
    intake <file> [backend] [notes]  With backend tag and notes
    intake backend <pkg> <be> <ver>  Register a backend-installed package

  OUT (clonepool → your current directory):
    intake clone <file>              Pull latest version to where you are now
    intake clone <file.lol>          Short syntax works here too

  INFO:
    intake status                    Show clonepool status
    intake help                      This screen

  Examples:
    intake myfile.py.lol             Intake — short syntax
    intake ./nginx.conf              Intake — direct
    intake ./nginx.sh                Intake — auto-detects companions
    intake clone myfile.py           Clone latest to current directory
    intake clone myfile.py.lol       Same thing, short syntax
    intake backend nodejs winget 20.11.0

  Pipeline IN:   file → hex → sidecar → clonepool → custody → D1
  Pipeline OUT:  name → hex → clonepool latest → \$PWD → custody → D1

  Worker  : ${WORKER_URL}
  Pool    : ${CLONEPOOL_DIR}
  Log     : ${LOG_FILE}
  Python  : ${PYTHON_CMD:-not found (non-critical)}

EOF
}

# ── .lol resolver ─────────────────────────────────────────────
resolve_lol() {
  local arg="${1:-}"
  if [[ "${arg}" == *.lol ]]; then
    local real="${arg%.lol}"
    [[ -f "${real}" ]] && { echo "${real}"; return; }
    [[ -f "${arg}"  ]] && { echo "${arg}";  return; }
    echo "${real}"
  else
    echo "${arg}"
  fi
}

# ── Self register ─────────────────────────────────────────────
self_register

# ── Entry point ───────────────────────────────────────────────
case "${1:-help}" in
  help|--help|-h) show_help ;;
  status)         intake_status ;;
  clone)          shift; intake_clone "${1:-}" ;;
  backend)        shift; intake_from_backend "$@" ;;
  *)
    first_arg=$(resolve_lol "${1:-}")
    shift || true
    intake_file "${first_arg}" "$@"
    ;;
esac
