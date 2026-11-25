#!/bin/bash
# W6 scratch gates after the repair-leg fix (map_gen.gd only).
# Fails a step on rc!=0, any SCRIPT ERROR, or any PASS=false.
SCRATCH=~/workspace/goals/game-off-2026-entry/loop-scratch/w6-long-soak-stability
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w6-long-soak-stability
SUM=$PHASE/w6-gate-scratch-summary.txt
: > $SUM
run_step() {
  local tag="$1"; shift
  local log="$PHASE/w6-gate-$tag.log"
  echo "=== $tag ===" | tee -a $SUM
  timeout 600 xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path "$SCRATCH" --resolution 2400x1080 -- "$@" > "$log" 2>&1
  local rc=$?
  local errs=$(grep -c "SCRIPT ERROR" "$log")
  local pf=$(grep -c "PASS=false" "$log")
  local ok=OK
  [ $rc -ne 0 ] && ok=FAIL
  [ "$errs" != "0" ] && ok=FAIL
  [ "$pf" != "0" ] && ok=FAIL
  echo "$tag rc=$rc errors=$errs passfalse=$pf -> $ok" | tee -a $SUM
  grep -E "DEEPFALL_PHASE1_READY" "$log" | tail -1 | tee -a $SUM
}
# 1. seed sweep: 5 fresh seeds via --dump-map (fast)
for S in 34288107 71509382 10455829 88204713 29063451; do
  timeout 120 xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path "$SCRATCH" --resolution 2400x1080 -- --seed=$S --dump-map > "$PHASE/w6-sweep-$S.log" 2>&1
  echo "sweep $S rc=$? $(grep -E 'DEEPFALL_PHASE1_READY' "$PHASE/w6-sweep-$S.log" | tail -1)" | tee -a $SUM
done
# 2. full suite, proper order (load test right after selftest, before p11)
run_step selftest --seed=20261101 --selftest
run_step selftest-load --seed=20261101 --selftest-load
run_step p11-tech --seed=20261101 --selftest-p11 --class=tech
run_step p11-red --seed=20261101 --selftest-p11 --class=red
run_step p11-mage --seed=20261101 --selftest-p11 --class=mage
echo "GATE CHAIN DONE $(date -u +%FT%TZ)" | tee -a $SUM
