# Claude Code status line

A cheap status line for Claude Code: model, context use, 5-hour and weekly usage with reset timers, git branch.

```
Model: Sonnet 5.5 | Ctx: 27.0% | Sess: 17.0% (1hr 45m)                    Weekly: 22.0% (4d 0hr 56m)
𖠰 main
```

| Segment | Meaning |
|---|---|
| `Ctx` | Context window used. Yellow from 50%, red from 65% |
| `Sess` | 5-hour usage window, with the time until it resets. Yellow from 50%, orange from 75%, red from 90% |
| `Weekly` | 7-day usage window, with the time until it resets. Same colours as `Sess` |
| `𖠰 <branch>` | Git branch of the session's directory, in magenta (the colour fish's prompt uses for the branch) |

Labels (`Model:`, `Ctx:`, `Sess:`, `Weekly:`) are dim; only the value carries the warning colour.

## Why a script and not a Node status line

Claude Code sends everything on stdin as JSON, including `rate_limits`, so nothing needs an API call.
A Node status line (`ccstatusline` with `refreshInterval: 10`, 8 sessions) started a Node process per
session every 10 seconds: about 148 ms and 165 ms of CPU per run, one-second single-core turbo bursts,
package temperature of 70-80°C on an idle headless laptop. This script runs in about 32 ms
(`bash` + `jq` + `git`) and only when Claude Code asks for an update.

## Install

```bash
jq '.statusLine = {"type":"command","command":"'"$PWD"'/statusline.sh","padding":0}' \
  ~/.claude/settings.json > /tmp/settings.json && mv /tmp/settings.json ~/.claude/settings.json
```

Run it from this directory. Needs `bash`, `jq` and `git`. Do not set `refreshInterval`: it re-runs the
command on a timer in every session.

## Behaviour

- **Data:** `rate_limits` exists only for claude.ai Pro, Max and Ultra, and only after a session's first
  API response. A fresh session shows no `Sess` and `Weekly` until its first reply.
- **When it runs:** after each assistant message, after `/compact`, on permission mode changes, and when a
  limit window passes its reset time (debounced 300 ms). An idle session runs nothing.
- **Layout follows the terminal width** (`COLUMNS`, which Claude Code sets):
  one row when everything fits, `Weekly` pushed to the right edge; otherwise `Weekly` moves to the
  branch row; below the width of `Ctx` and `Sess` alone, the model name is dropped.
- **Right margin:** 6 columns stay free (`STATUSLINE_MARGIN`). With 2, Claude Code cut a full-width row
  short with an ellipsis and `Weekly` lost its last characters.
- **Resizing:** Claude Code does not re-run the status line when the window is resized. A shrunk window
  keeps the old layout until the next update.
- **Under herdr:** every client of a session gets the same pane size, so all clients see the same layout.

## Tests

```bash
bash tools/statusline/statusline.test.sh   # all PASS
```

Covers the reset-time format, percent format, colour thresholds, dim labels, the magenta branch, layout at wide, medium, narrow and
unknown widths (including the exact fit boundary), missing `rate_limits`, and the git branch row.
