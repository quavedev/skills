# Quave Skills

Agent skills for building [Quave](https://www.quave.dev) applications — Meteor 3,
React 19, Tailwind CSS 4, and MongoDB — following the conventions of the
[quavedev/meteor-template](https://github.com/quavedev/meteor-template).

Skills follow the open [agent skills](https://github.com/vercel-labs/skills) format and
work with Claude Code, Cursor, Codex, OpenCode, and other supported agents.

## Install

Install all skills into your project:

```bash
npx skills add quavedev/skills
```

Install specific skills:

```bash
npx skills add quavedev/skills --skill meteor --skill meteor-frontend
```

List available skills without installing:

```bash
npx skills add quavedev/skills --list
```

## Skills

| Skill | What it covers |
| --- | --- |
| [`meteor`](./meteor/SKILL.md) | Meteor 3 architecture — async-only server (`*Async` + `await`), client/server boundaries, collections via `quave:collections`, methods, publications/subscriptions, ESM modules. |
| [`meteor-frontend`](./meteor-frontend/SKILL.md) | React 19 + React Compiler, Tailwind v4 CSS-first theming, feature folders, routing/layouts, reactive Minimongo data, alerts, mandatory responsive design. |
| [`meteor-controlled-reload`](./meteor-controlled-reload/SKILL.md) | Stop hot code push from refreshing every client on deploy — semver-gated reloads (major = force, minor = ask, patch = silent) with version bump scripts. |
| [`meteor-2-to-3-migration`](./meteor-2-to-3-migration/SKILL.md) | Incremental Meteor 2 → 3 async migration — eslint-plugin baseline, methods/pubs first under regression tests, dual-pattern split for shared code, cutover last. |
| [`quave-migrations`](./quave-migrations/SKILL.md) | One-time database migrations with `quave:migrations` — sequential numbered files, logging/error template, auto-run on startup, safe deploy practices. |
| [`pr-screenshots-videos`](./pr-screenshots-videos/SKILL.md) | Capture UI screenshots and videos with `agent-browser` and attach them to PRs via the `gh-image` extension — visual evidence for every UI change. |
| [`quave-coding-style`](./quave-coding-style/SKILL.md) | House coding rules — JS-only functional style, named params, feature folders, method shape (auth → validate → authorize → work), permission patterns, safety rules. |
| [`quave-enums`](./quave-enums/SKILL.md) | Enums with `@quave/enum` `createEnum` — never loose strings, schema `allowedValues` driven from the enum, boolean flags over string chains. |
| [`git-workflow`](./git-workflow/SKILL.md) | Safe git rules for agents — no force push, rebase, squash, or hard reset; PR-based flow; commit-message format. |
| [`create-issue`](./create-issue/SKILL.md) | Write a GitHub issue for the developer who implements it — context, scope, acceptance criteria, and where to change (files, code to reuse, tests); variants for bugs, vague features, and findings. |
| [`implement-issue`](./implement-issue/SKILL.md) | Take an issue to a reviewed PR — execution checklist in the issue body with proof per item, failing test first for bugs, browser test with `qa` before the PR, PR via `create-pr`, then a review by a separate agent with `review-pr`. |
| [`create-pr`](./create-pr/SKILL.md) | Run the project's checks, then open a PR with a Summary, an Agent test plan (already run and checked), and a Test plan (product steps for a person). |
| [`review-pr`](./review-pr/SKILL.md) | Review a PR, branch, or diff against its context — real issues, gaps, pattern drift, code that could be smaller, security, and performance; ends with `Ready to merge: yes/no`. |
| [`quality-gate`](./quality-gate/SKILL.md) | Final gate before declaring work done — `meteor npm run quave-check` / `quave-check-ci` (Oxlint + Oxfmt) and how to handle findings. |
| [`agent-file-convention`](./agent-file-convention/SKILL.md) | How AI instruction files are organized — `AGENTS.md`, `CLAUDE.md`, `internal-docs/ai/*.md`, `COLLECTIONS.md`. |

## Source of truth

These skills are derived from the canonical docs in
[`meteor-template/internal-docs/ai`](https://github.com/quavedev/meteor-template/tree/main/internal-docs/ai).
When the template docs change, update the corresponding skill here in the same spirit:
keep every rule, condense prose, and preserve the code examples that show the ✅/❌
patterns.
