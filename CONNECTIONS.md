# Phoenix-Package_handler

Written 2026-09-12, updated 2026-09-13 after reconciling with `../package-handler` and
origin/main. Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\package-handler\CONNECTIONS.md` — same GitHub repo, checked out
twice. No longer drifted from each other (see below), but still two separate directories.**

## What it is
Standalone repo, own `.git`, remote `github.com/jwl247/Phoenix-Package_handler.git`.
Layout: top-level `intake.sh`, `install.sh`/`install.ps1`/`uninstall.ps1`, `PATCH_NOTES.md`,
`PEER_REVIEW.md`, `worker/index.js` + `worker/wrangler.jsonc` (R2 binding
`CLONEPOOL_BUCKET`→`phoenix-clonepool` + D1 `PHOENIX_DB`→`phoenix_dev_db`),
`peer-review/schema.sql`.

## Dependencies
`worker/wrangler.jsonc` — R2 `CLONEPOOL_BUCKET`, D1 `PHOENIX_DB`. No `package.json` in
`worker/` (plain JS Cloudflare Worker, no npm deps declared).

## Commands / entry points
`bash intake.sh <cmd>`, `install.sh`/`install.ps1`, `wrangler deploy` inside `worker/`.

## Connects to / connected from
This repo (at some historical commit) is pulled into
`Phoenix-DevOps-oS/sector2/package-handler/` as a **git subtree** (squashed merge —
confirmed via `git log`: `82a9f03` squashed content from `d829892`, later `a111bce`
squashed content from `443d78e`). The subtree copy is the one actually live/deployed —
this standalone checkout is the upstream source for that subtree pull, not itself deployed.

## Known issues (verified, not guessed)
- **No longer drifted from `../package-handler`** — reconciled via two real merges
  (`ab7d81c` here, `be1b236` there, 2026-09-13) after both had independently diverged past
  their common ancestor `d829892` (one gained the hash/R2 backport, upstream gained
  sensitive-file hardening — merged both into `report_clonepool()` rather than picking a
  side, and added `sensitive` handling to `worker/index.js`'s POST /clonepool, which was
  otherwise about to silently drop it). Verify both directories are at the same commit
  with `git log --oneline -1` before assuming this stays true.
- **Still drifted from the subtree copy** at `Phoenix-DevOps-oS/sector2/package-handler/`,
  last synced at squash commit `443d78e` — commit `ab7d81c` has NOT been re-subtree'd into
  the monorepo. Real, separate work; not done by the merges above.
- Two directories checking out one repo is itself still worth Jerry's call on —
  consolidating to one would remove the *possibility* of drift recurring, not just resolve
  this instance. Not done unprompted; deleting a directory isn't a merge-conflict fix.
