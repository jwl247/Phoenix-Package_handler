# Phoenix-Package_handler

Written 2026-09-12, rewritten 2026-09-13 after reconciling with `../package-handler`
and origin/main (two merge rounds — see Known issues for both commit hashes).
Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\package-handler\CONNECTIONS.md` — same GitHub repo,
checked out twice. No longer drifted from each other, but still two separate directories —
Jerry's stated direction (2026-09-13) is to consolidate these into one repo eventually;
this split is expected to go away.**

## What it is
Standalone repo, own `.git`, remote `github.com/jwl247/Phoenix-Package_handler.git`.
Layout: top-level `intake.sh` only (no separate `intake/` subdir — that duplicate exists
in `../package-handler`, not here), `install.sh`/`install.ps1`/`uninstall.ps1`,
`PATCH_NOTES.md`, `PEER_REVIEW.md`, `worker/index.js` + `worker/wrangler.jsonc` (R2 binding
`CLONEPOOL_BUCKET`→`phoenix-clonepool` + D1 `PHOENIX_DB`→`phoenix_dev_db`, worker name
deliberately changed 2026-09-13 to `packages-worker-standalone-DO-NOT-DEPLOY-see-comment`
— see Known issues), `peer-review/schema.sql`.

## Dependencies
`worker/wrangler.jsonc` — R2 `CLONEPOOL_BUCKET`, D1 `PHOENIX_DB`. No `package.json` in
`worker/` (plain JS Cloudflare Worker, no npm deps declared).

## Commands / entry points
`bash intake.sh <cmd>`, `install.sh`/`install.ps1`, `wrangler deploy` inside `worker/`
(**except don't** — see Known issues, this now deploys somewhere harmless on purpose).

## Connects to / connected from
Same remote as `../package-handler`, and this repo (at some historical commit) is
pulled into `Phoenix-DevOps-oS/sector2/package-handler/` as a **git subtree** (squashed
merge — confirmed via `git log`: `82a9f03` squashed content from `d829892`, later `a111bce`
squashed content from `443d78e`). The subtree copy is the one actually live/deployed —
neither standalone checkout is itself deployed, and never should be again (see below).

## Known issues (verified, not guessed)
- **Worker name defused 2026-09-13.** This repo used to deploy under the exact same
  worker name (`packages-worker`) as the real live one in
  `Phoenix-DevOps-oS/sector2/package-handler/worker/` — confirmed via
  `wrangler deployments list` that the live one was last really deployed 2026-09-05,
  matching that session's CLAUDE.md log, i.e. NOT from this repo. A `wrangler deploy`
  from here would have silently overwritten months of monorepo-only work (this repo's
  code was hundreds of lines behind). Renamed to
  `packages-worker-standalone-DO-NOT-DEPLOY-see-comment` in `worker/wrangler.jsonc` and
  struck the instruction in `PATCH_NOTES.md` that told someone to do exactly that.
- **No longer drifted from `../package-handler`** — reconciled via two real merges
  (`ab7d81c` here, `be1b236` there, 2026-09-13) after both had independently diverged past
  their common ancestor `d829892` (this repo gained a hash/R2 backport, upstream gained
  sensitive-file hardening — merged both into `report_clonepool()` rather than picking a
  side, and added `sensitive` handling to `worker/index.js`'s POST /clonepool, which was
  otherwise about to silently drop it, verified against the real live D1 schema first).
  Verify both directories are at the same commit with `git log --oneline -1` before
  assuming this stays true.
- **Still drifted from the subtree copy** at `Phoenix-DevOps-oS/sector2/package-handler/`,
  last synced at squash commit `443d78e` — the reconciliation above has NOT been
  re-subtree'd into the monorepo, and given the monorepo is 600+ lines ahead in its own
  direction, a naive pull would be risky. Real, separate, not-yet-decided work.
- **Jerry's direction (2026-09-13): consolidate `../package-handler` and this repo into
  one repo.** Once that happens this whole "two directories drifting" class of issue goes
  away structurally, not just this instance of it.

## Note on this file specifically
This file and `../package-handler/CONNECTIONS.md` describe two directories that are
byte-identical git checkouts for the *code*, but this doc file is deliberately NOT kept in
sync between them via git — each is hand-written to describe *its own* directory. A
`git merge`/`pull` touching this file between the two checkouts WILL flip the
self-references wrong (happened three times on 2026-09-13 now) — don't sync CONNECTIONS.md
across these two repos via git again; edit each by hand. This whole problem is expected to
resolve itself once the consolidation above happens.
