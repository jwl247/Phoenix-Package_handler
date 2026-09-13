# package-handler

Written 2026-09-12, updated same day after reconciling with origin/main.
Master index: `D:\Users\jwlef\Phoenix\CONNECTIONS.md`.
**Read this alongside `..\Phoenix-Package_handler\CONNECTIONS.md` — same GitHub repo,
checked out twice. No longer drifted (see below), but still two separate directories.**

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
- **No longer drifted from `../Phoenix-Package_handler`** — both reconciled via a real
  merge (`ab7d81c`, 2026-09-13) after being pushed independently and diverging (one had
  the hash/R2 backport, the other had upstream's sensitive-file hardening; the merge
  combined both into `report_clonepool()` rather than picking a side). Both local
  directories should now be at the same commit after each pulls — verify with
  `git log --oneline -1` if in doubt, don't assume.
- **Still drifted from the subtree copy** at `Phoenix-DevOps-oS/sector2/package-handler/`,
  which was last synced at squash commit `443d78e` — the new merge commit `ab7d81c` has
  NOT been re-subtree'd into the monorepo. That's real, separate work, not done by this
  merge.
- Two directories for one repo is itself still worth Jerry's call on — consolidating to
  one local checkout would remove the *possibility* of drift recurring, not just this
  instance of it. Not done here since deleting a directory isn't a merge-conflict fix.
- Has a duplicate `intake.sh` in two places (`intake.sh` and `intake/intake.sh` — this
  directory specifically; `../Phoenix-Package_handler` only has the top-level one). Not
  yet reconciled by the merge above; unclear which was actually being run historically.
