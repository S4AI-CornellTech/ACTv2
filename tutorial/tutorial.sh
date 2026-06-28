#!/usr/bin/env bash
# ACT hands-on tutorial: run ANY bill-of-materials through the real act_model CLI.
# Participant-facing runner for the hands-on tutorial (see TUTORIAL.md). Self-contained
# in this repo — it does not depend on the full-stack-carbon suite.
#
#   ./tutorial.sh <bom.yaml>                 run a tutorial BOM, print its carbon report
#   ./tutorial.sh <bom.yaml> --expect <kg>   also assert total_carbon ~= <kg> (used by CI)
#
# <bom.yaml> is resolved relative to this tutorial/ directory if it is not absolute, e.g.:
#   ./tutorial.sh exercises/sensitivity.yaml
#
# Python: set $PYTHON to an interpreter whose path can import `act` + `act_core` (ACT's own
# env — pint/pyyaml installed). Defaults to python3 (assumes that env is active). From the
# full-stack-carbon suite, `make tutorial-act` passes the suite's .envs/act python.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"          # the ACT repo root (has act/ and act_core/)
PY="${PYTHON:-python3}"

BOM="${1:?usage: tutorial.sh <bom.yaml> [--expect <kg>]}"
case "$BOM" in /*) : ;; *) BOM="$HERE/$BOM" ;; esac
[ -f "$BOM" ] || { echo "ERROR: BOM not found: $BOM" >&2; exit 1; }

EXPECT=""
if [ "${2:-}" = "--expect" ]; then EXPECT="${3:?--expect needs a number}"; fi

OUT="$HERE/figures/tutorial"
mkdir -p "$OUT"

echo "[ACT tutorial] $(basename "$BOM")"
( cd "$REPO" && PYTHONPATH="$REPO" "$PY" -m act.act_model -m "$BOM" -o "$OUT" >/dev/null )

REPORT="$OUT/act_report.yaml"
echo "  $(grep -E '^total_carbon:' "$REPORT")"
grep -A12 '^result_by_category:' "$REPORT" | sed 's/^/  /'

if [ -n "$EXPECT" ]; then
  total="$(grep -E '^total_carbon:' "$REPORT" | grep -oE '[0-9]+\.?[0-9]*' | head -1)"
  awk -v g="$total" -v e="$EXPECT" \
    'BEGIN{d=(g>e?g-e:e-g); tol=(0.05>0.001*e?0.05:0.001*e); exit(d<=tol?0:1)}' \
    && echo "  OK: total ~= $EXPECT kg" \
    || { echo "  FAIL: total $total != expected $EXPECT kg" >&2; exit 1; }
fi
