# package-handler

Written 2026-09-12. Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\Phoenix-Package_handler\CONNECTIONS.md` — they are the same
GitHub repo, checked out twice, and have drifted. Don't edit package-handler code in only
one of them.**

## What it is
Standalone repo, own `.git`, remote `github.com/jwl247/Phoenix-Package_handler.git` (same
remote as `../Phoenix-Package_handler`). **This checkout is the BEHIND one** — HEAD at
commit `6c56cc8` ("feat: add pip3 to install dependencies"), missing the later `d829892`
R2/hash-verification patch. Layout differs from the other checkout: has BOTH a top-level
`intake.sh` (44KB, different size than the other repo's 48KB) AND a separate
`intake/intake.sh` (23KB) subdirectory — the other checkout only has the top-level one.
`worker/wrangler.jsonc` here has **no R2 binding**, only D1 `PHOENIX_DB`. No
`PATCH_NOTES.md` (predates that patch). `README.md`/`PEER_REVIEW.md`/`peer-review/schema.sql`
are byte-identical to the other checkout.

## Dependencies
`worker/wrangler.jsonc` — D1 `PHOENIX_DB` only (no R2 — this is the pre-patch state).

## Commands / entry points
`bash intake.sh <cmd>` (top-level) or `bash intake/intake.sh <cmd>` (subdir — same content
class, different vintage), `install.sh`/`install.ps1`.

## Connects to / connected from
Same remote as `../Phoenix-Package_handler` and the subtree at
`Phoenix-DevOps-oS/sector2/package-handler/` — see that repo's `CONNECTIONS.md` for the
subtree-squash commit history.

## Known issues (verified, not guessed)
- **This is the stale/behind copy.** Missing the R2 upload + SHA3-512/BLAKE2b hash
  verification patch (`d829892`) that `../Phoenix-Package_handler` has. If you need the
  current canonical package-handler behavior, use `../Phoenix-Package_handler` or the
  subtree inside `Phoenix-DevOps-oS`, not this one.
- Has a duplicate `intake.sh` in two places (`intake.sh` and `intake/intake.sh`) — unclear
  which was actually being run historically; don't assume they're identical (different
  file sizes confirmed).
