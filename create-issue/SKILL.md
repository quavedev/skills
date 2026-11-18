---
name: create-issue
description: Create or update a GitHub issue from a feature request, a bug, a vague idea or a finding. The issue is written for the developer who implements it - it names the files to change and the code to reuse. Use when the user asks to create, file, scope or update an issue.
---

# create-issue

The reader is the developer who implements it. Do the codebase reading here, once, so `implement-issue` starts from the map instead of scouting again.

## Before creating

1. Search for duplicates: `gh issue list --state all --search "<keywords>"`.
2. Map the change: the files to change (`path:line` where it helps), the closest existing code to copy, helpers to reuse, and the tests to add. Every path you write must be one you opened.
3. Labels: only ones `gh label list` returns. Never create one.

## Body

Title: short and specific. Body:

```markdown
## Context

<the problem or the gap, one paragraph>

## Scope

<what lands, as bullets>

## Acceptance criteria

<what must be true when it is done>

## Where to change

- `<path>`: <what changes there>
- Reuse: `<helper or pattern>` in `<path>`
- Tests: `<test file to extend or create>`
```

**Bug:** replace Context and Scope with **What happens**, **Expected** and **Steps to reproduce**. Where to change names the fault, or the suspects you narrowed it to.

**Vague feature** (the user describes a need, not a task): first ask what you need to know about who it is for and why. Then write Context as the problem and who feels it, Scope as **Must have** and **Out of scope**, and Acceptance criteria as `Given <context>, when <action>, then <result>` lines. Write it in the user's terms, not implementation terms.

**Finding** from other work (the `no-broken-windows` skill): open with `Found while working on #N. Group: **<group>**.`, put the evidence in it, and keep it as small as the fix.

**Sub-issue** (one piece of a parent issue that lands on its own): title `part of #<parent> - <title>`, e.g. `part of #42 - Reset link on the login page`. The title says what this piece does; the parent number is the only link.

## Create

```bash
gh issue create --title "TITLE" --label "<existing label>" \
  --assignee "$(gh api user --jq .login)" \
  --body "$(cat <<'EOF'
…
EOF
)"
```

Return the URL. Do not start implementing unless asked.

To update an issue, edit the body (`gh issue edit N --body-file <file>`). Comments are for conversation, not status.
