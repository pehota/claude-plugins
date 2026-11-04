# media-writer

Claude Code plugin with two skills for writing as a builder.

| Piece | Purpose |
|---|---|
| `skills/article-writer` | First-person technical blog post (dev.to style) from a real project |
| `skills/x-post-writer` | Three X post drafts (Problem-Solver, Visual Teaser, Contrarian) |
| `_shared/builder-voice.md` | Truth, opinion, anonymity, voice and style rules both skills follow |

## How the skills share `_shared/`

Each `SKILL.md` tells the model to read `../../_shared/builder-voice.md` before drafting. The rules live in one file so the article writer and the X post writer cannot drift apart. The article writer can also hand a finished article to the X post writer as a verified source for a teaser.

## Install

From the marketplace:

```
/plugin install media-writer --marketplace pehota/claude-plugins
```

Skills load as `media-writer:article-writer` and `media-writer:x-post-writer`.

To try it from a checkout without installing, load the plugin directory for one session:

```
claude --plugin-dir <path-to>/plugins/media-writer
```

If you also have standalone `article-writer` or `x-post-writer` skills in `~/.claude/skills/`, the names collide and the wrong copy can load. Remove the standalone ones.
