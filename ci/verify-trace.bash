#!/usr/bin/env bash
# For each branch: golden files with the fix, a rerun that must pass, and
# (for the bug fixes) a run on the unfixed runtime that must fail. Then all
# trace tests with every branch merged, and 'make format' on the merge.
set -uo pipefail
OUT=$1
mkdir -p "$OUT"
source .venv/bin/activate 2>/dev/null || true
export VERILATOR_TEST_NO_CONTRIBUTORS=1 VERILATOR_TEST_NO_LINT_PY=1
BASE=$(git rev-parse HEAD)
MASTER=$(git merge-base HEAD scratch/mask)
status=0
drv() { (cd test_regress && ./driver.py -j 0 "$@"); }
for b in mask event exact; do
  ref=scratch/$b
  git checkout -q "$ref" -- $(git diff --name-only "$MASTER" "$ref")
  tests=$(git diff --name-only "$MASTER" "$ref" -- 'test_regress/t/t_*.py' | sed 's|^test_regress/||')
  mkdir -p "$OUT/$b"
  drv --golden $tests > "$OUT/$b/golden.log" 2>&1
  cp test_regress/t/t_trace_dumpvars_*.out "$OUT/$b/" 2>/dev/null
  if drv $tests > "$OUT/$b/fixed.log" 2>&1; then echo "$b fixed: PASS"; else echo "$b fixed: FAIL"; status=1; fi
  if [ "$b" != exact ]; then
    git checkout -q "$MASTER" -- include
    if drv $tests > "$OUT/$b/unfixed.log" 2>&1; then echo "$b unfixed: PASS (expected FAIL)"; status=1
    else echo "$b unfixed: FAIL (expected)"; fi
    grep -h -E '%Error|Assertion|error:|Abort|differ|mismatch' "$OUT/$b/unfixed.log" | head -20
  fi
  git reset -q --hard "$BASE"; git clean -fdq test_regress
done
git -c user.name=ci -c user.email=ci@example.com merge -q --no-edit scratch/mask scratch/event scratch/exact || status=1
for b in mask event exact; do cp "$OUT/$b"/*.out test_regress/t/; done
if drv $(cd test_regress && ls t/t_trace_*.py) > "$OUT/all-trace.log" 2>&1; then echo "all t_trace_*: PASS"
else echo "all t_trace_*: FAIL"; status=1; fi
tail -5 "$OUT/all-trace.log"
make -j 4 format CLANGFORMAT=clang-format-21 > "$OUT/format.log" 2>&1 || echo "format: rc $?"
git diff > "$OUT/format.diff"; echo "format diff lines: $(wc -l < "$OUT/format.diff")"
exit $status
