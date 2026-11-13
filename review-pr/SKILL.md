---
name: review-pr
description: Review a pull request, a branch or the current uncommitted diff against its context. Find real issues, gaps, pattern drift and code that could be smaller, check security and performance, stay pragmatic, and end with whether it is ready to merge. Use when asked to review a PR or "check my changes".
---

# review-pr

Review. Do not change code unless the user asks.

**Target:** a PR URL or number, a branch, or nothing. Nothing means the PR for the current branch, or the current diff (`git diff <base branch>...HEAD` plus uncommitted changes) when there is no PR.

## 1. Context first

Read everything attached before judging the diff: the PR description, linked issues, review comments, and any link they reference (`gh pr view`, `gh pr diff`, `gh issue view`). If a link cannot be read, say so. Do not invent the expected behavior.

State in one or two sentences what the change is expected to do. That is the bar.

## 2. Read the whole diff

Not a sample. If it is too large to read completely, say what you skipped and do not claim it is ready.

Report only findings, grouped as in the `no-broken-windows` skill: **Issue**, **Gap**, **Pattern drift**, **Lean**. Skip style taste, naming preferences, hypothetical bugs with no realistic path, and suggestions outside the change's purpose. It is pattern drift only when the codebase already has a clear pattern the change should have followed.

**Lean:** dead or speculative code, a helper that already exists (name the path), what the stdlib or an installed dependency already does, an abstraction with one use, near-copies. Report it only with the shorter version and about how many lines it saves. Never suggest cutting what the `lean-code` skill says never to cut.

**Security and performance:** untrusted input reaching queries, shell, HTML or file paths; missing auth or permission checks; secrets in code or logs; queries in loops, unbounded reads, missing indexes or pagination on growing data.

## 3. Follow it past the diff

Read the code outside the diff that the change depends on: callers, shared helpers, config. Think of production data volume, the first run after deploy, concurrent use and failure paths. A problem the change triggers is in scope; if its fix belongs elsewhere, report it as a **Gap** to track separately.

## 4. Merge state

For a PR, check it merges cleanly and its required checks pass on the current head. A conflict or a failing check is an **Issue**.

## Re-reviews

Run the whole review again, not only the new commits. Judge earlier findings against the original risk, not the smallest fix you suggested.

## Output

Each finding: file and line, what is wrong, why it matters. Each Lean finding shows the shorter version. With Lean findings, add `Lean: -<N> lines possible.` Nothing found: say so.

Every risk you mention is a finding or dismissed in one line. When you suggest several fixes, say which one is required.

End with exactly one line:

`Ready to merge: yes` or `Ready to merge: no`

`yes` only when the change does what was expected and has no Issue, Gap or Pattern drift to fix first. Lean findings alone do not block, unless the extra code is a new dependency or a duplicate of a helper that must change with it.
