# package-handler

Written 2026-09-12, rewritten 2026-09-13 after reconciling with `../Phoenix-Package_handler`
and origin/main (two merge rounds — see Known issues for both commit hashes).
Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\Phoenix-Package_handler\CONNECTIONS.md` — same GitHub repo,
checked out twice. No longer drifted from each other, but still two separate directories.**

## What it is
Standalone repo, own `.git`, remote `github.com/jwl247/Phoenix-Package_handler.git` (same
remote as `../Phoenix-Package_handler`). Layout: top-level `intake.sh`,
`install.sh`/`install.ps1`/`uninstall.ps1`, `PATCH_NOTES.md`, `PEER_REVIEW.md`,
`worker/index.js` + `worker/wrangler.jsonc` (R2 binding `CLONEPOOL_BUCKET`→
`phoenix-clonepool` + D1 `PHOENIX_DB`→`phoenix_dev_db`), `peer-review/schema.sql`.

## Dependencies
`worker/wrangler.jsonc` — R2 `CLONEPOOL_BUCKET`, D1 `PHOENIX_DB`. No `package.json` in
`worker/` (plain JS Cloudflare Worker, no npm deps declared).

## Commands / entry points
`bash intake.sh <cmd>`, `install.sh`/`install.ps1`, `wrangler deploy` inside `worker/`.

## Connects to / connected from
Same remote as `../Phoenix-Package_handler`, and this repo (at some historical commit) is
pulled into `Phoenix-DevOps-oS/sector2/package-handler/` as a **git subtree** (squashed
merge — confirmed via `git log`: `82a9f03` squashed content from `d829892`, later `a111bce`
squashed content from `443d78e`). The subtree copy is the one actually live/deployed —
neither standalone checkout is itself deployed.

## Known issues (verified, not guessed)
- **No longer drifted from `../Phoenix-Package_handler`** — reconciled via two real merges
  (`ab7d81c` there, `be1b236` here, 2026-09-13) after both had independently diverged past
  their common ancestor `d829892` (one gained a hash/R2 backport, upstream gained
  sensitive-file hardening — merged both into `report_clonepool()` rather than picking a
  side, and added `sensitive` handling to `worker/index.js`'s POST /clonepool, which was
  otherwise about to silently drop it, verified against the real live D1 schema first).
  Verify both directories are at the same commit with `git log --oneline -1` before
  assuming this stays true — it drifted once already.
- **Still drifted from the subtree copy** at `Phoenix-DevOps-oS/sector2/package-handler/`,
  last synced at squash commit `443d78e` — the reconciliation above has NOT been
  re-subtree'd into the monorepo. Real, separate work.
- Two directories checking out one repo is itself still worth Jerry's call on —
  consolidating to one would remove the *possibility* of drift recurring, not just resolve
  this instance. Not done unprompted; deleting a directory isn't a merge-conflict fix.
- Has a duplicate `intake.sh` in two places in this directory specifically (`intake.sh` and
  `intake/intake.sh`) — `../Phoenix-Package_handler` only has the top-level one. Not yet
  reconciled; unclear which was actually being run historically.
