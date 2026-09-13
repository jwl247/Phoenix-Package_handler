# Phoenix-Package_handler

Written 2026-09-12. Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\package-handler\CONNECTIONS.md` — they are the same GitHub repo,
checked out twice, and have drifted. Don't edit package-handler code in only one of them.**

## What it is
Standalone repo, own `.git`, remote `github.com/jwl247/Phoenix-Package_handler.git`.
**This checkout is the AHEAD one** — HEAD at commit `d829892` ("fix: backport 08-17 hash
verification + R2 wiring from monorepo copy"). Layout: top-level `intake.sh` (48KB, no
separate `intake/` subdir), `install.sh`/`install.ps1`/`uninstall.ps1`, `PATCH_NOTES.md`
(documents the R2/hash-verification patch), `PEER_REVIEW.md`, `worker/index.js` +
`worker/wrangler.jsonc` (has R2 binding `CLONEPOOL_BUCKET`→`phoenix-clonepool` + D1
`PHOENIX_DB`→`phoenix_dev_db`), `peer-review/schema.sql`.

## Dependencies
`worker/wrangler.jsonc` — R2 `CLONEPOOL_BUCKET`, D1 `PHOENIX_DB`. No `package.json` in
`worker/` (plain JS Cloudflare Worker, no npm deps declared).

## Commands / entry points
`bash intake.sh <cmd>`, `install.sh`/`install.ps1`, `wrangler deploy` inside `worker/`.

## Connects to / connected from
This exact repo (at some historical commit) is pulled into
`Phoenix-DevOps-oS/sector2/package-handler/` as a **git subtree** (squashed merge —
confirmed via `git log`: `82a9f03` squashed content from `d829892`, later `a111bce`
squashed content from `443d78e`). The subtree copy is the one actually live/deployed —
this standalone checkout is the upstream source for that subtree pull, not itself deployed.

## Known issues (verified, not guessed)
- **Drifted from `../package-handler`**, the second local checkout of the same remote.
  That one is missing this repo's `d829892` commit (R2/hash-verification patch +
  `PATCH_NOTES.md`) and has a different `worker/wrangler.jsonc` (no R2 binding at all).
- **Drifted from the subtree copy** at `Phoenix-DevOps-oS/sector2/package-handler/`, last
  synced at squash commit `443d78e` — check whether that's newer or older than this repo's
  `d829892` HEAD before assuming either is more current.
- Three copies of the same codebase existing simultaneously is itself the core issue —
  before making any package-handler change, confirm which of the three you're actually
  editing and whether it needs to propagate to the other two.
