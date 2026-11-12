#!/usr/bin/env bash
# Run: bash tools/statusline/statusline.test.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/statusline.sh"
set +e
FAIL=0

check() { # description got want
  if [[ "$2" == "$3" ]]; then echo "PASS: $1"; else echo "FAIL: $1 (got '$2', want '$3')"; FAIL=1; fi
}
plain() { local s="$1"; echo "${s//$'\e'\[+([0-9;])m/}"; }

check "under an hour shows minutes"      "$(humanize_remaining 754)"    "12m"
check "hours and minutes"                "$(humanize_remaining 8003)"   "2hr 13m"
check "days, hours and minutes"          "$(humanize_remaining 359940)" "4d 3hr 59m"
check "passed reset shows now"           "$(humanize_remaining -5)"     "now"

check "whole number gets one decimal"    "$(format_percent 24)"   "24.0%"
check "decimal is kept"                  "$(format_percent 15.0)" "15.0%"
check "long decimal is rounded"          "$(format_percent 23.46)" "23.5%"

check "colour codes are not counted"     "$(visible_length "${RED}abc${RESET}")" "3"

check "usage with reset"                 "$(plain "$(usage_segment Sess 1 15600 0)")"   "Sess: 1.0% (4hr 20m)"
check "weekly label"                     "$(plain "$(usage_segment Weekly 15 300000 0)")" "Weekly: 15.0% (3d 11hr 20m)"
check "no usage data gives nothing"      "$(usage_segment Sess '' '' 100)"              ""
check "49.9% stays plain"                "$(plain "$(usage_segment Sess 49.9 160 100)")" "Sess: 49.9% (1m)"
check "50% turns yellow"                 "$(usage_segment Sess 50 160 100)"  "${DIM}Sess:${RESET} ${YELLOW}50.0%${RESET} ${DIM}(1m)${RESET}"
check "74.9% is still yellow"            "$(usage_segment Sess 74.9 160 100)" "${DIM}Sess:${RESET} ${YELLOW}74.9%${RESET} ${DIM}(1m)${RESET}"
check "75% turns orange"                 "$(usage_segment Sess 75 160 100)"  "${DIM}Sess:${RESET} ${ORANGE}75.0%${RESET} ${DIM}(1m)${RESET}"
check "89.9% is still orange"            "$(usage_segment Sess 89.9 160 100)" "${DIM}Sess:${RESET} ${ORANGE}89.9%${RESET} ${DIM}(1m)${RESET}"
check "90% turns red"                    "$(usage_segment Sess 95 160 100)"  "${DIM}Sess:${RESET} ${RED}95.0%${RESET} ${DIM}(1m)${RESET}"
check "weekly uses the same colours"     "$(usage_segment Weekly 80 160 100)" "${DIM}Weekly:${RESET} ${ORANGE}80.0%${RESET} ${DIM}(1m)${RESET}"

check "context below 50% has no colour"  "$(context_segment 49.9)"  "${DIM}Ctx:${RESET} 49.9%"
check "context 50% turns yellow"         "$(context_segment 50)"    "${DIM}Ctx:${RESET} ${YELLOW}50.0%${RESET}"
check "context 64.9% is still yellow"    "$(context_segment 64.9)"  "${DIM}Ctx:${RESET} ${YELLOW}64.9%${RESET}"
check "context 65% turns red"            "$(context_segment 65)"    "${DIM}Ctx:${RESET} ${RED}65.0%${RESET}"
check "no context data gives nothing"    "$(context_segment '')"    ""

check "empty segments are dropped"       "$(join_segments a '' b)" "a | b"

check "right side is pushed to the edge" "$(layout_line left right 20)" "left           right"
check "too narrow keeps 3 spaces"        "$(layout_line left right 5)"  "left   right"
check "no right side leaves left alone"  "$(layout_line left '' 20)"    "left"
check "layout ignores colour codes"      "$(visible_length "$(layout_line "${DIM}ab${RESET}" cd 12)")" "12"

full='{"model":{"display_name":"Opus 5.5"},"context_window":{"used_percentage":24},
  "rate_limits":{"five_hour":{"used_percentage":1,"resets_at":15540},"seven_day":{"used_percentage":15,"resets_at":318540}},
  "workspace":{"current_dir":"/nonexistent"}}'
want="Model: Opus 5.5 | Ctx: 24.0% | Sess: 1.0% (4hr 19m)            Weekly: 15.0% (3d 16hr 29m)"
got=$(echo "$full" | STATUSLINE_NOW=0 COLUMNS=96 main)
check "full payload, 96 columns minus the 6 column margin"         "$(plain "$got")" "$want"
check "full payload fills the width minus the margin" "$(visible_length "$got")" "90"

no_limits='{"model":{"display_name":"Sonnet"},"context_window":{"used_percentage":null},"workspace":{"current_dir":"/nonexistent"}}'
check "no rate_limits and null context"  "$(plain "$(echo "$no_limits" | STATUSLINE_NOW=0 main)")" "Model: Sonnet"

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q -b feature-x 2>/dev/null
branch_out=$(echo "{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"$repo\"}}" | STATUSLINE_NOW=0 main)
check "branch is on the second line"     "$(plain "$branch_out")" "Model: Opus
𖠰 feature-x"
check "model label is dim, name is not"  "${branch_out%%$'\n'*}" "${DIM}Model:${RESET} Opus"
check "branch is magenta"                "${branch_out#*$'\n'}"  "${MAGENTA}𖠰 feature-x${RESET}"
# render: responsive layout (plain segments, no colour codes)
M="Model: X"; C="Ctx: 5.0%"; S="Sess: 1.0% (4hr 19m)"; W="Weekly: 9.0% (3d 1hr 1m)"; B="𖠰 main"
left="$M | $C | $S"
wide=$(render "$M" "$C" "$S" "$W" "$B" 100)
check "wide: row 1 fills the width"       "$(visible_length "$(echo "$wide" | sed -n 1p)")" "100"
check "wide: branch is row 2"             "$(echo "$wide" | sed -n 2p)" "$B"
mid=$(render "$M" "$C" "$S" "$W" "$B" 60)
check "mid: row 1 is the left part"       "$(echo "$mid" | sed -n 1p)" "$left"
check "mid: weekly joins the branch row"  "$(echo "$mid" | sed -n 2p)" "$W | $B"
narrow=$(render "$M" "$C" "$S" "$W" "$B" 30)
check "narrow: model name is dropped"     "$(echo "$narrow" | sed -n 1p)" "$C | $S"
check "narrow: weekly joins the branch row" "$(echo "$narrow" | sed -n 2p)" "$W | $B"
check "unknown width: one compact row"    "$(render "$M" "$C" "$S" "$W" "" 0)" "$left   $W"
check "no weekly: left then branch"       "$(render "$M" "$C" "$S" "" "$B" 100)" "$left
$B"
check "exactly fitting width stays one row" "$(render "$M" "$C" "$S" "$W" "" $(( ${#left} + 3 + ${#W} )) | wc -l | tr -d " ")" "1"
check "one column too narrow stacks"      "$(render "$M" "$C" "$S" "$W" "" $(( ${#left} + 2 + ${#W} )) | wc -l | tr -d " ")" "2"
exit $FAIL
