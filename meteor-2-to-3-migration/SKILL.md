---
name: meteor-2-to-3-migration
description: Incremental Meteor 2 → Meteor 3 async migration strategy — baseline the sync-code debt with @quave/eslint-plugin-meteor-quave, convert entry points (methods, publications, jobs) first under regression tests while still on Meteor 2, cascade async through helpers, split shared client/server code into async/sync twins instead of isomorphic branching, and cut over last. Use when migrating a Meteor 2 app to Meteor 3, removing Fibers/Future/Meteor.wrapAsync/Promise.await, planning or estimating such a migration, or driving a sync-violation count to zero.
---

# Meteor 2 → Meteor 3 migration

Meteor 3 removes Fibers: synchronous server code (sync Mongo, `Meteor.user()`,
`Future`, `Meteor.wrapAsync`, `Promise.await`) no longer exists on the server. This
skill is the battle-tested strategy for large apps, distilled from a real ~5,000-
violation migration.

**The core insight: do the entire conversion while still on Meteor 2.** Meteor 2.8+
ships the `*Async` APIs alongside the sync ones, and every entry-point runner
(methods, publications, startup, webapp handlers) already awaits async handlers. So
you convert incrementally in small PRs, keep the full test suite green on Meteor 2 the
whole time, and only bump to Meteor 3 when the sync-violation count is zero. The
version bump is the **last** step, not the first.

Companion skill: `meteor` — the target end-state (async-only server, sync Minimongo
client, no isomorphic data access) and the full banned→required API table.

## Phase 0 — Baseline with `@quave/eslint-plugin-meteor-quave`

Install the plugin ([quavedev/eslint-plugin](https://github.com/quavedev/eslint-plugin)):

```bash
meteor npm i -D @quave/eslint-plugin-meteor-quave
```

```javascript
// .eslintrc.js
module.exports = {
  plugins: ['@quave/meteor-quave'],
  rules: {
    '@quave/meteor-quave/no-sync-mongo-methods-on-server': 'warn',
    '@quave/meteor-quave/no-sync-user-methods-on-server': 'warn',
    '@quave/meteor-quave/no-fibers-future-usage': 'warn',
    '@quave/meteor-quave/no-meteor-wrap-async-usage': 'warn',
    '@quave/meteor-quave/no-promise-fibers-usage': 'warn',
  },
};
```

| Rule | Catches | Fix |
|---|---|---|
| `no-sync-mongo-methods-on-server` | `Coll.findOne/insert/update/remove/upsert/fetch/count` on server | `await Coll.*Async(...)` |
| `no-sync-user-methods-on-server` | `Meteor.user()` on server | `await Meteor.userAsync()` |
| `no-fibers-future-usage` | `new Future()`, `.wait()`, `.return()` | native Promise |
| `no-meteor-wrap-async-usage` | `Meteor.wrapAsync(fn)` | `await` the underlying async fn |
| `no-promise-fibers-usage` | `Promise.await(x)` | `await x` |

The **pending-migration count** across these five rules is your progress metric.
Record the baseline, then drive it to zero. Use a scoped counter so you can measure
one directory or file at a time:

```javascript
#!/usr/bin/env node
// tools/mcount.js — scoped violation counter. Usage: node tools/mcount.js [paths...]
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const RULES = new Set([
  'no-sync-mongo-methods-on-server', 'no-sync-user-methods-on-server',
  'no-fibers-future-usage', 'no-meteor-wrap-async-usage', 'no-promise-fibers-usage',
]);
const targets = process.argv.slice(2);
const args = (targets.length ? targets : ['.'])
  .concat(['--ext', '.js,.jsx,.ts,.tsx', '--format', 'json']);
const res = spawnSync(
  process.execPath,
  [path.join(process.cwd(), 'node_modules/eslint/bin/eslint.js'), ...args],
  { env: { ...process.env, METEOR_ESLINT_PLUGIN_IGNORE_CACHE: '1' },
    maxBuffer: 512 * 1024 * 1024, encoding: 'utf8' }
);
let report;
try { report = JSON.parse(res.stdout); }
catch { console.error('eslint did not return JSON:\n', res.stderr.slice(0, 2000)); process.exit(1); }
const per = {}; const byFile = {}; let total = 0;
for (const f of report) for (const m of f.messages || []) {
  const short = (m.ruleId || '').replace('@quave/meteor-quave/', '');
  if (!RULES.has(short)) continue;
  total++; per[short] = (per[short] || 0) + 1;
  const rel = path.relative(process.cwd(), f.filePath);
  byFile[rel] = (byFile[rel] || 0) + 1;
}
console.log(`TOTAL=${total}  files=${Object.keys(byFile).length}`);
console.log('perRule=', JSON.stringify(per));
for (const [f, c] of Object.entries(byFile).sort((a, b) => b[1] - a[1]))
  console.log(`${String(c).padStart(4)}  ${f}`);
```

**Counter integrity rules (learned the hard way):**

- The plugin caches its file walk — always run counts with
  `METEOR_ESLINT_PLUGIN_IGNORE_CACHE=1` (stale caches report **false zeros** after a
  branch switch). On big projects raise
  `METEOR_ESLINT_PLUGIN_EXPIRES_CACHE_IN_SECONDS` so the cache doesn't expire
  mid-analysis.
- A file with a **parse error reports 0 violations** (eslint can't lint it). Always
  parse-check a file before trusting its zero.
- **Never game the count.** No `eslint-disable` on a real violation, no renaming or
  namespacing calls to dodge the rule. The only legitimate disable is a genuine false
  positive (e.g. crypto's `hash.update(data)` matching the Mongo `update` pattern) —
  inline, with a comment stating why.

## Phase order

Convert in this order, one small PR per cohesive cluster:

1. **Methods and publications** (and background-job handlers). These are entry
   points — their runners await async handlers, so converting them is safe on
   Meteor 2 and each one is a natural seam for regression tests.
2. **Server-only libraries and helpers** — coordinated cascades, leaf-first.
3. **Shared client+server code** — the dual pattern (below). This is usually the
   biggest and riskiest bucket; doing it after methods/pubs means most server callers
   are already async and ready to `await`.
4. **Deferred items** (below) — converted at cutover, not before.
5. **Final sweeps** for what the linter can't see.

**Guard every step with regression tests.** Before converting a method or
publication, make sure tests cover its observable behavior (add them if missing);
run the full suites (unit, integration, e2e) on every PR. Green tests on Meteor 2
are the safety net that makes the whole incremental strategy work.

## The conversion recipe (applies to every file)

1. Make the enclosing function `async` (method handler, helper, resolver, job
   handler, callback).
2. `Coll.findOne/insert/update/remove/upsert(...)` → `await Coll.*Async(...)`.
3. Cursor terminals: `.fetch()` → `await .fetchAsync()`; `.count()` →
   `await .countAsync()` (parenthesize in conditions:
   `(await X.find(q).countAsync()) === 0`); `.map` → `await .mapAsync`;
   `.forEach` → `for await (const x of cursor) { ... }`.
4. `Meteor.user()` → `await Meteor.userAsync()` — cache it once per function.
5. Callback-form `Coll.update(q, m, cb)` → `await Coll.updateAsync(q, m)` then
   inline the former callback body.
6. `Meteor.wrapAsync(fn)` → `await` the underlying async fn. `Promise.await(x)` →
   `await x`.
7. `new Future()` / `.wait()` / `.return()` / `.throw()` → native Promise. Prefer, in
   order: (a) `await util.promisify(fn)(args)` when the Future just wraps a
   node-style callback; (b) `await new Promise((resolve, reject) => { ... })` around
   the region; (c) external resolvers only when resolution happens far from creation.
   Preserve resolve-vs-throw semantics (`fut.return(x)` → `resolve(x)`,
   `fut.throw(e)` → `reject(e)`). `Future.wait([arr])` → `await Promise.all(arr)`.
8. **Never pass an `async` function to `_.each` / `.forEach` / `.map` for writes** —
   that's a fire-and-forget bug. Convert the loop to `for...of` / `for await` in ONE
   atomic edit (replace the opening `_.each(arr, fn) {` and the closing `});`
   together, so the file never has a dangling `});` — the #1 cause of a broken file).
   A `return;` skip inside a converted `_.each` becomes `continue;`.
9. **Direct-chain cursor reads** (`Coll.find(q).fetch()` — object is a call
   expression) are invisible to the linter but crash at Meteor 3 runtime. Convert
   them in any file you're already touching; untouched files are covered by the final
   sweep.
10. **Cascade to callers.** Making a helper async breaks callers that use its return
    value synchronously:
    - Caller already async and uses the result → add `await`.
    - Fire-and-forget call (email send, logging, after-mutation side effects) →
      **still `await` it** if the caller is or can trivially become async — it
      preserves Meteor 2 ordering and error propagation exactly. Only leave it
      un-awaited when the caller genuinely cannot become async, and then it MUST get
      `.catch((e) => /* route to the file's logger */)`.
      **Why this is non-negotiable:** Meteor 2's Node only *warns* on an unhandled
      promise rejection, so your tests won't catch it — but Meteor 3's Node
      **terminates the process**. A bare un-awaited call that used to throw
      synchronously becomes a production server crash. It has to be right by
      construction, not by test.
    - Caller in a sync context that can't cascade (Blaze, an unmigrated package) →
      stop, leave the helper converted, and record an explicit deferral instead of
      chasing indefinitely.
11. Convert the **whole chain** — the flagged call plus its callers and callees —
    never just the flagged line.

### The always-truthy trap

An un-awaited async boolean helper is **always truthy**: `if (userCanEdit(...))`
takes the then-branch every time once `userCanEdit` becomes async. Permission checks
are the dangerous case. When converting any boolean-returning helper, grep every call
site for `if (` / `&&` / `? :` usage and confirm each one got its `await`.

## Shared code: duplicate, don't branch (the dual pattern)

The `meteor` skill's rule — **no isomorphic data access** — is also the migration
strategy. When a helper is loaded by both bundles and does data access, do NOT make
one function serve both environments with `Meteor.isClient` branches or a
sync-vs-async wrapper. (A runtime guard doesn't even silence the linter: shared files
are eagerly loaded on the server, so the sync body must physically leave
server-loaded files.) **The solution is to duplicate front/back:**

1. In the shared file, convert the helper to async in place and name it `fnAsync`.
   Minimongo also implements the `*Async` API, so the async version is legal on both
   sides. Server callers `await fnAsync(...)`.
2. Move the sync body **verbatim** to a mirror module under `client/` (same export
   name), and repoint every client importer — and any Blaze global-helper
   registration, which already lives in client code — to the new path.
3. Re-run the counter on the shared file (must be 0) and grep that no server file
   imports the client copy.

Client React code may adopt `fnAsync` where trivial, but don't force that churn —
the sync client twin is the default (client reads stay sync per the `meteor` skill).

**Classify each shared helper first** by grepping its usages in `client/`, Blaze
templates, and template helpers:

- Consumed by client/Blaze synchronously → **dual pattern**.
- Server-only in practice (nothing on the client uses it) → plain cascade, no twin.

Work **leaf-first** (helpers that call no other flagged helper) so awaits compose
upward, and batch caller edits by directory so each PR stays reviewable.

## Deferrals — convert at cutover, not before

Some code **cannot** be converted while on Meteor 2. Track these explicitly as a
cutover work-list instead of half-converting them:

- **Collection-hooks handlers** (`before.*`/`after.*`): on Meteor 2 the hooks package
  dispatches aspects synchronously and ignores returned promises — an async hook
  handler silently becomes fire-and-forget at mutation time, breaking the contract
  that a write returns only after propagation completed (stale reads, missed rows,
  cross-test leaks). Keep hook handlers sync until the cutover, then upgrade to
  `quave:collection-hooks` 2.x (Meteor 3-only) and convert them in the same change.
- **Code whose callers live in unmigrated Meteor packages**: convert the package and
  its callers as one coordinated chunk, or defer both.
- **Callback-return-value state machines** (a callback's return drives transitions):
  restructure into an explicit async sequence at conversion time — naive
  async-ification changes the return into a Promise and breaks the machine.

## Per-PR guardrails

1. Parse-check every changed file (a broken file lints as 0 violations).
2. Scoped count on every changed file = 0 (`IGNORE_CACHE` on).
3. Full test suites green — fix causes, don't skip tests.
4. Keep PRs small: one helper + its callers, or one cohesive cluster.
5. Cross-PR caller overlaps are expected in cascades — keep those edits additive
   (adding `await`) and flag them in the PR body so merge conflicts stay trivial.
6. Follow the `git-workflow` skill — no force pushes, no rebases; new commits on top.

## Final sweeps (before cutover)

The count hitting zero is necessary but not sufficient — two classes of bug are
invisible to the linter and only crash on Meteor 3:

1. **Direct-chain cursor reads** in files never otherwise touched:

   ```bash
   grep -rnE '\.find\([^;]*\)\.(fetch|count|forEach|map)\(' server/ both/ imports/
   ```

   Convert each (`await ...fetchAsync()` etc., making enclosing functions async).

2. **Un-awaited async calls** with no `.catch` — process killers on Node 20+. Sweep
   call sites of converted helpers that are neither awaited, caught, returned, nor
   assigned; fix per recipe step 10 (prefer `await`; else `.catch`).

## Cutover checklist

- [ ] Whole-app count = 0 (fresh, cache-ignored run; false-positive disables documented inline)
- [ ] Both final sweeps done
- [ ] Full suites green on Meteor 2 (unit + integration + e2e)
- [ ] Bump to Meteor 3 (`meteor update --release 3.x`); follow
      https://v3-migration-docs.meteor.com/ for platform changes
- [ ] Upgrade Meteor-3-only package versions (e.g. `quave:collection-hooks` 2.x) and
      convert the deferred hook handlers in the same change
- [ ] Convert remaining deferrals (state machines, package-coupled helpers)
- [ ] `WebApp.connectHandlers` → `WebApp.handlers`, `WebApp.rawConnectHandlers` →
      `WebApp.rawHandlers`
- [ ] Full suites green on Meteor 3, then a manual test pass over every area the
      migration touched (keep a per-area test matrix as you go — it becomes this
      checklist's script)
- [ ] From here on, the `meteor` skill's rules are enforceable as written — keep the
      five lint rules on (as errors now) to prevent regressions
