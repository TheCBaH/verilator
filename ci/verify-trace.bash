#!/usr/bin/env bash
# Event review rework: goldens with the fix, rerun must pass, unfixed
# runtime must fail; then all trace tests and 'make format'.
set -uo pipefail
OUT=$1
mkdir -p "$OUT"
source .venv/bin/activate 2>/dev/null || true
export VERILATOR_TEST_NO_CONTRIBUTORS=1 VERILATOR_TEST_NO_LINT_PY=1
REF=scratch/event
BASE=$(git merge-base HEAD "$REF")
status=0
drv() { (cd test_regress && ./driver.py -j 0 "$@"); }
git checkout -q "$REF" -- .
git clean -fdq test_regress/t
git diff --name-only "$BASE" "$REF" -- test_regress | sed 's/^/changed: /'
tests=$(cd test_regress && ls t/t_trace_dumpvars_dyn_*.py)
drv --golden $tests > "$OUT/golden.log" 2>&1
echo "golden changes: $(git status --porcelain -- test_regress/t | grep '\.out$' | tr '\n' ' ')"
mkdir -p "$OUT/goldens"; cp test_regress/t/t_trace_dumpvars_dyn_*.out "$OUT/goldens/"
if drv $tests > "$OUT/fixed.log" 2>&1; then echo "fixed: PASS"; else echo "fixed: FAIL"; status=1; fi
cp include/verilated_trace_imp.h "$OUT/fixed_imp.h"
git show "$BASE":include/verilated_trace_imp.h > include/verilated_trace_imp.h
if drv $tests > "$OUT/unfixed.log" 2>&1; then echo "unfixed: PASS (expected FAIL)"; status=1
else echo "unfixed: FAIL (expected)"; fi
grep -h -E 'Assertion|FAILED' "$OUT/unfixed.log" | sort -u | head
cp "$OUT/fixed_imp.h" include/verilated_trace_imp.h
if drv $(cd test_regress && ls t/t_trace_*.py) > "$OUT/all-trace.log" 2>&1; then echo "all t_trace_*: PASS"
else echo "all t_trace_*: FAIL"; status=1; fi
grep '==SUMMARY' "$OUT/all-trace.log" | tail -1
git add -A
make -j 4 format CLANGFORMAT=clang-format-21 > "$OUT/format.log" 2>&1 || echo "format: rc $?"
git diff > "$OUT/format.diff"
echo "format diff lines: $(wc -l < "$OUT/format.diff")"
exit $status
