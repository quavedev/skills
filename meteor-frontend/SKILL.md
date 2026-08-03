---
name: meteor-frontend
description: Frontend conventions for Quave Meteor apps — React 19 with React Compiler, Tailwind CSS v4 CSS-first setup with @theme tokens, feature-folder component organization, routing/layouts via RoutePaths, reactive data with useSubscribe/useTracker over sync Minimongo, alerts via quave:alert-react-tailwind, and mandatory responsive design. Use before touching anything user-facing — React components, pages, routes, layouts, styling, theme tokens, alerts, or reactive data wiring.
---

# Frontend reference

Read this before touching anything user-facing under `app/` — React components,
routing, layouts, styling, theme tokens, alerts, or reactive data wiring.

Stack: **Meteor 3.5 + React 19 (React Compiler) + Tailwind CSS 4**. Application source
is JavaScript, not TypeScript. The client reads reactively from Minimongo with its
synchronous APIs; persistent mutations go through validated and authorized Meteor
methods. Companion skills: `quave-coding-style` (universal rules), `meteor`
(architecture), `quave-enums` (enums).

> Never run bare `npm`. Use `meteor npm ...` so the bundled Node/npm is used and the
> lockfile stays valid.

## Where everything lives

| Path | Purpose |
|------|---------|
| `client/main.js` | Client entry. Mounts `<App />` into `#app` inside `<StrictMode>`, imports `./main.css`. |
| `client/main.css` | **Single Tailwind v4 entry point.** `@import 'tailwindcss'` + all theme tokens, custom utilities, base rules. |
| `postcss.config.mjs` | PostCSS chain — just `@tailwindcss/postcss`. Nothing else. |
| `app/general/App.js` | Root component. Wires `BrowserRouter`, `Suspense`, `AlertProvider` + `<Alert />`, and the top-level `<Router />`. |
| `app/general/Router.js` | Route table. Maps `RoutePaths` to page components, each wrapped in a layout. |
| `app/general/RoutePaths.js` | **Single source of truth for every route path.** Always import from here; never hardcode a URL string. |
| `app/general/NotFound.js` | Catch-all `*` route. |
| `app/layouts/` | Layout shells — `ConditionalLayout` (auth gate) and its thin wrappers, plus `PageWithHeader` / `PageWithoutHeader`. |
| `app/components/` | Shared, reusable UI atoms (`Button`, `Loading`, `MyAlert`, `ErrorFallback`, …). |
| `app/<feature>/` | Feature/domain folders. A feature folder holds its page components, collections, methods, and publications. |

## Component organization (feature folders)

Organize **by feature/domain**, not by atomic-design layers.

Where does a new component go?

1. Reusable across features, no domain logic → `app/components/`.
2. Specific to one feature (a page, a section, a widget) → that feature's folder.
3. Layout/route chrome → `app/layouts/` or `app/general/`.

**Naming:** PascalCase component files with a matching named export
(`export function Home()` / `export const Button = ...`). Follow the nearest sibling.
Collections/methods/publishes follow `{Entity}Collection.js`, `{entity}Methods.js`,
`{entity}Publishes.js`.

## Tailwind v4 setup

**Tailwind v4 is in use — not v3.** There is no `tailwind.config.js` and no
`postcss.config.js`. Everything is CSS-first, driven from `client/main.css`.

Practical rules:

- **Define theme tokens in `client/main.css`** inside an `@theme { … }` block — never
  in a JS config, never as inline hex values in components. New colors, fonts, sizes,
  radii, breakpoints all go there.
- **Use `@apply` only inside a `@layer components` / `@utility` block** in `main.css`,
  not scattered across ad-hoc component strings.
- **PostCSS stays as-is** — only `@tailwindcss/postcss`. Don't add Autoprefixer /
  cssnano; Tailwind v4 (Lightning CSS) handles those.
- **Vendor JS that ships Tailwind class strings** must be made visible to the v4
  scanner with an `@source '…'` line in `main.css`, or the JIT won't emit those
  classes.
- Force-generate a genuinely dynamic class with `@source inline("…")` in `main.css`.
  Do not introduce a separate legacy safelist file.

## Theme tokens — colors, fonts, sizes

Define the palette and type scale once, in `@theme`, and reference them everywhere as
normal Tailwind utilities (`bg-*`, `text-*`, `border-*`, `ring-*`, `from-*`/`to-*`, …):

```css
@theme {
  /* Colors — every stop becomes bg-brand-500, text-brand-500, etc. */
  --color-brand-500: #4f46e5;
  --color-brand-600: #4338ca;
  --color-surface: #ffffff;
  --color-danger-500: #dc2626;

  /* Fonts */
  --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif;

  /* Semantic text sizes — prefer these over raw text-sm/text-xl when a scale exists */
  --text-h1: 2.25rem;
  --text-body: 1rem;

  /* Radii */
  --radius-card: 0.75rem;

  /* Extra breakpoints, if the viewport ladder needs them */
  --breakpoint-xsm: 480px;
}
```

Guidelines:

- **Add a token before using a color/size widely.** Never hardcode a hex value in
  JSX — add `--color-*` to `@theme`, then use `bg-brand-500`. Ad-hoc alpha tints
  (`bg-brand-500/40`) are fine; promote a tint to a named token once it's reused ~3×.
- **Prefer semantic tokens** (`--text-h1`, `--radius-card`) so the whole app moves
  together when the design changes.
- Fonts loaded globally should be wired into `--font-sans` so `font-sans` (the default
  body font) picks them up.
- If the product wants dark mode, define it as tokens in `@theme` and flip the base
  rule — don't hardcode dark colors per component.

## Responsive design — mandatory

**Every UI change must work on a phone (~320px wide) and on desktop.** A layout that
breaks on mobile is a bug, not missing polish.

Work **mobile-first**: write small-screen styles unprefixed, then layer larger
breakpoints on top. **Prefer container queries** (`@container` + `@sm:`/`@md:`/…
variants) for components whose width is driven by their parent panel; fall back to
viewport variants (`sm:`/`md:`/`lg:`) for true viewport-level chrome.

Checklist for any UI change:

- **Data tables must go responsive, not squeezed.** Below a breakpoint, collapse each
  row into a stacked, labelled block; above it, render a normal table:

  ```jsx
  // Each cell carries its column label; the grid stacks on mobile, tabulates on desktop.
  <div className="grid grid-cols-1 gap-2 @md:grid-cols-4">
    <div className="flex justify-between @md:block">
      <span className="font-medium text-gray-500 @md:hidden">Name</span>
      <span>{row.name}</span>
    </div>
    {/* …one block per column… */}
  </div>
  ```

  Horizontal scroll (`overflow-x-auto`) is acceptable only for genuinely tabular,
  many-column data or inside a modal/portal where container queries don't resolve.
- **Multi-column form rows must stack.** Use `flex flex-col gap-4 @sm:flex-row` (or
  `grid grid-cols-1 @sm:grid-cols-2`). Never a bare `flex gap-2` / `grid grid-cols-2`
  that stays multi-column on a phone.
- **Right-align row actions** (`justify-end` at the larger breakpoint) so the
  rightmost button stays aligned across rows.
- **Long / user-entered text wraps with `break-words`**, not `break-all`.

**Validate across widths before shipping.** Resizing a docked desktop browser is not a
real mobile test. Check the component at ~320px, a tablet width, and desktop — via
dev-tools device emulation or by rendering at fixed widths — and confirm tables, form
rows, and actions all behave.

## Component patterns and class merging

**Functional, named, single object-param.** Every component is a named function taking
one props object:

```jsx
export const Button = ({ primary = false, secondary = false, children, ...rest }) => {
  const style = primary ? styles.primary : secondary ? styles.secondary : styles.primary;
  return (
    <button
      className={`inline-flex items-center justify-center rounded-md border px-5 py-3 ${style}`}
      {...rest}
    >
      {children}
    </button>
  );
};
```

Class-string handling:

- Short, static class strings → template literals.
- **When a component takes a `className` that should override its defaults**, merge
  with Tailwind-awareness so the consumer's utility wins: `tailwind-merge` (`twMerge`)
  resolves conflicts and `classnames` handles boolean toggles. These aren't installed
  by default — plain template-literal concatenation is fine until a component genuinely
  needs override-merging.
- **Reach for the shared primitive** (`Button`, `Loading`, `MyAlert`, `ErrorFallback`)
  instead of re-styling a raw `<button>`/spinner inline. If one is missing, add it to
  `app/components/`.

## Routing and layouts

- **`react-router-dom` v6**, `BrowserRouter` mounted in `App.js`.
- **`RoutePaths` (`app/general/RoutePaths.js`) is the only place path patterns live.**
  Import from there; never hardcode `/private`, and use
  `generatePath(RoutePaths.X, params)` for parameterized routes.
- **`Router.js`** maps each `RoutePaths.*` entry to a page wrapped in a layout:

  ```jsx
  <Route path={RoutePaths.PRIVATE} element={<LoggedLayout><Private /></LoggedLayout>} />
  ```

- **Three layout wrappers**, all built on `ConditionalLayout`:
  - **`PublicLayout`** — open to everyone (home, status, not-found).
  - **`AnonymousLayout`** — `onlyAnonymous`: redirects logged-in users to the private area.
  - **`LoggedLayout`** — `onlyLogged`: redirects anonymous users to `RoutePaths.ACCESS`.
- **`ConditionalLayout`** reads `useLoggedUser()`, shows `<Loading />` while the user
  resolves, enforces the auth rule, then renders `PageWithHeader` or
  `PageWithoutHeader`. It wraps content in an `ErrorBoundary` (`ErrorFallback`), so
  every route already has a boundary — don't add a competing top-level one.
- Add a new route by: adding the path to `RoutePaths`, importing the page in
  `Router.js`, and wrapping it in the correct layout for its access level.

## Reactive data (sync Minimongo + methods)

Client UI reads reactively from the local **Minimongo** cache and writes through
**Meteor methods**. Reads use the **sync** reactive APIs; mutations are async method
calls. The corresponding Mongo query belongs in a server-only publication. Never
extract a shared "data service" that runs the same query against Mongo and Minimongo.

```jsx
import { useSubscribe, useTracker } from 'meteor/react-meteor-data';
import { useLoggedUser } from 'meteor/quave:logged-user-react';
import { useAlert } from 'meteor/quave:alert-react-tailwind';
import { ClicksCollection } from '../clicks/ClicksCollection';

export function Home() {
  const { openAlert } = useAlert();
  const { loggedUser, isLoadingLoggedUser } = useLoggedUser();

  const isLoading = useSubscribe('countData');           // subscribe to a publication
  const clicks = useTracker(() => ClicksCollection.find().fetch(), []); // reactive sync read

  const onIncrement = async () => {
    try {
      await Meteor.callAsync('clicks.increment');         // mutation via method
      openAlert('Incremented!');
    } catch (e) {
      openAlert(e.reason);                                // surface the server message
    }
  };
  // …
}
```

Rules:

- **Reads are reactive + sync:** `useSubscribe(name, ...args)` for the subscription
  and `useTracker(() => Collection.find(...).fetch(), deps)` for reactive Minimongo
  data. Keep the query client-only. Use `useFind` only when its incremental
  cursor-observer behavior has been verified with the current React and
  `react-meteor-data` versions.
- **Client data access stays client-only.** Subscription hooks and Minimongo finds
  must not be imported by server code; the matching Mongo selectors live in
  server-only publications.
- **Mutations go through Meteor methods**, called with `Meteor.callAsync('name',
  args)`. Wrap in `try/catch` and route the error's `.reason` to `openAlert`.
- **Never call `*Async` Mongo write methods on the client**, and never call sync Mongo
  on the server.
- Prefer **collection helpers** (`clickDocument.getCountText()`) for derived,
  display-facing values over recomputing in each component.
- `useLoggedUser()` (`meteor/quave:logged-user-react`) gives
  `{ loggedUser, isLoadingLoggedUser }` — gate UI on the loading flag before deciding
  logged-in vs. not.

## Alerts and messages

In-app transient messages use **`quave:alert-react-tailwind`**. The provider and
viewport are mounted once in `App.js`:

```jsx
<AlertProvider>
  <Alert Component={MyAlert} />
  <Router />
</AlertProvider>
```

- **`MyAlert` (`app/components/MyAlert.js`)** is the presentational alert (fixed
  top-right, auto-closes) — the single place alert visuals live.
- From any component/hook: `const { openAlert } = useAlert();` then
  `openAlert('message')`. Use it for success confirmations and for surfacing method
  errors (`openAlert(e.reason)`).
- Keep alerts for transient feedback. For inline field validation, show the message on
  the field itself.

## Modals and confirmations

The template ships **no** modal/dialog primitive. When you need one:

- Build a small dialog component (a `fixed inset-0` overlay + centered panel) in
  `app/components/` so it's shared — don't re-implement per page.
- Prefer a **single mount point + imperative open API** (one dialog host near the app
  root, opened via a helper) over scattered ad-hoc `useState`-driven modals.
- Give overlays an explicit, consistent z-index and keep the alert viewport **above**
  modals so feedback stays visible while a dialog is open.
- For "are you sure?", a confirm dialog that returns a promise keeps call sites clean:
  `if (await confirmDelete()) { await Meteor.callAsync('x.remove', id); }`.

## Enums drive UI labels — never loose strings

Drive UI text/branching off the enum, never a bare string literal (full rule in the
`quave-enums` skill):

```jsx
// ✅ compare and label through the enum
const LABELS = {
  [OrderStatus.DISPATCHED.name]: 'Dispatched',
  [OrderStatus.DELIVERED.name]: 'Delivered',
};
if (order.status === OrderStatus.DISPATCHED.name) { /* … */ }
return <Pill>{LABELS[order.status]}</Pill>;

// ❌ loose strings in the UI
if (order.status === 'DISPATCHED') { /* … */ }
```

Keep the label map next to the enum (or in the feature folder) so options, colors, and
copy stay in sync with the enum's members.

## Icons

The template ships no icon library. When you add one:

- **Deep-import each icon** (`import { faPlus } from '.../faPlus'`) — root imports
  bundle the entire icon set.
- Size and color icons with Tailwind utilities (`h-5 w-5 text-brand-500`) so they
  follow theme tokens.
- If an icon library injects its own runtime CSS, make sure it loses to Tailwind's
  utilities (e.g. import its stylesheet inside `@layer base` in `main.css`).

## React 19 + React Compiler

- The **React Compiler** is enabled (`babel-plugin-react-compiler`). Don't manually
  litter code with `useMemo`, `useCallback`, or `React.memo` for routine memoization —
  add manual memoization only after profiling.
- Keep hooks unconditional and at the top level, keep render pure (no side effects
  during render), and don't mutate props or state. If the lint rule flags a component,
  fix the pattern rather than disabling it.
- Static top-level imports only; no `import`/`require` inside functions, hooks, or
  conditionals.

## Must-not-do checklist

- ❌ Don't ship a UI change that breaks on a phone. Specifically:
  - ❌ No fixed-width `<table>` that squeezes columns on mobile — use the
    responsive-table (stacked-labelled-rows) pattern.
  - ❌ No multi-column form rows that stay multi-column on phones — stack them.
  - ❌ No `break-all` on user/long text — use `break-words`.
- ❌ Don't hardcode color hex values in JSX — add a token to `@theme` first.
- ❌ Don't add a `tailwind.config.js` / `postcss.config.js`, or extra PostCSS
  plugins — the v4 CSS-first setup is intentional.
- ❌ Don't hardcode route URLs — import `RoutePaths` and use `generatePath`.
- ❌ Don't bypass shared primitives (`Button`, `Loading`, `MyAlert`,
  `ErrorFallback`) or the layout wrappers when they already cover your case.
- ❌ Don't compare enum-backed values to string literals — use `Enum.KEY.name` /
  `.value`.
- ❌ Don't call `*Async` Mongo writes on the client, or sync Mongo on the server.
- ❌ Don't introduce TypeScript in app code. JavaScript only.
- ❌ Don't put `import`/`require` inside functions, hooks, or conditionals.
- ❌ Don't manually over-memoize — the React Compiler handles it.
- ❌ Don't import an entire icon package — deep-import each icon.

## Quality gate

Before declaring frontend work done, from the repo root:

```bash
meteor npm run quave-check   # Oxlint (--fix) + Oxfmt
```

Review the diff, then run `meteor npm run quave-check-ci` and fix everything it
reports. A final manual check catches what lints can't: open the app, exercise the
changed flow, open/close any alert, and **verify the layout at ~320px, a tablet width,
and desktop** — tables collapse correctly, form rows stack, and row actions stay
aligned.
