# Builder voice: rules both writers follow

Read this before drafting anything, whether it is a long article or a 280-character post. These rules live in one file so the article writer and the X post writer cannot drift apart.

## 1. The one rule: every claim traces to a source

**Every claim must trace to the session, the repo, or something the author told you.** If you can't point to the line, the measurement or the message it came from, leave it out. Readers can't tell an invented detail from a real one, but the author can, and one fake detail costs them their credibility.

Invented details to watch for:
- anecdotes and sources ("a forum post from 2019")
- durations and effort ("cost me a few minutes", "twenty minutes of work")
- reactions and feelings ("which was a relief", "I almost skipped this")
- measured-sounding facts nobody measured (a refresh rate, "runs in a second")
- plausible scenarios presented as experienced ("a model will happily rate a poster as an empty road")

When a number is derived, say so: "I didn't count the calls exactly, roughly 85, so call it 0.05 cents per call". When something was not tested or not observed, say that too ("tested offline only", "not observed at night").

## 2. Opinions

An opinion or claim about the niche must come from the source or from the author, or be flagged for the author to confirm. Do not invent a stance and attribute it to them. A made-up hot take is as much a fabrication as a made-up number.

## 3. Anonymity

Settle before drafting what must not appear. Typical leaks: names, places, countries and routes that reveal where someone lives or travels, hostnames, IPs, entity ids with place names, token or key names, exact travel dates. Generalise them (Crossing A, "a country with staggered school holidays"). Keep real measurements such as costs and counts, they are useful and harmless.

For any screenshot or code snippet, remind the author to scrub the same things. Code is trimmed and renamed, and the text says so.

## 4. Voice: a story, not a pitch

First person, a builder telling what they built and what happened. It is not a product page, a consulting deck or a LinkedIn post. A reader who smells selling stops trusting the technical content too.

- **No selling words.** Cut powerful, seamless, game-changing, game-changer, unlock, supercharge, leverage, robust, scalable, best practice, production-grade, end-to-end solution, empower, streamline, revolutionize, delve, "take X to the next level".
- **No consultant framing.** No "key takeaways", "value proposition", "ROI", "actionable insights", "here's how you can", "in today's fast-paced world". Say what you did and let readers decide if it applies to them.
- **No advice-giver stance.** Prefer "I did X because Y" over "you should do X". Opinions and lessons stay in first person.
- **Don't oversell the author or the project.** No "my elegant solution", "a clever trick". If it was a workaround, call it a workaround.
- **No emojis by default.** A skill may name its own exception.

Coffee test: read a sentence out loud as the author talking to a friend over coffee. If a friend would raise an eyebrow, rewrite it.

## 5. Style rules against the AI-draft feel

- No em dashes. Use commas, periods or parentheses.
- No "not X, not Y, a Z" setups, no staccato runs of fragments, no pitch rhythm. If a sentence exists to sound punchy, rewrite it as the plain fact.
- **No self-answered questions.** Don't ask and answer in the next breath ("The catch? It costs money"). It is a copywriter's trick for manufacturing a beat. Write the statement. The same goes for a bare label with a colon-reveal used as a punchline and for rhetorical questions the text then resolves. A real question the reader would actually ask is fine.
- No forced triples and no tidy lists that restate the next paragraph.
- No generic closers or "future looks bright" endings.
- Prefer "is/has" over "serves as/boasts".

Run the humanizer skill (`anthropic-skills:humanizer`) if it is available. Do it internally and show only the final text.

## 6. Voice source

Ask for 1 to 2 links to the author's earlier writing, fetch them and note the voice. Summaries are enough. If the author has none, carry on without them.

## 7. Handoff

After the draft, list the few things the author should double-check: claims taken on their say-so, opinions to confirm, and anything they may not want public.

## 8. Shared final check

- Is every sentence traceable to a source?
- Any invented feeling, duration, anecdote or number?
- Any selling words or consultant phrasing?
- Any self-answered question?
- Any PII or real ids left (text, screenshots, snippets)?
