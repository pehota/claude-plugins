# nudges

Claude Code plugin with one `UserPromptSubmit` hook that nudges me about three habits.

| Pattern | Fires when the prompt | Nudge |
|---|---|---|
| `challenge` | says "per recs" or "go with (your / the) recs" | Which rec would you challenge, and why? |
| `rule-budget` | names `MY_RULES`, `ME.md`, `ME_VOICE.md`, `CLAUDE.md`, "add a rule" or "new rule" | `MY_RULES` line count vs. the 188-line budget: replace a rule, or enforce it in code? |
| `limits` | asks to implement, fix, build, add, refactor or create, without stop, until, commit, max, only, don't or do not | No stop point stated: where should it stop, and how many review rounds? |

Matching is case-insensitive and word-bounded (`address` is not `add`).

## Behaviour

- **Once per day per pattern.** A fired pattern writes today's date to `<pattern>.last` and appends `<date>\t<pattern>` to `hits.tsv`.
- **Visible.** A fired nudge shows as a `systemMessage`, and `additionalContext` asks Claude to open its reply with `> **Nudge:** ...`.
- **Typed prompts only.** Prompts that start with `Another Claude session sent a message`, `<agent-message`, `<task-notification` or `<cross-session-message` (subagent hand-backs, notifications) are ignored: no output, no stamp, no hit.
- **Never blocks.** No `decision` or `continue` field; any error exits 0 silently.

## State

Local only, in `~/.local/state/claude-nudges/`: `<pattern>.last` and `hits.tsv`.

## Environment overrides

| Variable | Default | Use |
|---|---|---|
| `NUDGE_STATE_DIR` | `~/.local/state/claude-nudges` | State directory |
| `NUDGE_RULES_FILE` | `~/.claude/MY_RULES.md` | File counted by `rule-budget`; missing file skips the pattern |
| `NUDGE_TODAY` | `date +%F` | Date used for once-per-day and `hits.tsv` |

## Tests

```
bash plugins/nudges/tests/test-nudge.sh
```

Requires `jq`.

## Install

From the marketplace:

```
/plugin marketplace add pehota/claude-plugins
/plugin install nudges@pehota-plugins
```

To try it from a checkout without installing, load the plugin directory for one session:

```
claude --plugin-dir <path-to>/plugins/nudges
```

If you registered the old manual hook (`~/.claude/nudges/nudge.sh` under `hooks.UserPromptSubmit` in `~/.claude/settings.json`), remove it. Its `[ -e … ] || exit 0` guard makes it a no-op once `chezmoi update` has deleted `~/.claude/nudges/`, but until then both hooks can show the same nudge.
