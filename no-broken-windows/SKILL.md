---
name: no-broken-windows
description: Every flaw found while working ends fixed (in scope), filed as an issue (out of scope) or dismissed with a reason — never left as a TODO or a note in the reply. Defines the four finding groups (Issue, Gap, Pattern drift, Lean). Use while implementing, testing, reviewing or exploring code, whenever you notice a bug, a missing case or a flaw.
---

# No broken windows

A flaw left in place tells the next change that flaws are fine here. So a flaw you find is never left as a remark in the reply. Applies to all work: implementing, testing, reviewing, exploring.

## What counts as a finding

| Group         | What it is                                                              |
| ------------- | ----------------------------------------------------------------------- |
| Issue         | A bug: a concrete input or situation gives a wrong result.              |
| Gap           | A rule, a case or a test that should exist and does not.                |
| Pattern drift | Code that does not follow a clear pattern this codebase already has.    |
| Lean          | Code that can be deleted or made smaller without changing what it does. |

No case, no finding. Before reporting one, run it or read the lines again, and keep the evidence: the input that goes wrong, or the shorter version and how many lines it saves. Style taste and failures with no realistic path are not findings.

## What to do with one

| The finding is                                            | Do                                       |
| --------------------------------------------------------- | ---------------------------------------- |
| Caused by the change in hand, or inside its issue's scope | Fix it now, in this change.              |
| Outside that scope                                        | Leave the code alone and file it.        |
| Real, but not worth the work                              | Dismiss it in one line, with the reason. |

Every finding ends as fixed, filed or dismissed. A `TODO` comment or a note at the end of the reply is none of the three.

A session asked only to review reports its findings and stops there. The session that asked sorts them.

To file one: search first (`gh issue list --state all --search "<keywords>"`), then use the `create-issue` skill. One finding per issue; small ones in the same function may share one. Link the issue where it was found: in the PR body under `## Found along the way`, or in the reply when there is no PR.

An in-scope finding that cannot be fixed properly now gets a `shortcut:` comment at the spot (see the `lean-code` skill) and an issue for the real fix.
