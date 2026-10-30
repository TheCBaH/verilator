#!/usr/bin/env bash
# $dumpvars scope arguments: new tests against committed goldens, all
# trace and $dumpvars tests, then 'make format'.
set -uo pipefail
OUT=$1
mkdir -p "$OUT"
source .venv/bin/activate 2>/dev/null || true
export VERILATOR_TEST_NO_CONTRIBUTORS=1 VERILATOR_TEST_NO_LINT_PY=1
status=0
drv() { (cd test_regress && ./driver.py -j 0 "$@"); }
git log --oneline -3
new=$(cd test_regress && ls t/t_trace_dumpvars_scope_*.py)
if drv $new > "$OUT/scope.log" 2>&1; then echo "scope: PASS"; else echo "scope: FAIL"; status=1; fi
grep -h -E '%Error|%Warning|FAILED' "$OUT/scope.log" | sort -u | head -20
users=$(cd test_regress && grep -l -E '\$dump(vars|ports)' t/*.v | sed 's/\.v$/*.py/' | xargs -n1 sh -c 'ls $0 2>/dev/null' | grep -v '_scope_')
all=$( (cd test_regress && ls t/t_trace_*.py t/t_dist_*.py; echo "$users") | sort -u | grep -v '_scope_')
if drv $all > "$OUT/all.log" 2>&1; then echo "trace, dumpvars, dist: PASS"; else echo "trace, dumpvars, dist: FAIL"; status=1; fi
grep -E '==SUMMARY|^%Error: .*Test failed|FAILED' "$OUT/all.log" | sort -u | head -40
git status --porcelain | head -20
git add -A
make -j 4 format CLANGFORMAT=clang-format-21 > "$OUT/format.log" 2>&1 || echo "format: rc $?"
git diff > "$OUT/format.diff"
echo "format diff lines: $(wc -l < "$OUT/format.diff")"
exit $status
