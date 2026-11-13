---
name: publish-safety-check
description: >-
  Check that a git repo, its unpushed commits, or staged changes are safe to make public:
  no secrets, machine details (home paths, hostname, local IPs) or personal data (private
  emails, denylisted terms), including commit messages, authors, deleted files and image
  metadata. Also installs a pre-commit/pre-push guard that blocks such leaks. Use when the
  user asks whether changes are safe to push or publish, before making a repo public, before
  the first push of a new repo, or invokes /publish-safety-check.
---

# Publish safety check

Two parts: a scripted scan (`guard.sh`) that catches the mechanical leaks, and your own read
of the diff for what a regex can't judge. Report a plain verdict at the end.

Files next to this SKILL.md:
- `guard.sh --staged | --unpushed [ref] | --all` scans added lines, file names, image
  metadata, and (for commit ranges) messages and authors. Exit 1 means a blocking finding.
- `install-guard.sh [--remove]` installs it as `pre-commit` and `pre-push` hooks in the
  current repo. An existing hook is kept as `<hook>.local` and still runs first.
- Personal terms (work email, etc.) live in `~/.config/publish-guard/denylist`, one string per
  line. Never copy them into a repo, a commit, or a tool call to an outside service.

## 1. Pick the scope

| The user asks about | Mode |
|---|---|
| "safe to push", unpushed commits | `--unpushed` (commits on HEAD not on any remote) |
| making a repo public, first publish | `--all` plus the tree checks below |
| what they are about to commit | `--staged` |

Run `git status -sb`, `git log --oneline @{u}..HEAD` (or `--not --remotes`), `git remote -v`
and `git branch -a` first so the report can say exactly which commits and branches are covered.

## 2. Run the scanner

```bash
<this skill's folder>/guard.sh --unpushed   # or --all / --staged
```

Triage every finding. BLOCK means a real leak until shown otherwise. WARN needs a look: public
license author emails, documentation IPs and test fixtures are usually fine. Don't hide a
finding because it looks harmless at a glance; read the line and decide.

## 3. Check what the script can't

- **Read the diff summary** (`git diff --stat <base>..HEAD`) and skim new files, especially
  config, scripts, docs, fixtures, screenshots and logs. Look for real names, addresses, phone
  numbers, customer or employer data, internal URLs, and company or client names that shouldn't
  be public.
- **Code that reads the machine at runtime**: `process.env`, `os.homedir`, `hostname`,
  `child_process`, network calls to non-public hosts. These aren't leaks themselves, but say what
  they do.
- **Untracked and ignored files** (`git status --ignored -s`) are a risk only if they could be
  committed next; mention any `.env`, keys or dumps sitting there.
- **For `--all` (publishing a repo):** deleted files in history
  (`git log --all --diff-filter=D --name-only --format=`), every branch, tags and stashes; is there
  a LICENSE; commit author emails become public; `Co-Authored-By: Claude` lines show AI help.
- **Images:** if the script warns about metadata, inspect it (`exiftool`, or the PNG chunks)
  and look at screenshots for private content on screen.

## 4. Report

Lead with the verdict: safe to push / publish, or not, and why. Then a short list of what was
checked, with counts (commits, files, branches), and each real finding with `file:line` and the
fix. Name the commit author identity that will become public. Don't print the denylist terms or
secrets in full; refer to them ("your work email", "a GitHub token on line 12").

If anything is not safe to publish, stop and ask the user how to proceed. Never suggest
rewriting commits (no amend, rebase or reset): the user decides. If a secret is already pushed,
say it must be rotated, since rewriting history does not un-publish it.

## 5. Offer the guard

If the repo has no guard yet (`grep -l publish-safety-check "$(git rev-parse --git-path hooks)"/*`),
offer to install it:

```bash
<this skill's folder>/install-guard.sh
```

The hooks block a commit or push on any BLOCK finding. A false positive is marked by putting
`guard:allow` on that line; a one-off bypass is `--no-verify`, which you only use when the user
asks. Hooks live in `.git/hooks`, so they are per clone and never pushed.

If a new personal term should always be blocked, add it to `~/.config/publish-guard/denylist`.
