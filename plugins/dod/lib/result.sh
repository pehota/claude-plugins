#!/bin/bash
#
# dod/lib/result.sh — sole owner of result.json (N6).
#
# Nothing outside this file may `jq` into result.json. diff_hash is the
# gate's trust key: gate.sh reads RESULT_DIFF_HASH and RESULT_BLOCKING_FAIL
# only through this file's functions.
#
# Both requirement kinds are live: `check` ("fail" verdict = blocking) and
# `judgement` (the dod-reviewer agent's verdict, with severity-classified
# findings — "fail" or any blocking finding = blocking).
#
# ADR 0004: a judgement finding also carries `lens` and, for `lens:"scope"`,
# `kind` ("creep" | "gap"). RESULT_CREEP_IDS exports the ids of BLOCKING
# scope+creep findings only — gate.sh's one-shot creep branch reads it to
# route scope creep to a user decision instead of an ordinary fix round.

RESULT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dod__has_jq() { command -v jq >/dev/null 2>&1; }

# result__validate_requirements <json_array> — every element type check or
# judgement, never neither. Also: every judgement requirement's findings (if
# any) carry a non-empty string `id` — a null/missing id can never be
# decided (state_record_decisions requires string ids in RESULT_ADVISORY_IDS,
# dod/lib/state.sh), which would leave an advisory-decision contract stuck
# open forever with no way to satisfy it. Rejected here at the write
# boundary, same as the check/judgement type rule above, rather than
# silently dropped or coerced later.
result__validate_requirements() {
  local reqs="$1"
  dod__has_jq || return 1
  printf '%s' "$reqs" | jq -e '
    all(.[]; .type == "check" or .type == "judgement")
    and all(.[]; .type != "judgement" or
      ((.findings // []) | all(.[]; (.id | type) == "string" and (.id | length) > 0)))
  ' >/dev/null 2>&1
}

# result_write <path> --diff-hash H --baseline-sha SHA --round N
#                      [--snapshot-sha SHA] --requirements JSON_ARR
#
# snapshot_sha: the dod_snapshot commit of the working tree this round
# verified — round 2+ diffs against it to review only the delta. Empty when
# the snapshot could not be taken (the next round then reviews in full).
result_write() {
  local result_path="$1"; shift
  local diff_hash="" baseline_sha="" round="0" snapshot_sha="" requirements="[]"

  while [ $# -gt 0 ]; do
    case "$1" in
      --diff-hash) diff_hash="$2"; shift 2 ;;
      --baseline-sha) baseline_sha="$2"; shift 2 ;;
      --round) round="$2"; shift 2 ;;
      --snapshot-sha) snapshot_sha="$2"; shift 2 ;;
      --requirements) requirements="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  dod__has_jq || return 1
  result__validate_requirements "$requirements" || return 1

  case "$round" in ''|*[!0-9]*) round=0 ;; esac

  mkdir -p "$(dirname "$result_path")" 2>/dev/null

  jq -n \
    --arg diff_hash "$diff_hash" \
    --arg baseline_sha "$baseline_sha" \
    --argjson round "$round" \
    --arg snapshot_sha "$snapshot_sha" \
    --argjson requirements "$requirements" \
    '{
      diff_hash: $diff_hash,
      baseline_sha: $baseline_sha,
      round: $round,
      snapshot_sha: $snapshot_sha,
      requirements: $requirements,
      summary: {
        pass: [$requirements[] | select(.verdict == "pass")] | length,
        blocking_fail: [$requirements[] | select(.verdict == "fail")] | length,
        advisory: [$requirements[] | select(.verdict == "advisory")] | length,
        waived: [$requirements[] | select(.verdict == "waived")] | length,
        na: [$requirements[] | select(.verdict == "n/a")] | length
      }
    }' > "$result_path" 2>/dev/null
}

# result_read <path> — sets RESULT_* globals (RESULT_ADVISORY_IDS: JSON
# array of the advisory findings' ids across judgement requirements, unique
# and non-null — result__validate_requirements already rejects a null/missing
# id, `unique` here only guards against an accidental duplicate id so
# state_record_decisions never sees the same id twice; RESULT_SNAPSHOT_SHA:
# empty for a legacy result written before snapshot_sha existed). Returns 1 on
# missing/malformed/invalid, without setting stale globals.
result_read() {
  local result_path="$1"
  RESULT_DIFF_HASH=""
  RESULT_BASELINE_SHA=""
  RESULT_ROUND=""
  RESULT_SNAPSHOT_SHA=""
  RESULT_REQUIREMENTS="[]"
  RESULT_BLOCKING_FAIL=""
  RESULT_ADVISORY_IDS="[]"
  RESULT_CREEP_IDS="[]"

  [ -f "$result_path" ] || return 1
  dod__has_jq || return 1
  jq -e '.' "$result_path" >/dev/null 2>&1 || return 1

  local reqs
  reqs=$(jq -c '.requirements // []' "$result_path" 2>/dev/null)
  result__validate_requirements "$reqs" || return 1

  RESULT_DIFF_HASH=$(jq -r '.diff_hash // ""' "$result_path" 2>/dev/null)
  RESULT_BASELINE_SHA=$(jq -r '.baseline_sha // ""' "$result_path" 2>/dev/null)
  RESULT_ROUND=$(jq -r '.round // 0' "$result_path" 2>/dev/null)
  RESULT_SNAPSHOT_SHA=$(jq -r '.snapshot_sha // ""' "$result_path" 2>/dev/null)
  RESULT_REQUIREMENTS="$reqs"
  RESULT_BLOCKING_FAIL=$(jq -r '.summary.blocking_fail // 0' "$result_path" 2>/dev/null)
  RESULT_ADVISORY_IDS=$(printf '%s' "$reqs" | jq -c '[.[] | select(.type == "judgement") | .findings[]? | select(.severity == "advisory") | .id] | unique' 2>/dev/null)
  [ -n "$RESULT_ADVISORY_IDS" ] || RESULT_ADVISORY_IDS="[]"

  # ADR 0004: ids of BLOCKING findings that are both lens:"scope" and
  # kind:"creep" — a gap finding (also lens:"scope") or an advisory-severity
  # creep finding never belongs here; gate.sh's one-shot creep branch reads
  # this to tell "the user must decide revert/accept-and-amend" from an
  # ordinary fix-and-reverify blocking failure.
  RESULT_CREEP_IDS=$(printf '%s' "$reqs" | jq -c '[.[] | select(.type == "judgement") | .findings[]? | select(.severity == "blocking" and .lens == "scope" and .kind == "creep") | .id] | unique' 2>/dev/null)
  [ -n "$RESULT_CREEP_IDS" ] || RESULT_CREEP_IDS="[]"
  return 0
}

# result_next_round <prior_path> <baseline_sha> — prints the prior result's
# round + 1 when it belongs to the same contract (same baseline_sha), else 1
# (missing, invalid, or another contract's result).
result_next_round() {
  local prior="$1" baseline_sha="$2"
  if result_read "$prior" && [ "$RESULT_BASELINE_SHA" = "$baseline_sha" ]; then
    case "$RESULT_ROUND" in ''|*[!0-9]*) ;; *) echo $((RESULT_ROUND + 1)); return 0 ;; esac
  fi
  echo 1
}


# result_next_review <prior_path> <baseline_sha> — prints the next review's
# inputs as one JSON object {mode, reconfirm, delta_from} (D15/D16; /dod:verify
# passes them to dod-reviewer verbatim):
#   mode       "delta_reconfirm" when the prior result belongs to this
#              contract (same baseline_sha), its `review` verdict is "fail"
#              and it has no creep stop (RESULT_CREEP_IDS empty); else "full".
#              Keyed on the verdict, not on blocking findings — a review can
#              fail through `reconfirm` alone (findings: []).
#   reconfirm  delta_reconfirm only, else []: the prior review's blocking
#              non-scope findings, then its reconfirm entries whose status is
#              not "fixed", as {id, file, line, summary}, deduped by id (first
#              wins). Scope findings stay out — the scope lens re-runs fresh.
#   delta_from delta_reconfirm only, else "": the prior snapshot_sha ("" for a
#              legacy result without one — the reviewer then reviews in full).
result_next_review() {
  local prior="$1" baseline_sha="$2"
  local full='{"mode":"full","reconfirm":[],"delta_from":""}'
  if ! result_read "$prior" || [ "$RESULT_BASELINE_SHA" != "$baseline_sha" ] \
    || [ "$RESULT_CREEP_IDS" != "[]" ]; then
    printf '%s\n' "$full"
    return 0
  fi
  printf '%s' "$RESULT_REQUIREMENTS" | jq -c --arg delta_from "$RESULT_SNAPSHOT_SHA" '
    (first(.[] | select(.id == "review")) // null) as $review
    | if $review == null or $review.verdict != "fail" then
        {mode: "full", reconfirm: [], delta_from: ""}
      else
        ([($review.findings // [])[] | select(.severity == "blocking" and .lens != "scope")]
         + [($review.reconfirm // [])[] | select(.status != "fixed")]) as $carried
        | {mode: "delta_reconfirm",
           reconfirm: ($carried
             | map({id, file, line, summary})
             | reduce .[] as $item ([]; if any(.[]; .id == $item.id) then . else . + [$item] end)),
           delta_from: $delta_from}
      end'
}

# result_enrich_reconfirm <prior_path> <baseline_sha> <requirements_json> —
# prints the requirements with each `review` reconfirm entry's missing
# file/line/summary filled from the prior result's result_next_review
# reconfirm item of the same id (the reviewer replies with id/status/evidence
# only). Present fields and items without a prior match are kept as given.
# Must run before result_write overwrites the prior result. Unparseable input
# is printed unchanged, for result_write's validation to reject.
result_enrich_reconfirm() {
  local prior="$1" baseline_sha="$2" reqs="$3" prior_items enriched
  prior_items=$(result_next_review "$prior" "$baseline_sha" | jq -c '.reconfirm' 2>/dev/null)
  enriched=$(printf '%s' "$reqs" | jq -c --argjson prior "${prior_items:-[]}" '
    map(if .id == "review" and ((.reconfirm | type) == "array") then
          .reconfirm |= map(. as $item
            | (first($prior[] | select(.id == $item.id)) // {}) as $match
            | reduce ("file", "line", "summary") as $key ($item;
                if .[$key] == null and $match[$key] != null then .[$key] = $match[$key] else . end))
        else . end)' 2>/dev/null) || enriched=""
  printf '%s\n' "${enriched:-$reqs}"
}
