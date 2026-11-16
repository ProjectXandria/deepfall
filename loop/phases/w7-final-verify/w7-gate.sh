#!/bin/bash
# W7 FINAL gate chain on the LIVE tree (no scratch — verify-only wave).
# Fails a step on rc!=0, any SCRIPT ERROR, or any PASS=false.
# Proper order: selftest (creates save) -> selftest-load -> p11 per class -> soak.
LIVE=~/workspace/goals/game-off-2026-entry/deepfall-game
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w7-final-verify
SUM=$PHASE/w7-gate-summary.txt
: > $SUM
run_step() {
  local tag="$1"; shift
  local log="$PHASE/w7-gate-$tag.log"
  echo "=== $tag ===" | tee -a $SUM
  timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path "$LIVE" --resolution 2400x1080 -- "$@" > "$log" 2>&1
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
run_step selftest --seed=20261101 --selftest
run_step selftest-load --seed=20261101 --selftest-load
run_step p11-tech --seed=20261101 --selftest-p11 --class=tech
run_step p11-red --seed=20261101 --selftest-p11 --class=red
run_step p11-mage --seed=20261101 --selftest-p11 --class=mage
run_step soak-tech-180s --seed=20261101 --soak --soak-secs=180
echo "W7 GATE CHAIN DONE $(date -u +%FT%TZ)" | tee -a $SUM
