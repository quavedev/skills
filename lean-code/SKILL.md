---
name: lean-code
description: Make the smallest complete change — skip what nobody asked for, reuse what the codebase, the platform or an installed dependency already does, delete before adding, and never cut validation, data safety, security, accessibility or tests. Use for every code, test or doc change, and when judging whether code could be smaller.
---

# Lean code

Less is more: every line has to be read, tested and fixed later. Applies to code, tests, skills and docs.

## The smallest complete change

Before writing, read the code the change touches and list every place it must reach: callers, tests, config, strings. Then take the first option that fully works:

1. Does it need to exist? Skip options, features and flexibility nobody asked for.
2. Is it already in this codebase? Use the helper or pattern the way the code around it does.
3. Does the language, platform or an installed dependency already do it? Use that. Do not add a dependency for a few lines.
4. Otherwise, the least code that works.

Rules:

- Finish the whole change. The callers, tests and strings it breaks are part of it.
- Keep the structure that is here. Follow `AGENTS.md` when it names one.
- Deleting beats adding. No wrapper, option or abstraction that has one use.
- A line the reader has to decode is not shorter.
- Comment only the why that the code cannot show.
- Fix a bug once, at its root, after checking every caller.
- A shortcut with a known limit carries a comment: `shortcut: <the limit>, <when to upgrade>`.

## Never cut

Validation at trust boundaries, error handling that prevents data loss, migrations, security, accessibility, tests, and what the issue asked for.
