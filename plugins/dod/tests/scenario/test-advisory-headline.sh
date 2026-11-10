#!/bin/bash
#
# Scenario: in /dod:verify's pending-decision outcome (all pass, advisories,
# no decisions recorded) the user-facing message leads with ONE verdict line
# (advisory count + "Rec:" fix/skip recommendation + the deciding reason),
# and the pass table and the advisory table come last, under a "Detail"
# heading. After a long wait a big table gets skimmed and rubber-stamped;
# the verdict line is what the user acts on.
#
#   (headline) a passing round with 4 advisories, one clearly worth fixing:
#          the first non-empty line names the count (4), "Rec:" and at least
#          one advisory id; a "Detail" heading exists; no table row comes
#          before it; every advisory id appears in a table row after it.
#
# Usage: bash dod/tests/scenario/test-advisory-headline.sh [DOD_VERIFY_SKILL_PATH]
#        bash dod/tests/scenario/test-advisory-headline.sh --self-check
#   --self-check feeds assert_headline canned replies (no model call) to prove
#   each first-line assertion rejects a line missing its part.

DIR0="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR0/scenario-helpers.sh"
SELF_CHECK=0
[ "${1:-}" = "--self-check" ] && { SELF_CHECK=1; shift; }
SKILL="${1:-$DIR0/../../skills/dod-verify/SKILL.md}"

SYS=$(mktemp)
trap 'rm -f "$SYS"' EXIT
{
  echo "You are the root (orchestrating) agent in a Claude Code session. An open DoD"
  echo "contract exists and the implementation is back from the subagents. You are"
  echo "now executing this skill:"
  echo
  # A fixture's leading <!-- … --> header is test metadata, not skill text.
  awk '!started && /^<!--/ { inc = 1 } inc { if (/-->/) { inc = 0; started = 1 } next } { started = 1; print }' "$SKILL"
} > "$SYS"

PROMPT_HEADLINE=$(cat <<'EOF'
Situation (you have no tools in this exercise — describe, don't execute):

The task: add a --dry-run flag to a backup script. Contract baseline_sha is
base01. No decisions are recorded in .dod/<task>/state.json ("decisions":[]).
Steps 1-7 are done: the diff hash is h2; the "tests" check (`bash test.sh`)
PASSED (exit 0); the "lint" check (`shellcheck backup.sh`) PASSED (exit 0).

When dod-reviewer was spawned this round it returned exactly this final message:
{"findings":[
  {"id":"a1","severity":"advisory","file":"backup.sh","line":10,"summary":"log prefix differs from the rest of the script","failure_scenario":"none, cosmetic","requirement_id":"review"},
  {"id":"a2","severity":"advisory","file":"lib/paths.sh","line":20,"summary":"helper name `mkp` is vague","failure_scenario":"none, readability","requirement_id":"review"},
  {"id":"a3","severity":"advisory","file":"backup.sh","line":88,"summary":"--dry-run exits 1 when there is nothing to back up","failure_scenario":"a cron job running backup.sh --dry-run on an empty source reports failure every night, so a healthy setup looks broken","requirement_id":"review"},
  {"id":"a4","severity":"advisory","file":"README.md","line":7,"summary":"flag list is not alphabetical","failure_scenario":"none, cosmetic","requirement_id":"review"}
],"verdict":"pass"}

Write the exact message you send the user at the end of this turn (step 8),
verbatim, as Markdown. Reply with ONE JSON object and nothing else:
{"user_message": "<the exact Markdown message, newlines as \n>"}
EOF
)

IDS="a1 a2 a3 a4"

# assert_headline — reads the model's JSON reply on stdin. Prints the
# message's first non-empty line to stderr (for the run log), and on failure
# prints the reason and returns 1.
assert_headline() {
  local reply msg first rec_part detail_line pre post id
  reply=$(cat)
  msg=$(printf '%s' "$reply" | jq -er '.user_message' 2>/dev/null) || { echo "reply has no user_message string"; return 1; }

  first=$(printf '%s\n' "$msg" | awk 'NF { print; exit }')
  echo "    first line: $first" >&2
  # The count as a count ("4 advisories"), so the id a4 cannot stand in for it.
  printf '%s' "$first" | grep -Eiq '\b4 advisor(y|ies)\b' || { echo "first line lacks the count '4 advisories'"; return 1; }
  printf '%s' "$first" | grep -q 'Rec:' || { echo "first line lacks 'Rec:'"; return 1; }
  printf '%s' "$first" | grep -Eq '\ba[1-4]\b' || { echo "first line names no advisory id"; return 1; }
  # The deciding reason: after the Rec clause a separator (— ; .) followed by
  # more text, naming the consequence of a3, the one advisory worth fixing.
  rec_part=$(printf '%s' "$first" | sed 's/^.*Rec://')
  printf '%s' "$rec_part" | grep -Eq '(—|;|\.)[[:space:]]*[^[:space:]]' || { echo "first line has no reason after the Rec clause"; return 1; }
  printf '%s' "$rec_part" | grep -Eiq 'cron|exit|fail|broken|dry-run' || { echo "first line's reason does not name a3's consequence"; return 1; }

  detail_line=$(printf '%s\n' "$msg" | grep -nE '^[[:space:]]*#+[[:space:]]*Detail[[:space:]]*$' | head -n 1 | cut -d: -f1)
  [ -n "$detail_line" ] || { echo "no 'Detail' heading"; return 1; }

  pre=$(printf '%s\n' "$msg" | head -n $((detail_line - 1)))
  post=$(printf '%s\n' "$msg" | tail -n +$((detail_line + 1)))
  if printf '%s\n' "$pre" | grep -Eq '^[[:space:]]*\|'; then
    echo "a table row appears before the Detail heading"; return 1
  fi
  for id in $IDS; do
    printf '%s\n' "$post" | grep -E '^[[:space:]]*\|' | grep -Eq "\b$id\b" \
      || { echo "advisory $id is not in a table row after Detail"; return 1; }
  done
}

# headline__canned_reply <first line> — a full reply whose body passes every
# non-first-line assertion, so only the first line decides the outcome.
headline__canned_reply() {
  local msg
  msg="$1"$'\n\nReply fix or skip per id.\n\n## Detail\n\n| Requirement | Verdict |\n|---|---|\n| tests | pass |\n\n| id | file:line | summary | rec |\n|---|---|---|---|\n| a1 | backup.sh:10 | x | skip |\n| a2 | lib/paths.sh:20 | x | skip |\n| a3 | backup.sh:88 | x | fix |\n| a4 | README.md:7 | x | skip |'
  jq -nc --arg m "$msg" '{user_message: $m}'
}

# headline__expect <PASS|FAIL> <first line>
headline__expect() {
  local want="$1" line="$2" got reason
  if reason=$(headline__canned_reply "$line" | assert_headline 2>/dev/null); then got=PASS; else got=FAIL; fi
  if [ "$got" = "$want" ]; then
    echo "  ok   want $want: $line${reason:+ ($reason)}"
  else
    echo "  BAD  want $want, got $got: $line"; return 1
  fi
}

if [ "$SELF_CHECK" = 1 ]; then
  fail=0
  echo "== self-check: assert_headline on canned first lines =="
  headline__expect FAIL 'Rec: fix a3, skip a1 a2 a4.' || fail=1
  headline__expect FAIL '4 advisories. Rec: fix a3, skip the rest.' || fail=1
  headline__expect FAIL 'Rec: fix a4, skip the rest — a4 makes cron look broken.' || fail=1
  headline__expect FAIL '4 advisories. Rec: fix a3, skip the rest — a3 is untidy.' || fail=1
  headline__expect PASS '4 advisories. Rec: fix a3, skip the rest — a3 makes a nightly cron --dry-run look broken.' || fail=1
  headline__expect PASS '4 Advisories. Rec: fix a3, skip a1, a2 and a4. a3 makes --dry-run exit 1 on an empty source.' || fail=1
  exit $fail
fi

fail=0
echo "== scenario (headline): pending-decision message leads with the verdict line, tables under Detail ($SKILL) =="
scenario_run assert_headline "$SYS" "$PROMPT_HEADLINE" || fail=1
exit $fail
