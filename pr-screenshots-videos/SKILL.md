---
name: pr-screenshots-videos
description: Capture screenshots and video recordings of UI changes with agent-browser and attach them to GitHub pull requests using the gh-image extension — visual before/after evidence for every UI-affecting PR. Use when asked to attach a screenshot or video to a PR, show before/after of a UI change, record a flow, demo a feature on the PR, or visually document frontend work.
---

# PR screenshots and videos

Every UI-affecting PR should carry visual evidence: screenshots for static changes,
a short video for interactive flows. Reviewers, CS, and future readers should see
the change without checking out the branch. The pipeline is:

1. **Capture** with the `agent-browser` CLI (screenshots and WebM recordings).
2. **Upload** to GitHub with the `gh-image` CLI extension (GitHub has no public API
   for attachments; `gh-image` replicates the web UI's upload and returns a
   `github.com/user-attachments` URL that inherits the repo's visibility).
3. **Embed** the returned markdown into the PR description or a comment.

## Prerequisites — check, then only fix what fails

```bash
gh auth status                     # gh CLI installed & authenticated
gh extension list | grep -q 'drogers0/gh-image' || gh extension install drogers0/gh-image
command -v agent-browser >/dev/null || npm install -g agent-browser
```

`gh-image` does **not** use the `gh` token for the upload (that endpoint rejects
tokens) — it needs a GitHub browser session:

- Local use: it reads the `user_session` cookie from a logged-in browser
  (Chrome/Brave/Edge/Firefox/Safari/…). On macOS the first read may show a Keychain
  prompt — the user should click **Always Allow**.
- CI / headless: set `GH_SESSION_TOKEN` (use a dedicated bot account — a session
  cookie grants full account access; treat it like a password).

## Step 1 — Capture

Run the app (local dev server or preview environment), then drive it with
agent-browser. Save captures to an absolute path in a scratch/temp directory — never
commit them to the repo.

### Screenshots

```bash
agent-browser open http://localhost:3000/orders
agent-browser snapshot -i                         # find elements, interact as needed
agent-browser screenshot /tmp/orders-after.png
agent-browser screenshot /tmp/orders-full.png --full   # full page
```

For **before/after** pairs: capture "before" on the base branch (or production) and
"after" on your branch, using the same viewport and the same screen state so the
diff is honest.

Mobile evidence for responsive work: set a phone-sized viewport before capturing
(e.g. `agent-browser set viewport 320 640`), then repeat at desktop width.

### Videos (interactive flows)

```bash
agent-browser record start /tmp/checkout-flow.webm http://localhost:3000/checkout
# ...drive the flow: snapshot -i, click, fill, wait...
agent-browser record stop        # stops and saves the WebM
```

Record one focused flow per video — a reviewer should understand it in under a
minute. If GitHub rejects the WebM upload, convert to MP4 first:

```bash
ffmpeg -i /tmp/checkout-flow.webm -c:v libx264 -pix_fmt yuv420p /tmp/checkout-flow.mp4
```

## Step 2 — Upload

```bash
# One or more files; --repo optional inside a repo working dir (inferred from the remote)
gh image /tmp/orders-before.png /tmp/orders-after.png --repo owner/repo
```

`gh image` prints one embeddable reference per file to stdout:

- Images → `![name](https://github.com/user-attachments/assets/<uuid>)`
- Videos → a bare URL (GitHub renders it as an inline player)
- Other files (PDF, zip, log) → `[name](url)` download link

Capture that output — it is what you embed. Uploads to a private repo stay private
(the URL renders only for authorized viewers; an anonymous fetch 404s — expected).

## Step 3 — Embed into the PR

`gh-image` only prints the markdown; you embed it. Always pipe through
`--body-file -` so multi-line bodies and special characters can't break quoting.

**Append to the PR description** (preserves the existing body):

```bash
MD="$(gh image /tmp/orders-before.png /tmp/orders-after.png)"
BODY="$(gh pr view <pr> --json body -q .body)"
printf '%s\n\n## Screenshots\n\n%s\n' "$BODY" "$MD" | gh pr edit <pr> --body-file -
```

**Or post as a PR comment:**

```bash
printf '## Screenshots\n\n%s\n' "$MD" | gh pr comment <pr> --body-file -
```

Presentation patterns:

- **Before/after** side by side in a table:

  ```markdown
  | Before | After |
  |---|---|
  | ![before](url1) | ![after](url2) |
  ```

- **Control display size** with an HTML tag instead of bare markdown:

  ```html
  <img width="800" alt="orders page" src="https://github.com/user-attachments/assets/<uuid>" />
  ```

- Label every capture (page, viewport, state) so the reader doesn't have to guess.

## Step 4 — Verify

```bash
gh pr view <pr> --json body -q .body   # confirm the user-attachments URLs are present
```

## Conventions

- **Any PR that changes UI gets at least one screenshot**; interactive behavior
  (dialogs, drag-and-drop, multi-step flows) gets a video.
- Responsive changes show **mobile (~320px) and desktop** captures.
- Captures live in temp directories and are uploaded — never committed to git.
- Screenshots of real environments must not expose real user data, credentials, or
  secrets — use dev/seed accounts.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `<org> enforces SAML SSO and your session is not authorized…` | Open `https://github.com/orgs/<org>/sso` in a browser, authorize (~24h), retry. Write access alone is not enough. |
| `uploadToken not found … do you have write access?` | Confirm write access; if the org uses SSO, authorize at the SSO URL and retry. |
| No `user_session` cookie found | Log into GitHub in a supported browser, or set `GH_SESSION_TOKEN`. |
| CI / headless run | Set `GH_SESSION_TOKEN` (dedicated bot account); the browser cookie path won't exist. |
| Video won't upload / render | Convert WebM to MP4 with ffmpeg (see Step 1) and re-upload. |
