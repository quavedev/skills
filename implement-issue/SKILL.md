---
name: implement-issue
description: Implement a GitHub issue through an execution checklist kept in the issue body, with proof per item, a PR, and a review by a separate agent before it counts as ready. Use when the user asks to implement, work, pick up or fix an issue or a bug.
---

# implement-issue

Turn an issue into a reviewed PR. The issue body is the tracker, not comments. Follow the `git-workflow`, `lean-code` and `no-broken-windows` skills. Running this skill is the user's request for this issue's commits and pushes.

## 1. Start

1. `git status`. If the tree is dirty, stop and ask.
2. Update the base branch (the one `AGENTS.md` names, default `main`) with `git pull --ff-only`, then `git checkout -b feature/<N>-<short-slug>`.
3. `gh issue view N --json title,body` and assign yourself: `gh issue edit N --add-assignee "$(gh api user --jq .login)"`.
4. No issue yet? Create it with `create-issue` first.

## 2. Checklist in the issue body

Append it, keeping the original text. Reuse an existing one; refine it only when it is stale.

```markdown
## Execution checklist

- [ ] (TODO) (CODE) <specific behavior>. Proof: <file or check>.
- [ ] (TODO) (TEST) Tests for <behavior>, or (SKIP) Reason: <why>.
- [ ] (TODO) (VERIFY) Checks from `AGENTS.md`.
- [ ] (TODO) (PR) Open the PR.
- [ ] (TODO) (REVIEW) Review gate. Proof: the review's last line.
```

States: `(TODO)`, `(IN PROGRESS)`, `[x] (DONE) … Proof: …`, `(BLOCKED) … Reason: …`, `[x] (SKIP) … Reason: …`.

Save with `gh issue view N --json body -q .body > <tmp>`, edit, `gh issue edit N --body-file <tmp>`.

## 3. Execute

Item by item: mark it `(IN PROGRESS)`, do it, put the proof on the line, mark it `(DONE)`. Sync the body as you go. A blocked item gets `(BLOCKED)` with a reason; move on to what does not depend on it.

- Before each code item, read the files it touches and copy their patterns.
- **For a bug, write a failing test that reproduces it first**, then fix it at the root.
- Commit as you go, one logical change per commit. Before each commit, run the checks `AGENTS.md` asks for (in Quave apps, the `quality-gate` skill).

## 4. PR

Run the checks and report the real output. Then open the PR with `create-pr`, with `Closes #N`, and put its URL on the `(PR)` line.

## 5. Review gate

The PR is not ready until an agent that did not write it has read it.

1. Start a separate agent with fresh context. Give it only the PR number and tell it to follow the `review-pr` skill and change no code. If you cannot start one, say so and stop; never review your own work instead.
2. Sort each finding by the `no-broken-windows` skill: fix, file or dismiss. List filed issues and dismissals in the PR body under `## Found along the way`.
3. Push fixes as new commits. `Ready to merge: no` means a new round with a new agent. A `yes` followed only by Lean fixes needs no new round.
4. At `yes`, mark `(REVIEW)` done with that line. After three rounds without it, mark it `(BLOCKED)` and say what is still open.

Do not merge the PR unless the user asks.
