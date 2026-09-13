# Patch notes — package-handler R2/hash fix

Applied to the real files pulled from your Phoenix.zip upload
(sector2/package-handler/), based on the version actually live on
Cloudflare plus the locally-fixed worker copy that had diverged from it.

## Changed files
- `intake.sh` — added SHA3-256 + BLAKE2b hashing, R2 upload call,
  wired into self_register(), intake_file(), and intake_directory()'s
  per-file loop.
- `worker/index.js` — POST /clonepool now stores hash_sha3, hash_blake2,
  header_qr, footer_qr, source_path, notes, addr_scheme (all previously
  dropped). Added PUT /clonepool/:id (R2 write). GET /clonepool/:id now
  checks R2 first, falls back to D1.
- `worker/wrangler.jsonc` — added the CLONEPOOL_BUCKET -> phoenix-clonepool
  R2 binding this worker code now requires.

## Unchanged (carried over as-is)
README.md, PEER_REVIEW.md, .gitignore, install.sh, install.ps1,
uninstall.ps1, peer-review/schema.sql, .github/workflows/deploy.yml (if present)

## To deploy — DO NOT follow this as originally written (see 2026-09-13 note)
~~1. Copy this folder over your real sector2/package-handler/~~
~~2. cd worker && wrangler deploy~~ — **NEVER do this from this repo.** This
   worker's name has been changed specifically to make that impossible by
   accident (`worker/wrangler.jsonc`) — this repo shared the "packages-worker"
   name with the actual live one in `Phoenix-DevOps-oS/sector2/package-handler/`,
   and a deploy from here would have overwritten months of monorepo-only work
   (this patch predates all of it). The canonical pipeline is the monorepo's
   copy — deploy changes from there, never from here.
3. Verify: wrangler d1 execute phoenix_dev_db --command \
   "SELECT sql FROM sqlite_master WHERE name='clonepool'"
   Confirm hash_sha3, hash_blake2, header_qr, footer_qr, source_path,
   notes, addr_scheme columns exist (they did as of tonight's check).
4. Run one real intake and check it landed with a populated hash_sha3
   and that the object shows up in the phoenix-clonepool R2 bucket —
   not just that the D1 row exists.
