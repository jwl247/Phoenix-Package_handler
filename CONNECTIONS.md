# Phoenix-Package_handler

Written 2026-09-12, rewritten 2026-09-13 after reconciling with `../package-handler` and
origin/main (two merge rounds — see Known issues for both commit hashes).
Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\package-handler\CONNECTIONS.md` — same GitHub repo, checked out
twice. No longer drifted from each other, but still two separate directories.**

## What it is
Standalone repo, own `.git`, remote `github.com/jwl247/Phoenix-Package_handler.git`.
Layout: top-level `intake.sh` (no separate `intake/` subdir — that duplicate only exists in
`../package-handler`), `install.sh`/`install.ps1`/`uninstall.ps1`, `PATCH_NOTES.md`,
`PEER_REVIEW.md`, `worker/index.js` + `worker/wrangler.jsonc` (R2 binding
`CLONEPOOL_BUCKET`→`phoenix-clonepool` + D1 `PHOENIX_DB`→`phoenix_dev_db`),
`peer-review/schema.sql`.

## Dependencies
`worker/wrangler.jsonc` — R2 `CLONEPOOL_BUCKET`, D1 `PHOENIX_DB`. No `package.json` in
`worker/` (plain JS Cloudflare Worker, no npm deps declared).

## Commands / entry points
`bash intake.sh <cmd>`, `install.sh`/`install.ps1`, `wrangler deploy` inside `worker/`.

## Connects to / connected from
Same remote as `../package-handler`, and this repo (at some historical commit) is pulled
into `Phoenix-DevOps-oS/sector2/package-handler/` as a **git subtree** (squashed merge —
confirmed via `git log`: `82a9f03` squashed content from `d829892`, later `a111bce`
squashed content from `443d78e`). The subtree copy is the one actually live/deployed —
neither standalone checkout is itself deployed.

## Known issues (verified, not guessed)
- **No longer drifted from `../package-handler`** — reconciled via two real merges
  (`ab7d81c` here, `be1b236` there, 2026-09-13) after both had independently diverged past
  their common ancestor `d829892` (this repo gained a hash/R2 backport, upstream gained
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
- `../package-handler` (not this directory) has a duplicate `intake.sh` in two places
  (`intake.sh` and `intake/intake.sh`) — not yet reconciled there; unclear which was
  actually being run historically.

## Note on this file specifically
This file and `../package-handler/CONNECTIONS.md` are near-identical by design (both
directories are now byte-identical git checkouts) — they're written to each accurately
describe *their own* directory, not copy-pasted. If a future edit makes one generic enough
to paste into the other again, double-check every "this directory"/"the other one"
reference still points the right way — that's the exact mistake a fast-forward merge
caused here on 2026-09-13.
