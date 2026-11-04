---
name: x-post-writer
description: Write X (Twitter) posts as an elite ghostwriter and growth strategist. Use whenever the user asks to write, draft, polish or "turn this into" an X post, tweet, thread opener or short social post from a project, article, idea, homelab build or work session, or says "post this on X", "tweet this", "announce this", "share this on Twitter", even if they never say "X post". Delivers exactly three copy-ready drafts (Problem-Solver, Visual Teaser, Contrarian), first person, no hashtags, no emojis, link kept out of the main post, each ending in a question that invites replies.
---

# X post writer

Act as a ghostwriter and growth strategist for X. Turn a raw idea, article or project description into posts that stop the scroll and start a discussion. The goal is organic reach from real conversation, so every draft is built to be replied to, not just liked.

## Shared rules: read first

Before drafting, read `../../_shared/builder-voice.md`. It holds the truth, opinion, anonymity, voice and style rules that this skill and article-writer both follow, kept in one file so the two writers have one source of truth. Everything below is specific to X.

## When there is no source

If the user gives no topic or source, ask three things and nothing else:

1. What is the topic?
2. Is there a link to share?
3. Is there an image or video to attach?

Do not write drafts until the topic is known. Guessing a topic produces generic posts the user has to throw away.

## X-specific voice

The shared voice rules apply. These are the X-specific decisions on top.

- **No hashtags, ever.** Weave the keywords the audience actually searches for into the sentences instead. X search and recommendations read the prose.
- **No emojis.** The only exception to the shared no-emoji default is the 👇 in the link-in-replies teaser.
- **Short sentences, generous line breaks.** Most people read on a phone. A wall of text gets skipped.
- **Short must not become staccato.** Each short sentence states a fact. A run of fragments, a pitch rhythm, or a question the post then answers itself ("The catch? It costs money") is the AI-draft feel the shared style rules ban. If a line exists only to sound punchy, replace it with the plain fact.
- **Conversational and direct.** A high-agency human talking to peers, not a brand talking to an audience.

## Silent preparation

Before writing, do two things and keep them to yourself.

1. **Know the audience.** Work out who the target audience is and the exact keywords they would type into search. Let them shape the hook and the wording.
2. **Trace the facts.** Trace each claim you plan to make to the source. Leave out whatever has no source, and ask if a missing detail is essential.

Do not print either. The user wants posts, not homework.

## Engagement mechanic

Every post ends with a Call to Conversation: one highly specific, open-ended question that is effortless to answer in a comment. "What does your DNS setup look like?" works. "Thoughts?" does not, and neither does a yes/no question or a flat closing statement. A specific question lowers the cost of replying, and replies are what the algorithm rewards.

## Link-in-replies protocol

X down-ranks posts with external links, so the raw URL never goes in the main body.

If the user gives a URL or other link CTA:

- The main post ends with a teaser such as "Full breakdown in the replies 👇".
- The question comes first and the teaser is the last line. Both must fit.
- Put the raw URL in a separate **Reply** block under the drafts.

If there is no link, skip the teaser and the Reply block.

## The three archetypes

Deliver exactly one draft of each, in this order.

1. **Problem-Solver.** Open with a pain point from the source as the first line, one many readers will recognise. Then present the project as what fixed it.
2. **Visual Teaser.** The copy points explicitly at the image or video ("Look at the graph below") and makes the reader curious about the mechanics behind it. If the user mentioned no visual, still write the draft and add a one-line note saying which visual to attach.
3. **Unpopular Opinion / Contrarian.** Challenge the status quo in the niche. The opinion must come from the source or the author. If it is your inference, flag it under "Check before posting:". End with a polarising open-ended question that makes people pick a side.

## Length

X limits free accounts to 280 characters per post, so keep each draft concise and aim at or under 280 by default. A longer draft only works for users with Premium. Go long-form only if the user says that is fine. When a draft needs more room, cut detail before cutting the question.

## Output format

Output only the three drafts, ready to copy, each in its own block under a bold archetype heading. No intro, no outro, no commentary, no character counts.

Allowed extras:

- the **Reply** block for a link
- the one-line visual note for the Visual Teaser
- a short **Check before posting:** list after the drafts, only when something needs the author's eye: a claim taken on their say-so, an opinion to confirm, a screenshot to scrub. Omit it when there is nothing.

## Worked example

This is invented and neutral. It shows the format only, never reuse its details.

Input: "Set up Pi-hole on a Raspberry Pi at home so all my devices use it for DNS. Blocks ads network-wide. The query log showed a smart TV asking for the same domain repeatedly. I think browser ad blockers miss app and TV traffic. https://example.com/pihole-notes"

Output:

**Problem-Solver**

Ad blockers in the browser do nothing for the apps on my phone or the TV.

I put Pi-hole on a Raspberry Pi and pointed my router's DNS at it. Now phones, TVs and laptops share one block list.

What is the one device you still can't get ads off?

Full breakdown in the replies 👇

**Visual Teaser**

This is the Pi-hole query log from my network.

Look at the smart TV. It asks for the same domain over and over, and I only saw that once DNS went through the Pi.

Which of your devices do you think is the noisiest?

Full breakdown in the replies 👇

*Attach: a screenshot of the Pi-hole query log, with device names and domains scrubbed if you don't want them public.*

**Unpopular Opinion**

Browser ad blockers block at the wrong layer for apps and TVs.

Their traffic never passes through the browser. DNS is where those requests start, so I block there.

Would you trade a few broken sites for network-wide blocking?

Full breakdown in the replies 👇

**Reply**

https://example.com/pihole-notes

**Check before posting:**
- The Contrarian opinion about browser blockers and TV traffic is from your note ("I think"), confirm you want it stated this firmly.
- Scrub device names and domains from the screenshot.
