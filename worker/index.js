// packages-worker — Phoenix DevOps OS
// UnitedSys — United Systems | jwl247
// Role: Catalog index — clonepool, glossary, TOC, packages, peer review
// DB: phoenix_dev_db (D1) — the backbone
// Auth: PHOENIX_AUTH (Cloudflare secret)
// Version: 3.4.0

const HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

const ok = (data, status = 200) => new Response(JSON.stringify(data, null, 2), { status, headers: HEADERS });
const err = (msg, status = 400) => ok({ error: msg }, status);

// ── Auth ─────────────────────────────────────────────────────────────────────
function isAuthorized(req, env) {
  const token = req.headers.get('Authorization')?.replace('Bearer ', '').trim();
  return token && token === env.PHOENIX_AUTH;
}

// ── Router ───────────────────────────────────────────────────────────────────
export default {
  async fetch(req, env) {

    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: HEADERS });
    }

    const url = new URL(req.url);
    const path = url.pathname.replace(/\/$/, '') || '/';
    const db = env.PHOENIX_DB;

    try {

      // ── Health ──────────────────────────────────────────────────────────────
      if (path === '/' || path === '/health') {
        const tables = await db
          .prepare("SELECT count(*) as n FROM sqlite_master WHERE type='table'")
          .first();
        return ok({
          status: 'ok',
          worker: 'packages-worker',
          version: '3.4.0',
          brand: 'USys — United Systems',
          db: 'phoenix_dev_db',
          tables: tables.n,
        });
      }

      // ══════════════════════════════════════════════════════════════════════
      // INTAKE ENDPOINTS — called by intake.sh after every operation
      // All writes require auth
      // ══════════════════════════════════════════════════════════════════════

      // POST /clonepool — intake.sh reports a new file into the pool
      if (path === '/clonepool' && req.method === 'POST') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const body = await req.json();
        if (!body.hex_id || !body.name) return err('hex_id and name required');

        await db.prepare(`
          INSERT INTO clonepool (hex_id, b58, name, original_name, pool_path, sidecar_path,
            state, tier, size, version)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(hex_id) DO UPDATE SET
            state = excluded.state,
            version = excluded.version,
            updated_at = CURRENT_TIMESTAMP
        `).bind(
          body.hex_id,
          body.b58 || body.hex_id,
          body.name,
          body.original_name|| body.name,
          body.pool_path || null,
          body.sidecar_path || null,
          body.state || 'white',
          body.tier || 1,
          body.size || 0,
          body.version || 'v1',
        ).run();

        return ok({ ok: true, hex_id: body.hex_id, name: body.name });
      }

      // GET /custody — ledger view
      if (path === '/custody' && req.method === 'GET') {
        const hex = url.searchParams.get('hex');
        const limit = parseInt(url.searchParams.get('limit') || '50', 10);
        const params = [];
        let query = 'SELECT * FROM custody';

        if (hex) { query += ' WHERE hex_id = ?'; params.push(hex); }
        query += ' ORDER BY intaked_at DESC LIMIT ?';
        params.push(limit);

        const result = await db.prepare(query).bind(...params).all();
        return ok({ custody: result.results, count: result.results.length });
      }

      // POST /custody — intake.sh reports a custody receipt (append only)
      if (path === '/custody' && req.method === 'POST') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const body = await req.json();
        if (!body.hex_id || !body.name) return err('hex_id and name required');

        await db.prepare(`
          INSERT INTO custody (hex_id, name, qr_top, qr_bottom, state, action, actor, validated)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          body.hex_id,
          body.name,
          body.qr_top || null,
          body.qr_bottom|| null,
          body.state || 'white',
          body.action || 'intake',
          body.actor || 'usys',
          body.validated|| 0,
        ).run();

        return ok({ ok: true, hex_id: body.hex_id, action: body.action });
      }

      // ══════════════════════════════════════════════════════════════════════
      // CLONEPOOL
      // columns: id, hex_id, b58, name, original_name, pool_path, sidecar_path,
      //          header_qr, footer_qr, hash_sha3, hash_blake2, sha3_fp, blake2_fp,
      //          state, tier, size, version, source_path, intaked_at, updated_at,
      //          qr_valid, notes
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/clonepool' && req.method === 'GET') {
        const state = url.searchParams.get('state');
        const limit = parseInt(url.searchParams.get('limit') || '100', 10);
        const params = [];
        let query = 'SELECT * FROM clonepool';

        if (state) { query += ' WHERE state = ?'; params.push(state); }
        query += ' ORDER BY intaked_at DESC LIMIT ?';
        params.push(limit);

        const result = await db.prepare(query).bind(...params).all();
        return ok({ clonepool: result.results, count: result.results.length, filter: state || 'all' });
      }

      if (path.startsWith('/clonepool/') && req.method === 'GET') {
        const id = decodeURIComponent(path.slice(11));
        const row = await db
          .prepare('SELECT * FROM clonepool WHERE hex_id = ? OR name = ?')
          .bind(id, id).first();
        return row ? ok(row) : err('not found', 404);
      }

      // ══════════════════════════════════════════════════════════════════════
      // PACKAGES
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/packages' && req.method === 'GET') {
        const limit = parseInt(url.searchParams.get('limit') || '100', 10);
        const result = await db
          .prepare('SELECT * FROM packages ORDER BY name LIMIT ?')
          .bind(limit).all();
        return ok({ packages: result.results, count: result.results.length });
      }

      if (path.startsWith('/packages/') && req.method === 'GET') {
        const id = decodeURIComponent(path.slice(10));
        const row = await db
          .prepare('SELECT * FROM packages WHERE name = ? OR id = ?')
          .bind(id, id).first();
        return row ? ok(row) : err('not found', 404);
      }

      // ══════════════════════════════════════════════════════════════════════
      // GLOSSARY
      // columns: id, hex, b58, name, category_hex, description, state,
      //          version, platform, backend, size, pool_path, sidecar,
      //          amended, intaked_at, grace_until, evicted_at, notes
      // JOIN: categories on categories.hex = glossary.category_hex
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/glossary' && req.method === 'GET') {
        const search = url.searchParams.get('q');
        const cat = url.searchParams.get('category');
        const params = [];
        const conditions = [];
        let query = 'SELECT * FROM glossary g';

        if (search) { conditions.push('g.name LIKE ?'); params.push(`%${search}%`); }
        if (cat) { conditions.push('c.name = ?'); params.push(cat); }
        if (conditions.length) query += ' WHERE ' + conditions.join(' AND ');
        query += ' ORDER BY g.name';

        const result = await db.prepare(query).bind(...params).all();
        return ok({ glossary: result.results, count: result.results.length });
      }

      if (path === '/glossary' && req.method === 'POST') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const body = await req.json();
        if (!body.hex || !body.name) return err('hex and name required');

        await db.prepare(`
          INSERT INTO glossary (hex, b58, name, category_hex, description, state, version, platform, backend, size, pool_path, sidecar, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(hex) DO UPDATE SET
            name = excluded.name,
            description = excluded.description,
            category_hex = excluded.category_hex,
            state = excluded.state,
            amended = 1
        `).bind(
          body.hex,
          body.b58 || null,
          body.name,
          body.category_hex|| null,
          body.description || '',
          body.state || 'white',
          body.version || null,
          body.platform || null,
          body.backend || null,
          body.size || null,
          body.pool_path || null,
          body.sidecar || null,
          body.notes || null,
        ).run();

        return ok({ ok: true, hex: body.hex, name: body.name });
      }

      if (path.startsWith('/glossary/') && req.method === 'GET') {
        const id = decodeURIComponent(path.slice(10));
        const row = await db
          .prepare('SELECT * FROM glossary g WHERE g.hex = ? OR g.name = ?')
          .bind(id, id).first();
        return row ? ok(row) : err('not found', 404);
      }

      if (path.startsWith('/glossary/') && req.method === 'PUT') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const id = decodeURIComponent(path.slice(10));
        const body = await req.json();

        await db.prepare(`
          UPDATE glossary SET
            description = COALESCE(?, description),
            category_hex = COALESCE(?, category_hex),
            state = COALESCE(?, state),
            notes = COALESCE(?, notes),
            amended = 1
          WHERE hex = ? OR name = ?
        `).bind(
          body.description ?? null,
          body.category_hex ?? null,
          body.state ?? null,
          body.notes ?? null,
          id, id,
        ).run();

        return ok({ ok: true, updated: id });
      }

      if (path.startsWith('/glossary/') && req.method === 'DELETE') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const id = decodeURIComponent(path.slice(10));
        await db.prepare('DELETE FROM glossary WHERE hex = ? OR name = ?').bind(id, id).run();
        return ok({ ok: true, deleted: id });
      }

      // ══════════════════════════════════════════════════════════════════════
      // CATEGORIES
      // columns: hex, name, description
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/categories' && req.method === 'GET') {
        const result = await db.prepare('SELECT * FROM categories ORDER BY name').all();
        return ok({ categories: result.results, count: result.results.length });
      }

      // ══════════════════════════════════════════════════════════════════════
      // TOC — live table of contents
      // toc columns: id, title, parent_id, position, description, layer
      // toc_entries columns: id, toc_id, package_id, position
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/toc' && req.method === 'GET') {
        const [toc, entries, poolSummary] = await Promise.all([
          db.prepare('SELECT * FROM toc ORDER BY position, title').all(),
          db.prepare('SELECT * FROM toc_entries ORDER BY toc_id, position').all(),
          db.prepare('SELECT state, COUNT(*) as n FROM clonepool GROUP BY state').all(),
        ]);

        const entryMap = {};
        for (const e of entries.results) {
          if (!entryMap[e.toc_id]) entryMap[e.toc_id] = [];
          entryMap[e.toc_id].push(e);
        }

        const tocFull = toc.results.map(t => ({
          ...t,
          entries: entryMap[t.id] || [],
        }));

        return ok({
          toc: tocFull,
          total: tocFull.length,
          pool_summary: poolSummary.results,
          generated_at: new Date().toISOString(),
        });
      }

      // ══════════════════════════════════════════════════════════════════════
      // VERSIONS
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/versions' && req.method === 'GET') {
        const pkg = url.searchParams.get('package');
        const limit = parseInt(url.searchParams.get('limit') || '50', 10);
        const params = [];
        let query = 'SELECT * FROM versions';

        if (pkg) { query += ' WHERE package_name = ?'; params.push(pkg); }
        query += ' ORDER BY created_at DESC LIMIT ?';
        params.push(limit);

        const result = await db.prepare(query).bind(...params).all();
        return ok({ versions: result.results, count: result.results.length });
      }

      // ══════════════════════════════════════════════════════════════════════
      // SEARCH — clonepool + glossary + packages
      // ══════════════════════════════════════════════════════════════════════

      if (path === '/search' && req.method === 'GET') {
        const q = url.searchParams.get('q');
        if (!q) return err('q required');
        const term = `%${q}%`;

        const [pool, gloss, pkgs] = await Promise.all([
          db.prepare('SELECT hex_id, name, state, tier FROM clonepool WHERE name LIKE ? OR hex_id LIKE ? LIMIT 20').bind(term, term).all(),
          db.prepare('SELECT hex, name, description, category_hex FROM glossary WHERE name LIKE ? OR description LIKE ? LIMIT 20').bind(term, term).all(),
          db.prepare('SELECT name, version, description FROM packages WHERE name LIKE ? OR description LIKE ? LIMIT 20').bind(term, term).all(),
        ]);

        return ok({
          query: q,
          clonepool: pool.results,
          glossary: gloss.results,
          packages: pkgs.results,
          total: pool.results.length + gloss.results.length + pkgs.results.length,
        });
      }

      // ══════════════════════════════════════════════════════════════════════
      // PEER REVIEW — opt-in distribution + review + hex + QR verification
      // Tables: submissions, reviews, revocations, advertisement_feed
      // Principle: the hex is the identity. Review attaches judgment, not content.
      // Nothing is pushed. Availability is advertised. Users pull only what they choose.
      // ══════════════════════════════════════════════════════════════════════

      // GET /review — list all submissions (filter by ?status=pending|approved|rejected)
      if (path === '/review' && req.method === 'GET') {
        const status = url.searchParams.get('status');
        const limit = parseInt(url.searchParams.get('limit') || '50', 10);
        const params = [];
        let query = 'SELECT * FROM submissions';

        if (status) { query += ' WHERE status = ?'; params.push(status); }
        query += ' ORDER BY submitted_at DESC LIMIT ?';
        params.push(limit);

        const result = await db.prepare(query).bind(...params).all();
        return ok({ submissions: result.results, count: result.results.length, filter: status || 'all' });
      }

      // GET /review/:hex — fetch review record for a specific artifact
      if (path.startsWith('/review/') && !path.includes('/vote') && !path.includes('/revoke') && req.method === 'GET') {
        const hex = decodeURIComponent(path.slice(8));
        const [submission, reviewVotes] = await Promise.all([
          db.prepare('SELECT * FROM submissions WHERE hex = ?').bind(hex).first(),
          db.prepare('SELECT * FROM reviews WHERE submission_hex = ? ORDER BY voted_at DESC').bind(hex).all(),
        ]);
        if (!submission) return err('not found', 404);
        return ok({ submission, reviews: reviewVotes.results, vote_count: reviewVotes.results.length });
      }

      // POST /review — submit an artifact for community review (auth required)
      if (path === '/review' && req.method === 'POST') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const body = await req.json();
        if (!body.hex || !body.name) return err('hex and name required');

        await db.prepare(`
          INSERT INTO submissions (hex, name, description, category, platform, submitter, artifact_url, status)
          VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
          ON CONFLICT(hex) DO UPDATE SET
            name = excluded.name,
            description = excluded.description,
            status = 'pending',
            submitted_at = CURRENT_TIMESTAMP
        `).bind(
          body.hex,
          body.name,
          body.description || '',
          body.category || null,
          body.platform || null,
          body.submitter || 'anonymous',
          body.artifact_url || null,
        ).run();

        return ok({ ok: true, hex: body.hex, name: body.name, status: 'pending' });
      }

      // POST /review/:hex/vote — cast a vote (approve / reject / abstain) (auth required)
      if (path.match(/^\/review\/[^\/]+\/vote$/) && req.method === 'POST') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const hex = decodeURIComponent(path.slice(8, path.lastIndexOf('/vote')));
        const body = await req.json();
        if (!body.vote || !['approve', 'reject', 'abstain'].includes(body.vote)) {
          return err('vote must be approve, reject, or abstain');
        }

        await db.prepare(`
          INSERT INTO reviews (submission_hex, reviewer, vote, notes)
          VALUES (?, ?, ?, ?)
        `).bind(
          hex,
          body.reviewer || 'anonymous',
          body.vote,
          body.notes || null,
        ).run();

        // Tally votes — auto-approve if approvals >= threshold (default 2)
        const threshold = 2;
        const tally = await db.prepare(
          "SELECT vote, COUNT(*) as n FROM reviews WHERE submission_hex = ? GROUP BY vote"
        ).bind(hex).all();

        const counts = {};
        for (const row of tally.results) counts[row.vote] = row.n;
        const approvals = counts['approve'] || 0;
        const rejections = counts['reject'] || 0;

        let newStatus = null;
        if (approvals >= threshold) newStatus = 'approved';
        else if (rejections >= threshold) newStatus = 'rejected';

        if (newStatus) {
          await db.prepare("UPDATE submissions SET status = ? WHERE hex = ?").bind(newStatus, hex).run();

          // If approved, register in the advertisement feed
          if (newStatus === 'approved') {
            const sub = await db.prepare('SELECT * FROM submissions WHERE hex = ?').bind(hex).first();
            if (sub) {
              await db.prepare(`
                INSERT INTO advertisement_feed (hex, name, description, category, platform, approvals, artifact_url)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(hex) DO UPDATE SET
                  approvals = excluded.approvals,
                  advertised_at = CURRENT_TIMESTAMP
              `).bind(
                hex,
                sub.name,
                sub.description || '',
                sub.category || null,
                sub.platform || null,
                approvals,
                sub.artifact_url || null,
              ).run();
            }
          }
        }

        return ok({ ok: true, hex, vote: body.vote, approvals, rejections, status: newStatus || 'pending' });
      }

      // GET /review/:hex/votes — view all votes on a submission
      if (path.match(/^\/review\/[^\/]+\/votes$/) && req.method === 'GET') {
        const hex = decodeURIComponent(path.slice(8, path.lastIndexOf('/votes')));
        const result = await db.prepare(
          'SELECT * FROM reviews WHERE submission_hex = ? ORDER BY voted_at DESC'
        ).bind(hex).all();
        const tally = await db.prepare(
          "SELECT vote, COUNT(*) as n FROM reviews WHERE submission_hex = ? GROUP BY vote"
        ).bind(hex).all();
        const counts = {};
        for (const row of tally.results) counts[row.vote] = row.n;
        return ok({ hex, votes: result.results, tally: counts, total: result.results.length });
      }

      // POST /review/:hex/revoke — revoke an approved artifact (auth required)
      if (path.match(/^\/review\/[^\/]+\/revoke$/) && req.method === 'POST') {
        if (!isAuthorized(req, env)) return err('unauthorized', 401);
        const hex = decodeURIComponent(path.slice(8, path.lastIndexOf('/revoke')));
        const body = await req.json();

        // Identity == hash. Old artifact remains addressable. Only status changes.
        await db.prepare("UPDATE submissions SET status = 'revoked' WHERE hex = ?").bind(hex).run();

        await db.prepare(`
          INSERT INTO revocations (hex, reason, revoked_by, superseded_by)
          VALUES (?, ?, ?, ?)
        `).bind(
          hex,
          body.reason || 'no reason provided',
          body.revoked_by || 'admin',
          body.superseded_by || null,
        ).run();

        // Mark as revoked in the feed (don't delete — revocation is public record)
        await db.prepare(
          "UPDATE advertisement_feed SET revoked = 1, revoked_at = CURRENT_TIMESTAMP WHERE hex = ?"
        ).bind(hex).run();

        return ok({ ok: true, hex, status: 'revoked', reason: body.reason || 'no reason provided' });
      }

      // GET /verify/:hex — verify an artifact — returns status + review provenance
      if (path.startsWith('/verify/') && req.method === 'GET') {
        const hex = decodeURIComponent(path.slice(8));
        const [submission, revocation, feedEntry] = await Promise.all([
          db.prepare('SELECT hex, name, status, submitted_at FROM submissions WHERE hex = ?').bind(hex).first(),
          db.prepare('SELECT * FROM revocations WHERE hex = ?').bind(hex).first(),
          db.prepare('SELECT * FROM advertisement_feed WHERE hex = ?').bind(hex).first(),
        ]);

        if (!submission) {
          return ok({ hex, status: 'unknown', verified: false });
        }

        if (revocation) {
          return ok({
            hex,
            status: 'revoked',
            verified: false,
            name: submission.name,
            revocation: {
              reason: revocation.reason,
              revoked_by: revocation.revoked_by,
              revoked_at: revocation.revoked_at,
              superseded_by: revocation.superseded_by || null,
            },
          });
        }

        if (submission.status === 'approved') {
          return ok({
            hex,
            status: 'verified',
            verified: true,
            name: submission.name,
            submitted_at: submission.submitted_at,
            in_feed: feedEntry ? true : false,
          });
        }

        return ok({ hex, status: submission.status, verified: false, name: submission.name });
      }

      // GET /feed — opt-in availability feed of approved artifacts
      if (path === '/feed' && req.method === 'GET') {
        const category = url.searchParams.get('category');
        const platform = url.searchParams.get('platform');
        const limit = parseInt(url.searchParams.get('limit') || '50', 10);
        const params = [];
        const conditions = ['revoked = 0'];
        let query = 'SELECT * FROM advertisement_feed';

        if (category) { conditions.push('category = ?'); params.push(category); }
        if (platform) { conditions.push('platform = ?'); params.push(platform); }
        query += ' WHERE ' + conditions.join(' AND ');
        query += ' ORDER BY advertised_at DESC LIMIT ?';
        params.push(limit);

        const result = await db.prepare(query).bind(...params).all();
        return ok({
          feed: result.results,
          count: result.results.length,
          note: 'Availability advertised. Nothing is pushed. Pull only what you choose.',
        });
      }

      // ── 404 ───────────────────────────────────────────────────────────────
      return err('not found', 404);

    } catch (e) {
      return ok({ error: e.message, worker: 'packages-worker', db: 'phoenix_dev_db' }, 500);
    }
  },
};
