# Web

Use the browser tool this environment has: the T3 Code browser, a browser MCP (Playwright, Chrome, Firefox devtools), or the `agent-browser` CLI. Prefer reading the page structure (accessibility snapshot) to find elements, and screenshots to judge how it looks.

In T3 Code, use its `preview_*` tools: `preview_open` / `preview_navigate` to load the page, `preview_snapshot` to read it, `preview_act` to click and type, `preview_wait_for` before asserting, `preview_resize` and `preview_set_appearance` for screen sizes and dark mode, and `preview_recording_start` / `preview_recording_stop` to record a flow as evidence. Close tabs you opened when done.

With `agent-browser`:

```bash
agent-browser open <url>
agent-browser snapshot                 # accessibility tree with @refs
agent-browser click "@12"              # or a CSS selector
agent-browser fill "input[name=email]" "user@example.com"
agent-browser type "<selector>" "text" # real keystrokes, fires JS handlers
agent-browser wait "<selector>"
agent-browser screenshot <dir>/qa-1-login.png
agent-browser eval "location.href"
```

- **Login:** find where test credentials live in `AGENTS.md`. Never print or commit them.
- **Dynamic pages:** wait for the element you expect before asserting.
- **Errors:** read the console and failed network requests after each flow; an error there is a finding even when the screen looks fine.
- **Evidence:** save screenshots outside the repo with descriptive names, and attach them to the report, or to the PR with the `pr-screenshots-videos` skill.
