---
name: qa
description: Test what was built the way a user would - in the browser, across UI states and screen sizes, or on a mobile device - with screenshots as evidence and a pass/fail result per test. Use for "qa", "smoke test", "test this", "check the UI", "does it work on mobile", or the Test plan of an issue or PR.
---

# qa

Validate a change as a user, not as its author. Never commit and never fix in this skill: present findings and wait.

## 1. Scope

From the argument: an issue or PR (`gh issue view` / `gh pr view`: acceptance criteria and Test plan), a prompt, or nothing (the current diff). Get the run command and URL from `AGENTS.md`, then the README. Make sure the app is running.

## 2. Plan

Write a numbered list of tests and show it before running. Cover what applies:

- the happy path, end to end
- forms: valid, empty and invalid input, error and success messages
- empty, loading and error states; long text and special characters
- navigation, reloads and direct URLs
- what the diff could have broken nearby

## 3. Run

Load only the reference for the surface you test:

| Surface | Reference |
| --- | --- |
| Web app in a browser | `references/web.md` |
| Layout across states and screen sizes | `references/ui-states.md` |
| iOS or Android app | `references/mobile.md` |

For each test: run it, take a screenshot, look at the screenshot, record PASS, FAIL (expected vs actual) or SKIP (reason).

## 4. Report

| # | Test | Result | Evidence |
| --- | --- | --- | --- |

End with **QA passed** or **QA failed**. Each failure follows the `no-broken-windows` skill: propose the fix if it is in scope, or the issue to file. Wait for approval. After fixes, re-run the failed tests.

When the run came from a PR or issue Test plan, tick only the steps you actually ran, noting any different conditions.
