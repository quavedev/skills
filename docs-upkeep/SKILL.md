---
name: docs-upkeep
description: Keep AI instructions true — when work proves a documented command, path, rule or skill wrong, verify it against the real output or code and fix it in the one file that owns it, in the same change. Use when a documented step fails, a skill caused the same mistake twice, or a task revealed something the next agent needs to know.
---

# Docs upkeep

These instructions are only useful while they are true. When work proves one wrong, fix it in the same change.

Fix when:

- A documented command, path, env var or setup step fails because the doc is stale.
- A rule or skill caused, or would cause, the same mistake twice.
- A task revealed a sharp edge or workflow the next agent needs.

Skip one-off noise, outages, guesses you could not verify, and anything sensitive (secrets, customer data, personal details).

How:

1. Verify the mismatch against the real command output or code. Not from memory.
2. Edit the one place that owns the fact. Link to it instead of copying it.
3. Project facts go where the `agent-file-convention` skill says (`AGENTS.md` or `internal-docs/ai/`). Skills installed from a shared skills repo are overwritten on update: fix them in that repo, not in the project's copy.
4. Say in the reply or PR body what you changed in the docs.
