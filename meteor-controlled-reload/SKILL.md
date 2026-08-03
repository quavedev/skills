---
name: meteor-controlled-reload
description: Stop Meteor's hot code push from force-refreshing every connected client on each deploy — gate reloads with semver version control instead (major = forced refresh, minor = ask the user, patch = silent). Use when a Meteor app reloads users mid-work on every release, when implementing or changing a client reloader, when wiring version bump scripts, or when deciding whether a release should be major, minor, or patch.
---

# Controlled client reloads in Meteor (version-gated hot code push)

By default, Meteor's hot code push reloads **every connected client** the moment a new
build is deployed — users lose form state and mid-flow work on every release, even for
server-only changes. This skill replaces that behavior with a semver contract: the
client intercepts the reload, asks the server for its version, and decides what to do
based on how big the jump is.

## The release contract

| Bump | Effect on connected users | Use for |
|---|---|---|
| **Major** | Full-page refresh, immediately | Breaking changes that make the old client incompatible with the new server |
| **Minor** | Toast: "There's a new version available. Would you like to update?" — reloads only if the user accepts (asked once per session) | Non-critical client changes that don't disrupt an active session |
| **Patch** | Nothing — users keep the running client until they naturally reload | Server-side changes, fixes that don't need immediate client adoption |

Every release decision is a version decision. When preparing a release, pick the bump
type by asking: *must* every open tab refresh right now (major), *should* users be
nudged (minor), or can the new client wait (patch)?

## How it works — three pieces

1. A **shared version constant** compiled into both bundles, kept in sync with
   `package.json` by the npm `version` lifecycle script.
2. A **server method** that returns the server's version.
3. A **client reloader** that registers `Reload._onMigrate`, always denies the
   automatic reload, and applies the contract above.

The client's constant is baked in at build time, so after a deploy the connected
(old) client still holds the previous version — comparing it to the server's answer
tells you exactly how big the update is.

### 1. Shared version constant

```javascript
// app/general/version.js — imported by both client and server
export const APP_VERSION = '12.4.0';
```

Never edit this file by hand. It is rewritten by the `version` lifecycle script:

```javascript
// tools/update-version.js
const fs = require('fs');

const version = process.env.npm_package_version;

if (!version) {
  console.error('Version is undefined in package.json');
  process.exit(1);
}

console.log('Updating version to', version);
fs.writeFileSync(
  'app/general/version.js',
  `export const APP_VERSION = '${version}';\n`
);
```

```jsonc
// package.json — npm runs the "version" script during `npm version <type>`,
// after bumping package.json but before committing, so the staged constant
// lands in the same bump commit.
{
  "scripts": {
    "version": "node tools/update-version.js && git add app/general/version.js"
  }
}
```

### 2. Server method

```javascript
// app/general/versionMethods.js (server)
import { Meteor } from 'meteor/meteor';
import { APP_VERSION } from './version';

Meteor.methods({
  getServerVersion() {
    this.unblock();
    if (Meteor.isClient) return null;
    return APP_VERSION;
  },
});
```

### 3. Client reloader

`Reload._onMigrate` handlers are consulted when a hot code push arrives. Returning
`[false]` denies the reload — that is the key move: the automatic refresh **never**
happens; the reloader decides on its own terms.

```javascript
// client/reloader.js
import { Meteor } from 'meteor/meteor';
import { Reload } from 'meteor/reload';
import { APP_VERSION } from '../app/general/version';
import { confirmUpdate } from './confirmUpdate'; // your app's confirm toast/dialog → Promise<boolean>

const Reloader = {
  clientVersion: APP_VERSION,
  modalShown: false,

  debug(message, context) {
    if (Meteor?.settings?.public?.packages?.reload?.debug) {
      console.log(`[Reloader] ${message}`, context);
    }
  },

  isMajorVersionUpdated(serverVersion, clientVersion) {
    const [serverMajor] = serverVersion.split('.').map(Number);
    const [clientMajor] = clientVersion.split('.').map(Number);
    return serverMajor > clientMajor;
  },

  isMinorVersionUpdated(serverVersion, clientVersion) {
    const [serverMajor, serverMinor] = serverVersion.split('.').map(Number);
    const [clientMajor, clientMinor] = clientVersion.split('.').map(Number);
    return (
      serverMajor > clientMajor ||
      (serverMajor === clientMajor && serverMinor > clientMinor)
    );
  },

  reloadNow() {
    this.debug('Reloading now');
    if (window.location.hash || window.location.href.endsWith('#')) {
      window.location.reload();
    } else {
      window.location.replace(window.location.href);
    }
  },

  async checkForUpdate(serverVersion) {
    this.debug('Checking for update', {
      serverVersion,
      clientVersion: this.clientVersion,
    });

    if (this.isMajorVersionUpdated(serverVersion, this.clientVersion)) {
      return true; // major → reload without asking
    }

    if (
      !this.modalShown &&
      this.isMinorVersionUpdated(serverVersion, this.clientVersion)
    ) {
      this.modalShown = true; // minor → ask once per session
      const accepted = await confirmUpdate({
        content: "There's a new version available. Would you like to update?",
        proceedLabel: 'Update Now',
      });
      if (accepted) {
        this.clientVersion = serverVersion;
        this.reloadNow();
      }
    }

    return false; // patch (or declined minor) → keep running
  },

  onMigrate() {
    this.debug('onMigrate called');
    Meteor.call('getServerVersion', async (error, serverVersion) => {
      if (error) {
        console.error('Error fetching server version:', error);
        return;
      }
      const shouldReload = await this.checkForUpdate(serverVersion);
      if (shouldReload) {
        this.clientVersion = serverVersion;
        this.reloadNow();
      }
    });
    return [false]; // always deny the automatic hot-code-push reload
  },

  initialize() {
    this.debug('Reloader initialized');
    Reload._onMigrate('reload', () => this.onMigrate());
  },
};

Meteor.startup(() => {
  if (!Meteor.isDevelopment) {
    Reloader.initialize();
  }
});
```

Implementation notes:

- **Production only.** The `!Meteor.isDevelopment` guard keeps normal hot code push
  working in development — you want instant reloads there.
- **`return [false]` is unconditional.** The version check runs asynchronously after
  denying; when a reload is warranted the reloader triggers it itself with
  `reloadNow()`.
- **`modalShown` limits the minor-bump prompt to once per session** so users aren't
  nagged repeatedly while they keep working.
- **`reloadNow()` uses `location.replace`** (not `reload()`) when there's no hash, so
  the refresh doesn't add a history entry; with a hash it falls back to `reload()`.
- **Debug logging** is gated by `Meteor.settings.public.packages.reload.debug` so you
  can trace the flow in any environment without code changes.
- The callback form of `Meteor.call` is intentional here — the reloader predates or
  sits outside normal app code paths; keep it self-contained.

## Bumping the version

Always bump through npm so the lifecycle script keeps the constant in sync
(`meteor npm`, never bare `npm`, inside a Meteor app):

```bash
cd <app-dir> && meteor npm version <major|minor|patch> --no-git-tag-version
```

- `--no-git-tag-version` stops npm from creating its own commit/tag; the `version`
  script still runs, rewriting and staging the constant file.
- Stage exactly the three version files and nothing else, then commit with the
  version as the message:

```bash
git add package.json package-lock.json app/general/version.js
git commit -m "v<newVersion>"
```

- Verify with `git status --short` that nothing unrelated is staged.

## Pitfalls

- **Forgetting to bump = silent no-op releases.** If a deploy ships without a version
  bump, connected clients compare equal versions and never refresh — old clients keep
  running indefinitely. Make the bump part of the release checklist.
- **Hand-editing the constant** desynchronizes it from `package.json`. Only the
  lifecycle script writes it.
- **Defaulting everything to major** defeats the purpose — users get force-refreshed
  on every release again. Default to patch; escalate deliberately.
