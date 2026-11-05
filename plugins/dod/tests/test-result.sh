#!/bin/bash
#
# Tests for dod/lib/result.sh: result_read/write/validate.

DIR0="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR0/test-helpers.sh"
. "$DIR0/../lib/result.sh"

echo "== result.sh =="

REPO=$(dod__test_make_repo)
RFILE="$REPO/.dod/main/result.json"

# --- round trip --------------------------------------------------------------
result_write "$RFILE" \
  --diff-hash "abc123" \
  --baseline-sha "def456" \
  --round 1 \
  --requirements '[{"id":"tests","type":"check","verdict":"pass","cmd":"npm test","exit":0}]'

if [ -f "$RFILE" ]; then
  ok "result_write creates the file"
else
  bad "result_write creates the file" "missing"
fi

result_read "$RFILE"
eq "round-trip diff_hash" "abc123" "$RESULT_DIFF_HASH"
eq "round-trip baseline_sha" "def456" "$RESULT_BASELINE_SHA"
eq "round-trip round" "1" "$RESULT_ROUND"
eq "round-trip blocking_fail count" "0" "$RESULT_BLOCKING_FAIL"

# --- malformed input rejected -------------------------------------------------
BADFILE="$REPO/.dod/main/bad-result.json"
printf 'not json at all' > "$BADFILE"
if result_read "$BADFILE"; then
  bad "result_read rejects malformed JSON" "accepted"
else
  ok "result_read rejects malformed JSON"
fi

# --- N6: requirement must be check or judgement, never neither ---------------
UNTYPED="$REPO/.dod/main/untyped-result.json"
if result_write "$UNTYPED" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[{"id":"mystery","verdict":"pass"}]'; then
  bad "result_write rejects a requirement with neither type" "accepted"
else
  ok "result_write rejects a requirement with neither type"
fi
if [ -f "$UNTYPED" ]; then
  bad "result_write does not create a file on validation failure" "created"
else
  ok "result_write does not create a file on validation failure"
fi

# --- f1: a judgement finding must carry a non-empty string id ----------------
# A null/missing id can never be decided (state_record_decisions requires
# string ids), which would leave an advisory-decision contract stuck open
# forever — reject at the write boundary instead.
NULLID="$REPO/.dod/main/nullid-result.json"
if result_write "$NULLID" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[{"id":"review","type":"judgement","verdict":"pass",
    "findings":[{"id":null,"severity":"advisory","file":"a.ts","line":1,"summary":"x"}]}]'; then
  bad "result_write rejects a judgement finding with a null id" "accepted"
else
  ok "result_write rejects a judgement finding with a null id"
fi
if [ -f "$NULLID" ]; then
  bad "result_write does not create a file on null-id validation failure" "created"
else
  ok "result_write does not create a file on null-id validation failure"
fi

MISSINGID="$REPO/.dod/main/missingid-result.json"
if result_write "$MISSINGID" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[{"id":"review","type":"judgement","verdict":"pass",
    "findings":[{"severity":"advisory","file":"a.ts","line":1,"summary":"x"}]}]'; then
  bad "result_write rejects a judgement finding with a missing id" "accepted"
else
  ok "result_write rejects a judgement finding with a missing id"
fi

# --- blocking failure counted correctly --------------------------------------
FAILFILE="$REPO/.dod/main/fail-result.json"
result_write "$FAILFILE" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[{"id":"tests","type":"check","verdict":"fail","cmd":"npm test","exit":1},{"id":"lint","type":"check","verdict":"pass","cmd":"npm lint","exit":0}]'
result_read "$FAILFILE"
eq "blocking_fail counts fail verdicts" "1" "$RESULT_BLOCKING_FAIL"

# --- judgement requirement round-trips with nested findings -------------------
JFILE="$REPO/.dod/main/judgement-result.json"
result_write "$JFILE" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[
    {"id":"review","type":"judgement","verdict":"fail",
     "findings":[{"id":"f1","severity":"blocking","file":"a.ts","line":1,"summary":"bug"},
                 {"id":"f2","severity":"advisory","file":"b.ts","line":2,"summary":"naming"}]}
  ]'
result_read "$JFILE"
eq "judgement: blocking_fail counts a failed judgement" "1" "$RESULT_BLOCKING_FAIL"
FINDINGS_COUNT=$(printf '%s' "$RESULT_REQUIREMENTS" | jq '.[0].findings | length' 2>/dev/null)
eq "judgement: findings round-trip intact" "2" "$FINDINGS_COUNT"

# --- judgement requirement, all-advisory findings -> requirement still passes -
JPASSFILE="$REPO/.dod/main/judgement-pass-result.json"
result_write "$JPASSFILE" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[
    {"id":"review","type":"judgement","verdict":"pass",
     "findings":[{"id":"f1","severity":"advisory","file":"b.ts","line":2,"summary":"naming"}]}
  ]'
result_read "$JPASSFILE"
eq "judgement: advisory-only findings do not block" "0" "$RESULT_BLOCKING_FAIL"

# --- RESULT_ADVISORY_IDS: advisory finding ids across judgements --------
result_read "$RFILE"
eq "advisory ids: none in a check-only result" "[]" "$RESULT_ADVISORY_IDS"
result_read "$JFILE"
eq "advisory ids: only severity advisory" '["f2"]' "$RESULT_ADVISORY_IDS"

# --- f1: RESULT_ADVISORY_IDS is deduplicated ----------------------------------
DUPFILE="$REPO/.dod/main/dup-result.json"
result_write "$DUPFILE" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[
    {"id":"review","type":"judgement","verdict":"pass",
     "findings":[{"id":"f1","severity":"advisory","file":"a.ts","line":1,"summary":"x"},
                 {"id":"f1","severity":"advisory","file":"a.ts","line":1,"summary":"x"}]}
  ]'
result_read "$DUPFILE"
eq "advisory ids: duplicate ids are deduplicated" '["f1"]' "$RESULT_ADVISORY_IDS"

PRIOR="$REPO/.dod/main/prior-result.json"
result_write "$PRIOR" \
  --diff-hash "x" --baseline-sha "y" --round 2 \
  --requirements '[{"id":"tests","type":"check","verdict":"pass","cmd":"t","exit":0}]'

# --- result_next_round: prior round + 1 for the same contract, else 1 ------
eq "next round: no prior result -> 1" "1" "$(result_next_round "$REPO/.dod/main/no-such-result.json" "y")"
eq "next round: same baseline, prior round 2 -> 3" "3" "$(result_next_round "$PRIOR" "y")"
eq "next round: different baseline -> 1" "1" "$(result_next_round "$PRIOR" "other-baseline")"
eq "next round: malformed prior -> 1" "1" "$(result_next_round "$BADFILE" "y")"

# --- RESULT_CREEP_IDS: only blocking scope+creep findings (ADR 0004) --------
CREEP_FILE="$REPO/.dod/main/creep-result.json"
result_write "$CREEP_FILE" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[
    {"id":"review","type":"judgement","verdict":"fail","findings":[
      {"id":"c1","severity":"blocking","lens":"scope","kind":"creep","file":"a.ts","line":1,"summary":"unrequested refactor"},
      {"id":"g1","severity":"blocking","lens":"scope","kind":"gap","file":"b.ts","line":2,"summary":"missing coverage"},
      {"id":"adv1","severity":"advisory","lens":"scope","kind":"creep","file":"c.ts","line":3,"summary":"advisory creep, not blocking"},
      {"id":"other1","severity":"blocking","lens":"correctness","file":"d.ts","line":4,"summary":"a bug"}
    ]}
  ]'
result_read "$CREEP_FILE"
eq "creep ids: only blocking scope+creep findings" '["c1"]' "$RESULT_CREEP_IDS"

NOCREEP_FILE="$REPO/.dod/main/nocreep-result.json"
result_write "$NOCREEP_FILE" \
  --diff-hash "x" --baseline-sha "y" --round 1 \
  --requirements '[
    {"id":"review","type":"judgement","verdict":"fail","findings":[
      {"id":"g1","severity":"blocking","lens":"scope","kind":"gap","file":"b.ts","line":2,"summary":"missing coverage"}
    ]}
  ]'
result_read "$NOCREEP_FILE"
eq "creep ids: gap-only result has none" "[]" "$RESULT_CREEP_IDS"

eq "creep ids: check-only result has none" "[]" "$(result_read "$RFILE" && printf '%s' "$RESULT_CREEP_IDS")"

# --- snapshot_sha -------------------------------------------------------------
SNAP_FILE="$REPO/.dod/main/snap-result.json"
result_write "$SNAP_FILE" --diff-hash "x" --baseline-sha "y" --round 1 \
  --snapshot-sha "0123abcd" --requirements '[]'
result_read "$SNAP_FILE"
eq "round-trip snapshot_sha" "0123abcd" "$RESULT_SNAPSHOT_SHA"
# legacy result (written before snapshot_sha existed) reads as empty
LEGACY_FILE="$REPO/.dod/main/legacy-result.json"
printf '%s' '{"diff_hash":"x","baseline_sha":"y","round":1,"requirements":[],"summary":{"blocking_fail":0}}' > "$LEGACY_FILE"
result_read "$LEGACY_FILE"
eq "legacy result: snapshot_sha empty" "" "$RESULT_SNAPSHOT_SHA"
# a failed read never leaves a stale snapshot sha
result_read "$SNAP_FILE"; result_read "$REPO/.dod/main/missing.json"
eq "failed read: snapshot_sha reset" "" "$RESULT_SNAPSHOT_SHA"

# --- result_next_review: the next review's mode, reconfirm and delta_from ---
# Guards f1: which round and what reconfirm holds used to be skill text the
# model followed (and got wrong); now code computes it (D15/D16).
NR_DIR="$REPO/.dod/nr"; mkdir -p "$NR_DIR"
# nr_write <name> <requirements> [snapshot] — a prior result on baseline "y"
nr_write() {
  result_write "$NR_DIR/$1.json" --diff-hash "x" --baseline-sha "y" --round 1 \
    --snapshot-sha "${3:-snap1}" --requirements "$2"
}
nr() { result_next_review "$NR_DIR/$1.json" "${2:-y}"; }

eq "next review: no prior result -> full, no reconfirm" \
  '{"mode":"full","reconfirm":[],"delta_from":""}' "$(nr no-such)"
eq "next review: malformed prior -> full" \
  '{"mode":"full","reconfirm":[],"delta_from":""}' "$(result_next_review "$BADFILE" "y")"

nr_write pass '[{"id":"review","type":"judgement","verdict":"pass","findings":[
  {"id":"a1","severity":"advisory","lens":"standards","file":"a.ts","line":1,"summary":"nit"}]}]'
eq "next review: prior review passed -> full" \
  '{"mode":"full","reconfirm":[],"delta_from":""}' "$(nr pass)"

nr_write findings '[{"id":"tests","type":"check","verdict":"pass","cmd":"t","exit":0},
  {"id":"review","type":"judgement","verdict":"fail","findings":[
  {"id":"f1","severity":"blocking","lens":"correctness","file":"a.ts","line":3,"summary":"bug","failure_scenario":"x"},
  {"id":"g1","severity":"blocking","lens":"scope","kind":"gap","file":"b.ts","line":1,"summary":"gap"},
  {"id":"a1","severity":"advisory","lens":"standards","file":"c.ts","line":2,"summary":"nit"}]}]'
eq "next review: baseline mismatch -> full" \
  '{"mode":"full","reconfirm":[],"delta_from":""}' "$(nr findings other-baseline)"
eq "next review: fail via findings -> delta_reconfirm, blocking non-scope only, delta_from = snapshot" \
  '{"mode":"delta_reconfirm","reconfirm":[{"id":"f1","file":"a.ts","line":3,"summary":"bug"}],"delta_from":"snap1"}' \
  "$(nr findings)"

nr_write creep '[{"id":"review","type":"judgement","verdict":"fail","findings":[
  {"id":"c1","severity":"blocking","lens":"scope","kind":"creep","file":"a.ts","line":1,"summary":"creep"},
  {"id":"f1","severity":"blocking","lens":"correctness","file":"a.ts","line":3,"summary":"bug"}]}]'
eq "next review: creep stop -> full" \
  '{"mode":"full","reconfirm":[],"delta_from":""}' "$(nr creep)"

nr_write reconfonly '[{"id":"review","type":"judgement","verdict":"fail","findings":[],"reconfirm":[
  {"id":"f1","file":"a.ts","line":3,"summary":"bug","status":"still_present","evidence":"unchanged"},
  {"id":"f2","file":"b.ts","line":5,"summary":"leak","status":"fixed","evidence":"guarded"},
  {"id":"f3","file":"c.ts","line":7,"summary":"race","status":"unverifiable","evidence":"no repro"}]}]'
eq "next review: fail via reconfirm only -> still_present/unverifiable carried, fixed dropped" \
  '{"mode":"delta_reconfirm","reconfirm":[{"id":"f1","file":"a.ts","line":3,"summary":"bug"},{"id":"f3","file":"c.ts","line":7,"summary":"race"}],"delta_from":"snap1"}' \
  "$(nr reconfonly)"

nr_write dedupe '[{"id":"review","type":"judgement","verdict":"fail","findings":[
  {"id":"f1","severity":"blocking","lens":"impact","file":"new.ts","line":9,"summary":"from findings"}],"reconfirm":[
  {"id":"f1","file":"old.ts","line":1,"summary":"from reconfirm","status":"still_present","evidence":"e"},
  {"id":"f0","file":"z.ts","line":2,"summary":"older","status":"still_present","evidence":"e"}]}]'
eq "next review: deduped by id, first (findings) wins" \
  '[{"id":"f1","file":"new.ts","line":9,"summary":"from findings"},{"id":"f0","file":"z.ts","line":2,"summary":"older"}]' \
  "$(nr dedupe | jq -c '.reconfirm')"

# legacy result: no snapshot_sha, review entry without reconfirm
printf '%s' '{"diff_hash":"x","baseline_sha":"y","round":1,"requirements":[{"id":"review","type":"judgement","verdict":"fail","findings":[{"id":"f1","severity":"blocking","file":"a.ts","line":3,"summary":"bug"}]}],"summary":{"blocking_fail":1}}' \
  > "$NR_DIR/legacy.json"
eq "next review: legacy result -> delta_reconfirm, delta_from empty, reconfirm from findings" \
  '{"mode":"delta_reconfirm","reconfirm":[{"id":"f1","file":"a.ts","line":3,"summary":"bug"}],"delta_from":""}' \
  "$(nr legacy)"

# --- result_enrich_reconfirm: file/line/summary filled from the prior list --
# Guards f1: the model copied the reviewer's reconfirm reply onto the review
# entry but dropped file/line/summary, so round 3's reconfirm lost them.
REPLY='[{"id":"tests","type":"check","verdict":"pass","cmd":"t","exit":0},
  {"id":"review","type":"judgement","verdict":"fail","findings":[],"reconfirm":[
  {"id":"f1","status":"still_present","evidence":"a.ts:3 unchanged"},
  {"id":"f3","file":"kept.ts","line":70,"summary":"own","status":"fixed","evidence":"e"},
  {"id":"zz","status":"still_present","evidence":"no prior match"}]}]'
ENRICHED=$(result_enrich_reconfirm "$NR_DIR/reconfonly.json" "y" "$REPLY")
eq "enrich: missing file/line/summary filled from the prior item, status/evidence kept" \
  '{"id":"f1","status":"still_present","evidence":"a.ts:3 unchanged","file":"a.ts","line":3,"summary":"bug"}' \
  "$(printf '%s' "$ENRICHED" | jq -c '.[1].reconfirm[0]')"
eq "enrich: fields already present are kept" \
  '{"id":"f3","file":"kept.ts","line":70,"summary":"own","status":"fixed","evidence":"e"}' \
  "$(printf '%s' "$ENRICHED" | jq -c '.[1].reconfirm[1]')"
eq "enrich: no prior match -> item unchanged" \
  '{"id":"zz","status":"still_present","evidence":"no prior match"}' \
  "$(printf '%s' "$ENRICHED" | jq -c '.[1].reconfirm[2]')"
eq "enrich: other requirements unchanged" \
  "$(printf '%s' "$REPLY" | jq -c '.[0]')" "$(printf '%s' "$ENRICHED" | jq -c '.[0]')"
NOREC='[{"id":"review","type":"judgement","verdict":"pass","findings":[]}]'
eq "enrich: review entry without reconfirm unchanged" \
  "$(printf '%s' "$NOREC" | jq -c '.')" "$(result_enrich_reconfirm "$NR_DIR/reconfonly.json" "y" "$NOREC" | jq -c '.')"
eq "enrich: no prior result -> unchanged" \
  "$(printf '%s' "$REPLY" | jq -c '.')" "$(result_enrich_reconfirm "$NR_DIR/no-such.json" "y" "$REPLY" | jq -c '.')"
eq "enrich: invalid JSON passed through as given (result_write rejects it)" \
  "not json" "$(result_enrich_reconfirm "$NR_DIR/reconfonly.json" "y" "not json")"

echo
echo "result.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
