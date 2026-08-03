---
name: quave-migrations
description: Create and run one-time database migrations with meteor/quave:migrations — sequential numbered files, a standard template with logging and error handling, automatic run on server startup via Migrations.migrateTo('latest'), and safe deploy practices. Use when transforming existing data, backfilling new fields, fixing data inconsistencies, changing indexes, or performing any one-time database operation in a Meteor app.
---

# How to create a migration (quave:migrations)

## When to use

Write a migration when you need to:

- Transform existing data in the database
- Backfill new fields on existing documents
- Clean up or fix data inconsistencies
- Drop or modify indexes
- Perform any one-time database operation

Do **not** use a migration for logic that must run on every startup — migrations run
once, tracked by version number.

## Quick steps

1. Find the next migration number in `server/migrations/sequential/`.
2. Create the migration file `{number}.js` (filename = version number).
3. Follow the template below.
4. The migration runs automatically on server startup.

## Migration template

```javascript
// server/migrations/sequential/{number}.js
import { Migrations } from 'meteor/quave:migrations';
import { MyCollection } from '../../../app/my/MyCollection';

function logStatus(message) {
  console.log('[Migration {number} - {MigrationName}]: ' + message);
}

export async function myMigration() {
  try {
    logStatus('Starting migration...');

    let processedCount = 0;

    const cursor = MyCollection.find({ /* query */ });
    for await (const doc of cursor) {
      await MyCollection.updateAsync(
        { _id: doc._id },
        { $set: { newField: 'value' } }
      );
      processedCount++;
    }

    logStatus(`Processed ${processedCount} documents`);
    logStatus('Migration completed successfully!');

    return { success: true, processedCount };
  } catch (error) {
    logStatus(`ERROR: ${error.message}`);
    console.error(error);
    throw error;
  }
}

Migrations.add({
  version: {number}, // must match the filename
  name: 'Description of what this migration does',
  up: myMigration,
});
```

(The same pattern works in TypeScript — talent-style repos use `{number}.ts`.)

## Key points

### Logging

Always define a `logStatus()` helper with a clear, greppable prefix that includes the
migration number and name:

```javascript
function logStatus(message) {
  console.log('[Migration 215 - DescriptiveName]: ' + message);
}
```

Deploy logs are the only window into a production migration — log the start, progress
counts on long loops, and the final result.

### Error handling

- Wrap the logic in try/catch.
- Log errors clearly.
- **Re-throw** to mark the migration as failed — this stops the version from advancing
  past a half-applied migration.

### Iteration

- Use `for await (const doc of cursor)` for document-by-document processing — it
  streams instead of loading everything into memory.
- All database calls are the Meteor 3 `*Async` forms, each awaited (see the `meteor`
  skill). A missing `await` in a migration is silent data loss.
- Prefer bulk operators (`updateAsync` with a broad selector, `{ multi: true }`, or
  `rawCollection().bulkWrite`) over per-document writes when the transformation
  doesn't need per-document logic — one command instead of thousands.

### Return value

Return a result object so the outcome is visible in the logs:

```javascript
return { success: true, processedCount: 42 };
```

### Registration

Always register with `Migrations.add()` at the bottom of the file:

```javascript
Migrations.add({
  version: 215, // must match the filename: 215.js
  name: 'Human-readable description',
  up: myMigration,
});
```

## Running migrations

### Automatic

Migrations run on server startup via `Migrations.migrateTo('latest')`, called from a
single init module (e.g. `server/migrations/initMigrations.js`) that also imports
every sequential file. When you add a migration, make sure it is imported there (or
by an index the init file loads).

### Testing locally

Import and call the exported function directly in the Meteor shell (`meteor shell`):

```javascript
import { myMigration } from '/server/migrations/sequential/215';
await myMigration();
```

Test against a realistic local dataset before deploying — run it, inspect the
affected documents, and confirm the counts match expectations.

## Deploying safely

- **Backup first when the migration is dangerous.** Anything that deletes, rewrites
  large amounts of data, or is hard to reverse: take a database backup before
  releasing.
- **Watch the deploy logs** until the migration reports completion — the `logStatus`
  prefix makes it easy to filter.
- **A crashed migration leaves the control document locked** so it won't re-run
  automatically. Investigate the failure, fix the cause, then unlock
  (`Migrations.unlock()` from the server shell) and let it run again. Write
  migrations to be **idempotent** (safe to re-run) so recovery is a rerun, not a
  restore.

## Checklist

- [ ] Migration number is sequential (check `sequential/` for the latest)
- [ ] Filename matches the version: `215.js` → `version: 215`
- [ ] `logStatus()` helper defined with a clear prefix
- [ ] Error handling with try/catch, error re-thrown
- [ ] Every `*Async` call awaited
- [ ] Registered with `Migrations.add()`
- [ ] Imported by the migrations init module
- [ ] Returns a result object for logging
- [ ] Tested locally (Meteor shell) before deploying
- [ ] Backup taken if the migration is dangerous
