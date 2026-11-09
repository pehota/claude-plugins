#!/bin/bash
#
# Tests for nudges/hooks/nudge.sh. Run: bash plugins/nudges/tests/test-nudge.sh

DIR0="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUDGE="$DIR0/../hooks/nudge.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILS=0
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

RULES="$WORK/rules.md"
printf 'a\nb\nc\n' >"$RULES"

# run_nudge <prompt> [day]: sets OUT and CODE. State dir is $WORK/state.
run_nudge() {
  local prompt="$1" day="${2:-2026-01-01}"
  OUT="$(jq -n --arg p "$prompt" '{prompt:$p,hook_event_name:"UserPromptSubmit"}' |
    NUDGE_STATE_DIR="$WORK/state" NUDGE_RULES_FILE="$RULES" NUDGE_TODAY="$day" bash "$NUDGE")"
  CODE=$?
}
fresh_state() { rm -rf "$WORK/state"; }

assert_fires() { # name prompt text-fragment
  fresh_state; run_nudge "$2"
  [[ $CODE -eq 0 ]] || fail "$1: exit $CODE"
  [[ "$OUT" == *"$3"* ]] || fail "$1: expected '$3' got '$OUT'"
}
assert_silent() { # name prompt
  fresh_state; run_nudge "$2"
  [[ $CODE -eq 0 ]] || fail "$1: exit $CODE"
  [[ -z "$OUT" ]] || fail "$1: expected silence got '$OUT'"
}

# challenge
assert_fires "per recs" "ok per recs" "Which one would you challenge"
assert_fires "go with recs" "go with recs" "challenge"
assert_fires "go with your recs" "go with your recs" "challenge"
assert_fires "go with the recs" "go with the recs" "challenge"
assert_fires "case-insensitive" "PER RECS" "challenge"
assert_silent "challenge non-match" "what are the recs for dinner"

# rule-budget
for p in "look at MY_RULES" "open ME.md" "see ME_VOICE.md" "update CLAUDE.md" "add a rule" "a new rule"; do
  assert_fires "rule-budget: $p" "$p" "MY_RULES is 3 lines (budget 188)"
done
assert_fires "rule-budget lowercase" "my_rules tweak" "MY_RULES is 3 lines"
assert_silent "rule-budget non-match" "tell me about rules of chess"
printf 'a\nb\nc\nd\ne\n' >"$RULES"
assert_fires "rule count follows fixture" "look at MY_RULES" "MY_RULES is 5 lines"
printf 'a\nb\nc\n' >"$RULES"
RULES_BAK="$RULES"; RULES="$WORK/missing.md"
assert_silent "missing rules file skips rule-budget" "look at MY_RULES"
RULES="$RULES_BAK"

# limits
assert_fires "limits verb" "please implement the thing" "no stop point stated"
for v in fix build add refactor create; do
  assert_fires "limits verb $v" "$v the thing" "no stop point stated"
done
assert_silent "limits: 'address' is not 'add'" "what is my address"
assert_silent "limits: 'fixture' is not 'fix'" "show the fixture"
for s in stop until commit max only "don't" "do not"; do
  assert_silent "limits stop word '$s'" "implement the thing, $s later"
done

# once per day
fresh_state
run_nudge "per recs" "2026-01-01"; [[ -n "$OUT" ]] || fail "once-a-day: first call silent"
run_nudge "per recs" "2026-01-01"; [[ -z "$OUT" ]] || fail "once-a-day: second call same day fired"
run_nudge "per recs" "2026-01-02"; [[ -n "$OUT" ]] || fail "once-a-day: new day silent"
[[ "$(cat "$WORK/state/challenge.last")" == "2026-01-02" ]] || fail "stamp file not updated"

# hits.tsv
fresh_state
run_nudge "per recs" "2026-03-03"
printf '2026-03-03\tchallenge\n' | cmp -s - "$WORK/state/hits.tsv" || fail "hits.tsv content: $(cat "$WORK/state/hits.tsv" 2>&1)"
run_nudge "per recs" "2026-03-04"
[[ "$(wc -l <"$WORK/state/hits.tsv" | tr -d ' ')" == "2" ]] || fail "hits.tsv not appended"

# multiple patterns joined, valid JSON, systemMessage + additionalContext, never blocking
fresh_state
run_nudge "implement it per recs"
[[ "$OUT" == *" | "* ]] || fail "multi: not joined with ' | ': $OUT"
[[ "$(jq -c 'keys' <<<"$OUT")" == '["hookSpecificOutput","systemMessage"]' ]] || fail "output keys: $OUT"
[[ "$(jq -r '.systemMessage' <<<"$OUT")" == Nudge:*" | Nudge:"* ]] || fail "multi text: $OUT"
[[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$OUT")" == "UserPromptSubmit" ]] || fail "hookEventName: $OUT"
[[ "$(jq -c '.hookSpecificOutput | keys' <<<"$OUT")" == '["additionalContext","hookEventName"]' ]] || fail "hookSpecificOutput keys: $OUT"
[[ "$(jq -c '[.. | objects | keys[] | select(. == "decision" or . == "continue" or . == "stopReason")]' <<<"$OUT")" == '[]' ]] || fail "blocking keys present: $OUT"

# additionalContext tells Claude to open its reply with the nudge line
fresh_state
run_nudge "ok per recs"
EXPECTED_CONTEXT="The user asked to be nudged about a habit. Start your reply with exactly this line, then answer the prompt normally: > **Nudge:** accepting all recs. Which one would you challenge, and why?"
[[ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$OUT")" == "$EXPECTED_CONTEXT" ]] || fail "additionalContext: $OUT"
[[ "$(jq -r '.systemMessage' <<<"$OUT")" == "Nudge: accepting all recs. Which one would you challenge, and why?" ]] || fail "systemMessage text: $OUT"

# prompts not typed by the user (hand-backs, notifications) are ignored: no output, no stamp, no hit
HANDBACK=$'Another Claude session sent a message:\n<agent-message from="ad082fd3e566eed83">\n[Subagent hand-back] done per recs, implement next\n</agent-message>'
for framed in "$HANDBACK" \
  '<agent-message from="x">per recs</agent-message>' \
  '<task-notification>implement it per recs</task-notification>' \
  '<cross-session-message from="y">per recs</cross-session-message>' \
  $'  \n\t<task-notification>per recs</task-notification>'; do
  assert_silent "ignored framing: ${framed:0:30}" "$framed"
  [[ ! -e "$WORK/state/challenge.last" ]] || fail "ignored framing stamped: ${framed:0:30}"
  [[ ! -s "$WORK/state/hits.tsv" ]] || fail "ignored framing logged a hit: ${framed:0:30}"
done
assert_fires "framing text later in a typed prompt still fires" "per recs, see <task-notification> above" "challenge"
assert_fires "typed per recs still fires" "per recs" "challenge"

# robustness
fresh_state
for input in "" "not json" '{"prompt":' '{"nope":1}' '[]' '{"prompt":42}'; do
  OUT="$(printf '%s' "$input" | NUDGE_STATE_DIR="$WORK/state" NUDGE_RULES_FILE="$RULES" bash "$NUDGE")"
  CODE=$?
  [[ $CODE -eq 0 ]] || fail "bad input '$input': exit $CODE"
  [[ -z "$OUT" ]] || fail "bad input '$input': output '$OUT'"
done

if [[ $FAILS -ne 0 ]]; then echo "nudge.sh: $FAILS test(s) failed"; exit 1; fi
echo "nudge.sh: all tests passed"
