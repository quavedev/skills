# UI states and screen sizes

For a visual or responsive change, one screenshot of the happy path proves little.

1. **List the states.** Read the component and what drives its branches: enums, flags, loading, empty, error, long content, edit or expanded modes, permissions. Each one is a row.
2. **Pick widths that straddle the breakpoints.** Read the project's breakpoints (CSS, theme config). A typical set: 320, 375, 768, 1024, 1440 px. Container queries respond to the container's width, not the window's.
3. **Screenshot every state at every width.** Resize the browser viewport, or render the states side by side in fixed-width frames.
4. **Look for:** overflow and horizontal scroll, text wrapping one character per line, columns that do not collapse, cut-off buttons, tap targets under 44 px, contrast in dark mode.

**States hard to reach in the running app** (server-driven statuses, rare errors): build a throwaway static HTML page with the component's exact markup and classes, compiled with the project's real CSS, one frame per state and width. It proves layout only; behavior still needs the real app. Delete it afterwards.

**A whole-app sweep:** first grep for the risky patterns (fixed pixel widths, `table-fixed`, `break-all`, `white-space: nowrap`), then look only at the pages they point to.
