# Phoenix Package Handler
**UnitedSys — United Systems | jwl247**  
**License:** GPL-3.0  
**Part of:** Phoenix DevOps OS  

---

## What This Is

The Phoenix Package Handler is the universal intake and catalog system for the Phoenix DevOps OS. It intercepts, registers, and tracks every file, package, config, and dependency that enters the system — regardless of origin or platform.

One pipeline. Every platform. Everything tracked.

```
file / package / config / api def
          ↓
       intake.sh
          ↓
  hex → sidecar → clonepool
          ↓
    custody receipt
          ↓
    D1 via packages-worker
          ↓
    catalog is always current
```

---

## Components

### `intake/intake.sh`
Universal intake script. Runs on Linux, macOS, and Windows (Git Bash).

- Self-registers on first run
- Accepts any file type (scripts, configs, binaries, yaml, json, service units)
- Auto-detects companion files (.service, .conf, .env, .yaml travel with parent)
- Generates hex identity from filename
- Writes sidecar.json with full metadata
- Versions files in clonepool (v1, v2, v3...)
- Writes local custody log (sqlite3)
- Reports to D1 via packages-worker (clonepool + custody + glossary)

### `worker/index.js`
Cloudflare Worker — packages-worker.  
The catalog API. Serves and receives data from phoenix_dev_db (D1).

**Endpoints:**
```
GET  /health
GET  /clonepool        ?state= ?limit=
POST /clonepool        (auth required)
GET  /custody          ?hex= ?limit=
POST /custody          (auth required)
GET  /glossary         ?q= ?category=
POST /glossary         (auth required)
PUT  /glossary/:id     (auth required)
DELETE /glossary/:id   (auth required)
GET  /categories
GET  /toc
GET  /versions         ?package= ?limit=
GET  /search           ?q=
```

### `worker/wrangler.jsonc`
Cloudflare Wrangler configuration. Binds worker to phoenix_dev_db D1 database.

---

## Quick Start

### Install intake.sh
```bash
git clone https://github.com/jwl247/Phoenix-Package_handler.git
cd Phoenix-Package_handler/intake
chmod +x intake.sh

# Set environment
export PHOENIX_AUTH="your-token-here"
export PHOENIX_WORKER_URL="https://packages-worker.phoenix-jwl.workers.dev"
export CLONEPOOL_DIR="$HOME/Phoenix/clonepool"

# Run
./intake.sh help
```

### Intake a file
```bash
./intake.sh ./myfile.sh
./intake.sh ./nginx.conf direct "production config"
./intake.sh ./franken.py scripts "Frank v2"
```

### Register a backend-installed package
```bash
./intake.sh backend nodejs winget 20.11.0
./intake.sh backend python apt 3.13.0
```

### Check status
```bash
./intake.sh status
```

---

## Deploy the Worker

```bash
cd worker
wrangler secret put PHOENIX_AUTH
wrangler deploy
```

---

## File Identity System

Every file gets a deterministic hex identity derived from its name:

```
"intake" → 737363726970747332f696e74616b65
```

This hex is:
- The clonepool directory name
- The sidecar filename
- The D1 primary key
- Permanent and reproducible

---

## QR State System

Every file in the clonepool carries two QR codes:

```
Top QR    → status pointer
            White = active
            Grey  = deprecated  
            Black = compromised/retired

Bottom QR → location pointer
            T1/T2/T3/T4 — max 4 folders deep
```

---

## Companion Files

Files that belong together travel together:

```
nginx.sh          ← main file
nginx.service     ← auto-detected companion
nginx.conf        ← auto-detected companion
```

All versioned as one unit. Edit the .service file in the clonepool, it propagates via HelixSync.

---

## Platform Support

| Platform | Shell | Status |
|----------|-------|--------|
| Linux    | bash  | ✅ Native |
| macOS    | bash  | ✅ Native |
| Windows  | Git Bash | ✅ Supported |

**Windows note:** Git Bash required. Python 3.x required. Both ship with Phoenix installer.

---

## Part of Phoenix DevOps OS

```
Sector 2  → intake lives here (file intake authority)
Sector 3  → pattern recognition, bypass routing  
Sector 4  → stage, prefetch, systemd
D1        → phoenix_dev_db (the backbone — 41 tables)
Frank     → kernel micro, orchestrates all sectors
```

---

*Built by JW — Phoenix DevOps OS | UnitedSys — United Systems*  
*GPL-3.0 — Free as in freedom*
