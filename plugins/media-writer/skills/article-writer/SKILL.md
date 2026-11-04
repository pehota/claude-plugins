---
name: article-writer
description: Write a first-person technical blog post (dev.to, Hashnode, personal blog) about something the user actually built, such as a homelab setup, an automation, a script or a migration. Use whenever the user asks to write, draft, outline or "turn this into" an article, post or write-up from a project or session, or asks to audit, humanize, restructure or fact-check an existing article draft, even if they never say "article". Covers voice matching (a story, never a sales pitch, no emojis), anonymising, fact-checking against the real work, tone calibration, structure, search-aware titles and hooks, and an optional X teaser. Shares its truth, voice and style rules with the x-post-writer skill.
---

# Article writer

Turn a real project into a post the author is happy to publish under their name. The reader is a practitioner who wants to reproduce the setup or avoid its mistakes. The author is the one who put in the work, so every sentence has to be something they can stand behind.

## Shared rules: read first

Before drafting, read `../../_shared/builder-voice.md`. It holds the rules this skill and x-post-writer both follow (truth tracing, opinions, anonymity, voice, style, handoff, shared final check). It is one file so the two writers keep one source of truth. Everything below is specific to articles.

## Workflow

1. **Gather the sources.** The conversation, the repo docs, measured numbers, and the author's earlier posts (see the voice-source rule in the shared file).
2. **Settle anonymity before drafting**, per the shared file.
3. **Silent audience and keyword prep.** Work out who the reader is and the exact phrases they would type into a search engine. Let that shape the title, the description and the dev.to tags. Do not print this analysis, the user wants the article, not homework.
4. **Outline, then draft** with the structure below and the hook discipline.
5. **Fact audit.** Walk the draft claim by claim against the sources. Remove or fix whatever has no source. Mark what was inferred.
6. **Overstatement audit.** Read for tone that is bigger than the project. See "Tone".
7. **Pattern pass.** Apply the shared style rules and the article-specific ones below. Do it internally, show only the final text unless the user asks to see drafts.
8. **Format pass.** Make the headings a real hierarchy. If the user asks for a formatting-only change, don't touch wording, and prove it by diffing the non-heading lines before and after.
9. **Deliver.** Save a markdown file with dev.to front matter and `published: false`. Give the full path (the scratchpad is temporary, offer to move it). Add the handoff list from the shared file.
10. **Offer an X teaser (optional).** Ask whether the author wants a post on X for the finished article. If yes, use the `x-post-writer` skill with the finished article as the verified source, and put the article link in the reply block as that skill describes.

## Structure that matches the author's style

```
front matter (title, published: false, description, tags)
hook: the personal problem in 3 to 5 short paragraphs, then one line on what the post covers
## Contents            nested list matching the headings
## Overview
### The idea           generalise the concept first (who has this problem, why it recurs)
### What you end up with   an ASCII flow diagram and 2 to 3 sentences
### Tech stack         one table: layer, what I used, used for
## The setup
### Step N: <action>   numbered, each with its own code, **Gotcha:** callouts next to the step
                       they apply to, and a closing **Verify it worked:**
## Running it
### What it costs      measured, then extrapolated, as a table; state the assumptions
### Testing
### Troubleshooting    table: symptom, cause, fix; mark rows the author hasn't hit
## Retrospective
### What I learned
### What I would change   include real mistakes, including documentation or assumptions that turned out wrong
```

Horizontal rules only between the top-level sections. Headings in sentence case. Keep **Gotcha:** and **Verify it worked:** bold, they are the author's signature, but don't bold list lead-ins elsewhere.

## Hook discipline

Most readers decide in the first screen, so the hook has to carry the post.

- The first line states the problem or the result. A reader who stops after it should know what the post is about.
- Keep hook paragraphs short, one to three sentences, so the hook scans on a phone.
- Put the search phrases from the silent prep in the title, the description and naturally in the hook. No keyword stuffing, the text still has to read like the author.

## Tone

A homelab automation is not surgery. Write the result and what it means, not how it felt.

- Instead of "which was a relief", state the finding and its consequence: "every image was different, which shows the snapshots come from live broadcasts".
- Cut superlatives and drama: "the cheapest design decision", "poison the series", "makes the chart lie", "the part I almost skipped".
- Keep the dry, plain first person. Short sentences, one idea each, a little humour only where the author's earlier posts have it.
- Say what a measurement shows, then stop. Don't add a slogan afterwards.

## No calls to action

This is a decision for the article medium. No "follow for more", "let me know in the comments", "stay tuned", "what do you think?", no newsletter or product plug. A plain note that the repo or config is available is fine, if the author offers it. (The X teaser is a separate piece and follows its own rules.)

## Article-specific style rules

These add to the shared style rules.

- Don't repeat the same promise twice ("numbers" then "a time series").
- End on the practical part, or on "what I would change".
- Code in the post is trimmed and renamed. Say that it is, and make sure no real ids, hosts or secrets remain.

## Content principles that made the last article better

- **Generalise first.** Open on the pattern anyone shares (people travelling at peak times, wanting data), then show this implementation as one instance.
- **Separate what the model or tool reports from what the code decides**, and explain why a choice was made, not only what was done.
- **Failures are material.** Include what broke, the exact symptom and the fix, next to the step where it applies.
- **Say what was verified and what wasn't.** "Tested offline only", "not observed at night", "unproven until the first real run".
- **Look at the data before designing around it.** If the project taught that lesson, say it in "what I would change".
- **Costs get a table**: unit price from real spend, count per window, total, and a suggested safety limit.

## Final check before handing over

Run the shared final check in `../../_shared/builder-voice.md`, then these:

- Anything bigger in tone than the project?
- Any call to action or emoji?
- Does the first line carry the post, and are the hook paragraphs short?
- Title, description and tags reflect the reader's search phrases?
- Hierarchy clean, Contents matching the headings and anchors?
- A short handoff list for the author of what to double-check.
