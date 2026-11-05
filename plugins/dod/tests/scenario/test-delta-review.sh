#!/bin/bash
#
# Scenario (before/after): from round 2 on, /dod:verify's review covers only
# what that round changed — including breakage it causes in untouched code —
# never pre-existing leftovers; and a prior result without a snapshot still
# gets its blocking findings re-checked.
#
# Guards the bug where /dod:verify passed the prior result's diff_hash (a
# content fingerprint, not a commit) as delta_from: no `git diff` could
# resolve it, so every round 2+ silently became a full review.
#
# Each case runs SCENARIO_RUNS times per side (old text vs final text) and
# prints both pass rates; it fails when a rate misses its threshold.
#
#   (a)  leftover excluded. Reviewer, real git repo, delta_reconfirm,
#        delta_from S1 / delta_to S2, reconfirm []. Round 1 adds lib/clamp.sh
#        with an obvious bug (S1); round 2 adds lib/is_even.sh with a
#        different obvious bug (S2). Pass: a non-scope finding on is_even.sh,
#        none on clamp.sh. old = baseline reviewer (<= OLD_MAX), new = final
#        reviewer (>= NEW_MIN).
#   (b2) caused breakage kept. lib/inv.sh's inv_row prints CSV; the unchanged
#        bin/total.sh parses it with `cut -d, -f2`. Round 2 changes inv_row's
#        output format; total.sh's sum breaks — the only symptom. Pass: a
#        non-scope finding anchored to lib/inv.sh that names total.sh.
#        old = final reviewer minus the f2 rule; new = final (>= NEW_MIN, a
#        regression guard). minus-f2 already scored 10/10 here (f2 10/10
#        too), so b2 alone does not justify the f2 rule ("breakage the delta
#        causes in unchanged code is kept, re-anchored to the causing
#        hunk") and old has no ceiling. The rule is kept anyway: (b3) needs
#        it (pre-f2pipe text, without the consumer rule, scored 0/10).
#   (b3) piped consumer breakage kept. bin/export.sh prints CSV; the
#        unchanged bin/summary.sh pipes it into `awk -F,` to sum column 2.
#        Round 2 changes export.sh's output format; summary.sh's total
#        breaks — the only symptom, and no source/call edge links the two.
#        Pass: a non-scope finding anchored to bin/export.sh that names
#        summary.sh. old = reviewer before the impact lens traced output
#        consumers (<= OLD_MAX; it scored 0/10 on this design), new = final
#        reviewer (>= NEW_MIN).
#   (c)  no-snapshot fallback keeps reconfirm (D16). The verify skill as
#        system prompt, tool-less, given a contract-read whose result has
#        snapshot_sha "" and a blocking review finding f1, plus the
#        next_review result_next_review computes for it (delta_reconfirm,
#        reconfirm [f1], delta_from ""); it prints the
#        reviewer input block it would spawn. Pass: mode delta_reconfirm and
#        reconfirm carries f1. old = pre-f1 skill (<= OLD_MAX), new = final
#        skill (>= NEW_MIN).
#
# Old-text fixtures (tests/scenario/fixtures/):
#   dod-reviewer.baseline-e6408a6.md — verbatim
#       `git show e6408a6:plugins/dod/agents/dod-reviewer.md`.
#   dod-reviewer.final-minus-f2.md   — the final reviewer with the f2 rule
#       (delta-caused breakage in unchanged code is kept, re-anchored to the
#       causing hunk) replaced by the earlier "only on hunks inside this
#       delta" rule, in Procedure step 1 and the `findings` self-check. It
#       is the text the f2 decision was measured on; the final reviewer is
#       this text plus later tightenings for case (a): step 1 "even when it
#       visibly breaks works_when"; the self-check runs
#       `git diff <delta_from> <delta_to> -- <file>` per finding; the
#       delta_reconfirm obligations say a file outside the delta gets no
#       non-scope finding; "Be exhaustive" is bounded by the mode's scope.
#   dod-reviewer.pre-f2pipe.md       — derivation in its header comment.
#   dod-verify-SKILL.pre-f1.md       — derivation in its header comment.
#
# Usage: bash plugins/dod/tests/scenario/test-delta-review.sh [case…]
#   cases: a b2 b3 c (default: all). Env: SCENARIO_RUNS (default 10),
#   SCENARIO_VERBOSE=1 prints failing replies.

DIR0="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR0/scenario-helpers.sh"
. "$DIR0/../../lib/gitref.sh"
. "$DIR0/../../lib/result.sh"
SCENARIO_RUNS="${DELTA_RUNS:-10}"
OLD_MAX=2
NEW_MIN=9
B2_OLD_MAX="-"  # f2 dropped: old and new are the same text (see header)
CASES="${*:-a b2 b3 c}"

FIXT="$DIR0/fixtures"
REVIEWER_NEW="$DIR0/../../agents/dod-reviewer.md"
REVIEWER_BASE="$FIXT/dod-reviewer.baseline-e6408a6.md"
REVIEWER_MINUS_F2="$FIXT/dod-reviewer.final-minus-f2.md"
REVIEWER_PRE_F2PIPE="$FIXT/dod-reviewer.pre-f2pipe.md"
SKILL_NEW="$DIR0/../../skills/dod-verify/SKILL.md"
SKILL_PRE_F1="$FIXT/dod-verify-SKILL.pre-f1.md"

WORK=$(mktemp -d)
[ -n "$WORK" ] || { echo "mktemp failed"; exit 1; }
trap 'rm -rf "$WORK"' EXIT

# sys_prompt <md> <out> — the file's body: a leading <!-- … --> fixture
# header and the YAML frontmatter stripped.
sys_prompt() {
  awk '
    !started && /^<!--/ { inc = 1 }
    inc { if (/-->/) inc = 0; next }
    !started && /^---$/ { fm = 1; started = 1; next }
    fm { if (/^---$/) fm = 0; next }
    { started = 1; print }
  ' "$1" > "$2"
}

# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

# fixture_init <dir> — empty repo with git identity and .dod/ ignored.
fixture_init() {
  git init -q -b main "$1"
  git -C "$1" config user.email t@t.t
  git -C "$1" config user.name t
  mkdir -p "$1/lib" "$1/bin"
  printf '.dod/\n' > "$1/.gitignore"
}

REQS='[{"id":"tests","type":"check","cmd":null,"expect_exit":null,"source":"task","applicable":false,"reason":"fixture has no test runner","proves":"n/a: fixture"},{"id":"e2e","type":"check","cmd":null,"expect_exit":null,"source":"task","applicable":false,"reason":"no user-facing flow","proves":"n/a: no user-facing flow"},{"id":"scenario","type":"check","cmd":null,"expect_exit":null,"source":"task","applicable":false,"reason":"review proves works_when","proves":"n/a: review row proves works_when"},{"id":"review","type":"judgement","agent":"dod-reviewer","source":"protocol","proves":"independent check the change is correct and in scope"},{"id":"docs","type":"check","cmd":null,"expect_exit":null,"source":"task","applicable":false,"reason":"no documented behaviour changes","proves":"n/a: no documented behaviour changes"}]'

# delta_prompt <base> <s1> <s2> <task> <works_when>
delta_prompt() {
  cat <<EOF
Inputs:
baseline_sha : $1
mode         : delta_reconfirm
delta_from   : $2
delta_to     : $3
reconfirm    : []
task         : $4
works_when   : $5
requirements : $REQS
brief        : n/a: fixture repo has no context brief
changed_standards : []
depth        : full
EOF
}

# reviewer_model <system_prompt_file> <fixture_dir> <prompt> — one isolated
# headless reviewer run inside the fixture repo (its cwd only; nothing
# confines file paths to it). Allowlisted: Bash `git` (any subcommand — git
# itself can write, so not strictly read-only), `cd`, `echo` and `cat` (the
# reviewer chains them, and every part of a compound command must be
# allowed), plus Read, Grep and Glob. In -p mode any other tool call (other
# Bash commands, `$(...)` substitution, Write/Edit) is denied, not prompted;
# the reviewer retries with plain git commands. Prints the reply's JSON
# object (first line opening with `{` to the last line closing with `}`).
reviewer_model() {
  local out
  out=$(cd "$2" && printf '%s' "$3" | CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 claude -p \
    --model sonnet --tools "Bash,Read,Grep,Glob" --setting-sources "" --strict-mcp-config \
    --disable-slash-commands --no-session-persistence \
    --allowedTools "Bash(git:*)" "Bash(cd:*)" "Bash(echo:*)" "Bash(cat:*)" Read Grep Glob \
    --system-prompt "$(cat "$1")" 2>&1)
  printf '%s\n' "$out" | awk '/^[[:space:]]*\{/ { f = 1 } f { buf = buf $0 "\n" } f && /\}[[:space:]]*$/ { out = buf } END { printf "%s", out }'
}

# skill_model <system_prompt_file> <prompt> — one isolated, tool-less
# headless run (same isolation as scenario_model); prints the whole reply.
skill_model() {
  (cd "${TMPDIR:-/tmp}" && printf '%s' "$2" | CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 claude -p \
    --model sonnet --tools "" --setting-sources "" --strict-mcp-config \
    --disable-slash-commands --no-session-persistence \
    --system-prompt "$(cat "$1")" 2>&1)
}

# assert_json <reply> — the reply is the reviewer's JSON object.
assert_json() {
  printf '%s' "$1" | jq -e 'type == "object" and (.findings | type) == "array"' >/dev/null 2>&1 \
    || { echo "reply is not the reviewer JSON: $(printf '%s' "$1" | head -c 120)"; return 1; }
}

# has_finding <reply> <file_suffix> [<text_regex>] — 0 if a non-scope
# finding's file ends with <file_suffix> (and its summary/failure_scenario
# matches <text_regex>, when given).
has_finding() {
  printf '%s' "$1" | jq -e --arg f "$2" --arg re "${3:-}" '[.findings[] | select(.lens != "scope"
      and ((.file // "") | endswith($f))
      and ($re == "" or (((.summary // "") + " " + (.failure_scenario // "")) | test($re))))] | length > 0' >/dev/null 2>&1
}

# measure <label> <run_fn> <assert_fn> <run args…> — SCENARIO_RUNS runs in
# parallel; prints each failure reason, sets RATE to the pass count.
measure() {
  local label="$1" run="$2" assert="$3" i n=0 reason d
  shift 3
  d="$WORK/runs-$label"; mkdir -p "$d"
  for i in $(seq 1 "$SCENARIO_RUNS"); do
    "$run" "$@" > "$d/$i" 2>&1 &
  done
  wait
  for i in $(seq 1 "$SCENARIO_RUNS"); do
    if reason=$("$assert" < "$d/$i"); then
      n=$((n + 1))
    else
      echo "    $label run $i: $reason"
      [ -n "${SCENARIO_VERBOSE:-}" ] && sed 's/^/      | /' "$d/$i"
    fi
  done
  RATE=$n
}

FAIL=0
# verdict <case> <old_rate> <old_max|-> <new_rate> — prints the rates, checks
# old <= old_max ("-" = no ceiling) and new >= NEW_MIN.
verdict() {
  local ok=1
  [ "$3" = "-" ] || [ "$2" -le "$3" ] || ok=0
  [ "$4" -ge "$NEW_MIN" ] || ok=0
  if [ "$ok" = 1 ]; then echo "  ($1) old $2/$SCENARIO_RUNS new $4/$SCENARIO_RUNS — PASS"
  else echo "  ($1) old $2/$SCENARIO_RUNS new $4/$SCENARIO_RUNS — FAIL (need old <= $3, new >= $NEW_MIN)"; FAIL=1; fi
}

want() { case " $CASES " in *" $1 "*) return 0 ;; esac; return 1; }

# ============================================================== (a)
if want a; then
  FIXA="$WORK/repo-a"
  fixture_init "$FIXA"
  printf '# mathlib\n\nSmall shell math helpers in lib/.\n' > "$FIXA/README.md"
  git -C "$FIXA" add -A && git -C "$FIXA" commit -q -m baseline
  BASE_A=$(git -C "$FIXA" rev-parse HEAD)
  # Round 1: clamp() returns hi when v is below lo (should return lo).
  cat > "$FIXA/lib/clamp.sh" <<'EOF'
#!/bin/bash
# clamp <v> <lo> <hi> — prints v limited to the range [lo, hi].
clamp() {
  local v="$1" lo="$2" hi="$3"
  if [ "$v" -lt "$lo" ]; then
    echo "$hi"
  elif [ "$v" -gt "$hi" ]; then
    echo "$hi"
  else
    echo "$v"
  fi
}
EOF
  S1A=$(dod_snapshot "$FIXA") || { echo "snapshot failed"; exit 1; }
  # Round 2: is_even() succeeds for odd numbers (remainder test inverted).
  cat > "$FIXA/lib/is_even.sh" <<'EOF'
#!/bin/bash
# is_even <n> — exit 0 if n is even, 1 otherwise.
is_even() {
  local n="$1"
  [ $(( n % 2 )) -eq 1 ]
}
EOF
  S2A=$(dod_snapshot "$FIXA") || { echo "snapshot failed"; exit 1; }
  PROMPT_A=$(delta_prompt "$BASE_A" "$S1A" "$S2A" \
    "Add two shell helpers: lib/clamp.sh defining clamp <v> <lo> <hi> (prints v limited to [lo, hi]) and lib/is_even.sh defining is_even <n> (exit 0 if n is even, 1 otherwise)." \
    "It works when clamp 5 10 20 prints 10, clamp 25 10 20 prints 20, clamp 15 10 20 prints 15, is_even 4 exits 0 and is_even 3 exits 1.")

  assert_a() {
    local r; r=$(cat)
    assert_json "$r" || return 1
    has_finding "$r" "is_even.sh" || { echo "no non-scope finding on lib/is_even.sh (the delta's bug missed)"; return 1; }
    ! has_finding "$r" "clamp.sh" || { echo "non-scope finding on lib/clamp.sh (round-1 leftover re-raised)"; return 1; }
  }

  echo "== (a) leftover bug outside the delta is excluded =="
  sys_prompt "$REVIEWER_BASE" "$WORK/sys-rev-base"
  sys_prompt "$REVIEWER_NEW" "$WORK/sys-rev-new"
  measure a-old reviewer_model assert_a "$WORK/sys-rev-base" "$FIXA" "$PROMPT_A"; OLD=$RATE
  measure a-new reviewer_model assert_a "$WORK/sys-rev-new" "$FIXA" "$PROMPT_A"; NEW=$RATE
  verdict a "$OLD" "$OLD_MAX" "$NEW"
fi

# ============================================================== (b2)
if want b2; then
  FIXB="$WORK/repo-b2"
  fixture_init "$FIXB"
  mkdir -p "$FIXB/data"
  printf 'apple 3\npear 2\n' > "$FIXB/data/stock.txt"
  cat > "$FIXB/lib/inv.sh" <<'EOF'
#!/bin/bash
# inv_row <name> <qty> — prints one inventory row.
inv_row() {
  printf '%s,%s\n' "$1" "$2"
}
EOF
  cat > "$FIXB/bin/total.sh" <<'EOF'
#!/bin/bash
# Prints the total number of units in stock.
. "$(dirname "$0")/../lib/inv.sh"
total=0
while read -r name qty; do
  q=$(inv_row "$name" "$qty" | cut -d, -f2)
  total=$((total + q))
done < "$(dirname "$0")/../data/stock.txt"
echo "Total units: $total"
EOF
  cat > "$FIXB/bin/list.sh" <<'EOF'
#!/bin/bash
# Lists every inventory row.
. "$(dirname "$0")/../lib/inv.sh"
while read -r name qty; do
  inv_row "$name" "$qty"
done < "$(dirname "$0")/../data/stock.txt"
EOF
  git -C "$FIXB" add -A && git -C "$FIXB" commit -q -m baseline
  BASE_B=$(git -C "$FIXB" rev-parse HEAD)
  # Round 1: list.sh gets a header line.
  cat > "$FIXB/bin/list.sh" <<'EOF'
#!/bin/bash
# Lists every inventory row.
. "$(dirname "$0")/../lib/inv.sh"
echo "Inventory"
while read -r name qty; do
  inv_row "$name" "$qty"
done < "$(dirname "$0")/../data/stock.txt"
EOF
  S1B=$(dod_snapshot "$FIXB") || { echo "snapshot failed"; exit 1; }
  # Round 2: inv_row's output format changes; total.sh (unchanged) still
  # splits on ',' and now gets the whole row as the quantity.
  cat > "$FIXB/lib/inv.sh" <<'EOF'
#!/bin/bash
# inv_row <name> <qty> — prints one inventory row.
inv_row() {
  printf '%s: %s\n' "$1" "$2"
}
EOF
  S2B=$(dod_snapshot "$FIXB") || { echo "snapshot failed"; exit 1; }
  PROMPT_B=$(delta_prompt "$BASE_B" "$S1B" "$S2B" \
    "Make bin/list.sh print an 'Inventory' header and show each row as 'name: qty' instead of CSV." \
    "It works when bash bin/list.sh prints 'Inventory', then 'apple: 3' and 'pear: 2'.")

  assert_b2() {
    local r; r=$(cat)
    assert_json "$r" || return 1
    has_finding "$r" "inv.sh" 'total\.sh' \
      || { echo "no non-scope finding anchored to lib/inv.sh naming bin/total.sh (delta-caused breakage missed)"; return 1; }
  }

  echo "== (b2) breakage the delta causes in an unchanged consumer is reported =="
  sys_prompt "$REVIEWER_MINUS_F2" "$WORK/sys-rev-minus-f2"
  sys_prompt "$REVIEWER_NEW" "$WORK/sys-rev-new"
  measure b2-old reviewer_model assert_b2 "$WORK/sys-rev-minus-f2" "$FIXB" "$PROMPT_B"; OLD=$RATE
  measure b2-new reviewer_model assert_b2 "$WORK/sys-rev-new" "$FIXB" "$PROMPT_B"; NEW=$RATE
  verdict b2 "$OLD" "$B2_OLD_MAX" "$NEW"
fi

# ============================================================== (b3)
if want b3; then
  FIXP="$WORK/repo-b3"
  fixture_init "$FIXP"
  mkdir -p "$FIXP/data"
  printf 'pear 2\napple 3\n' > "$FIXP/data/stock.txt"
  cat > "$FIXP/bin/export.sh" <<'EOF'
#!/bin/bash
# Exports the stock list, one row per item.
while read -r name qty; do
  printf '%s,%s\n' "$name" "$qty"
done < "$(dirname "$0")/../data/stock.txt"
EOF
  cat > "$FIXP/bin/summary.sh" <<'EOF'
#!/bin/bash
# Prints the total number of units in stock.
bash "$(dirname "$0")/export.sh" | awk -F, '{ s += $2 } END { print "Total units: " s }'
EOF
  git -C "$FIXP" add -A && git -C "$FIXP" commit -q -m baseline
  BASE_P=$(git -C "$FIXP" rev-parse HEAD)
  # Round 1: export.sh sorts its rows by name.
  cat > "$FIXP/bin/export.sh" <<'EOF'
#!/bin/bash
# Exports the stock list, one row per item, sorted by name.
while read -r name qty; do
  printf '%s,%s\n' "$name" "$qty"
done < "$(dirname "$0")/../data/stock.txt" | sort
EOF
  S1P=$(dod_snapshot "$FIXP") || { echo "snapshot failed"; exit 1; }
  # Round 2: export.sh's output format changes; summary.sh (unchanged) still
  # pipes it into `awk -F,` and now sums empty fields (Total units: 0).
  cat > "$FIXP/bin/export.sh" <<'EOF'
#!/bin/bash
# Exports the stock list, one row per item, sorted by name.
while read -r name qty; do
  printf '%s: %s\n' "$name" "$qty"
done < "$(dirname "$0")/../data/stock.txt" | sort
EOF
  S2P=$(dod_snapshot "$FIXP") || { echo "snapshot failed"; exit 1; }
  PROMPT_P=$(delta_prompt "$BASE_P" "$S1P" "$S2P" \
    "Make bin/export.sh print its rows sorted by name, each as 'name: qty' instead of CSV." \
    "It works when bash bin/export.sh prints 'apple: 3', then 'pear: 2'.")

  assert_b3() {
    local r; r=$(cat)
    assert_json "$r" || return 1
    has_finding "$r" "export.sh" 'summary\.sh' \
      || { echo "no non-scope finding anchored to bin/export.sh naming bin/summary.sh (piped consumer breakage missed)"; return 1; }
  }

  echo "== (b3) breakage the delta causes in an unchanged piped consumer is reported =="
  sys_prompt "$REVIEWER_PRE_F2PIPE" "$WORK/sys-rev-pre-f2pipe"
  sys_prompt "$REVIEWER_NEW" "$WORK/sys-rev-new"
  measure b3-old reviewer_model assert_b3 "$WORK/sys-rev-pre-f2pipe" "$FIXP" "$PROMPT_P"; OLD=$RATE
  measure b3-new reviewer_model assert_b3 "$WORK/sys-rev-new" "$FIXP" "$PROMPT_P"; NEW=$RATE
  verdict b3 "$OLD" "$OLD_MAX" "$NEW"
fi

# ============================================================== (c)
if want c; then
  # next_review exactly as contract-read computes it for this result: run
  # result_next_review on the same result written by result_write.
  REQS_C='[
    {"id":"tests","type":"check","verdict":"n/a","reason":"fixture has no test runner"},
    {"id":"review","type":"judgement","verdict":"fail","depth":"full",
     "findings":[{"id":"f1","severity":"blocking","lens":"correctness",
       "file":"lib/clamp.sh","line":5,
       "summary":"clamp prints hi instead of lo when v < lo",
       "failure_scenario":"clamp 5 10 20 prints 20, expected 10",
       "requirement_id":"review"}],
     "impact_trace":[]}]'
  result_write "$WORK/result-c.json" --diff-hash 9f8e7d6c5b4a39281706f5e4d3c2b1a098765432 \
    --baseline-sha 1111111111111111111111111111111111111111 --round 1 \
    --snapshot-sha "" --requirements "$REQS_C" \
    || { echo "result_write failed for case c"; exit 1; }
  NEXT_REVIEW_C=$(result_next_review "$WORK/result-c.json" 1111111111111111111111111111111111111111)
  CONTRACT_C=$(jq -n --argjson reqs "$REQS" --argjson next_review "$NEXT_REVIEW_C" '{
    repo: "/work/app", task_key: "feature-x", status: "open",
    task: "Add lib/clamp.sh defining clamp <v> <lo> <hi>.",
    task_source: "argument", session_id: "",
    works_when: "It works when clamp 5 10 20 prints 10.",
    baseline_sha: "1111111111111111111111111111111111111111",
    requirements: $reqs, waivers: [],
    brief: {applicable: false, reason: "no project standards found"},
    state: {state: "verifying", decisions: [], decided_diff_hash: ""},
    result: {diff_hash: "9f8e7d6c5b4a39281706f5e4d3c2b1a098765432",
      baseline_sha: "1111111111111111111111111111111111111111",
      round: 1, snapshot_sha: "",
      requirements: [
        {id: "tests", type: "check", verdict: "n/a", reason: "fixture has no test runner"},
        {id: "review", type: "judgement", verdict: "fail", depth: "full",
         findings: [{id: "f1", severity: "blocking", lens: "correctness",
           file: "lib/clamp.sh", line: 5,
           summary: "clamp prints hi instead of lo when v < lo",
           failure_scenario: "clamp 5 10 20 prints 20, expected 10",
           requirement_id: "review"}],
         impact_trace: []}],
      advisory_ids: [], creep_ids: []},
    next_review: $next_review}')
  PROMPT_C=$(cat <<EOF
You are running /dod:verify. Steps 1-4 are done; you are at step 5, about to
spawn dod-reviewer for the "review" requirement. Do not run anything — every
command output you need is given below. Reply with ONLY the dod-reviewer
input block you would spawn it with (the "baseline_sha : …" lines), in one
fenced code block, nothing else.

dod.sh contract-read printed:
$CONTRACT_C

dod.sh changed-standards printed: []
dod.sh snapshot (if you run it) prints: 2222222222222222222222222222222222222222
EOF
)

  # assert_c — stdin: the skill run's reply (the input block).
  assert_c() {
    local r; r=$(cat)
    printf '%s\n' "$r" | grep -Eq '^[[:space:]]*mode[[:space:]]*:[[:space:]]*delta_reconfirm' \
      || { echo "mode is not delta_reconfirm: $(printf '%s\n' "$r" | grep -E 'mode' | head -1)"; return 1; }
    printf '%s\n' "$r" | awk '/^[[:space:]]*reconfirm[[:space:]]*:/ { f = 1 } f && /^[[:space:]]*task[[:space:]]*:/ { f = 0 } f' | grep -q 'f1' \
      || { echo "reconfirm does not carry f1"; return 1; }
  }

  echo "== (c) no snapshot: reconfirm[] still re-checked =="
  sys_prompt "$SKILL_PRE_F1" "$WORK/sys-skill-old"
  sys_prompt "$SKILL_NEW" "$WORK/sys-skill-new"
  measure c-old skill_model assert_c "$WORK/sys-skill-old" "$PROMPT_C"; OLD=$RATE
  measure c-new skill_model assert_c "$WORK/sys-skill-new" "$PROMPT_C"; NEW=$RATE
  verdict c "$OLD" "$OLD_MAX" "$NEW"
fi

exit $FAIL
