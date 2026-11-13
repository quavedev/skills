---
name: create-pr
description: Open or update a pull request after the project's checks, with a Summary, an Agent test plan (run and checked by the opening agent) and a Test plan (checked by whoever runs it). Use when opening or updating a PR, or when implement-issue reaches its PR step.
---

# create-pr

## Before opening

1. The branch is pushed (`git push -u origin HEAD`). Follow the `git-workflow` skill.
2. Run the checks in `AGENTS.md` that the diff can affect (in Quave apps, the `quality-gate` skill). Fix failures first; never open a red PR. A docs-only change needs a read of the diff against the issue, not the app suite.

## Body

```markdown
Closes #N

## Summary

- <what landed, 1 to 3 bullets>

## Agent test plan

- [x] `<command you ran>`

## Test plan

- [ ] <step that exercises the change in the product>

## Found along the way

- #<issue>: <one line>. Or: None.
```

- **Agent test plan:** commands or checks an agent can run. Run every one before opening and check it. Never leave them for the reviewer.
- **Test plan:** steps in the product, no shell commands. Unchecked until someone runs them. If a step ran under different conditions (emulator, other data), say so on the line. No UI: `- [ ] N/A: no user-facing change.`
- **UI changes:** attach at least one screenshot, and a video for interactive flows, with the `pr-screenshots-videos` skill.
- `Closes #N` only when the PR fully completes the issue.

## Create

```bash
gh pr create --base <base branch> --assignee "$(gh api user --jq .login)" \
  --title "<what the PR does> (#<N>)" --body "$(cat <<'EOF'
…
EOF
)"
```

When updating an existing PR, keep the agent boxes in sync with what you actually ran. Return the PR URL.
