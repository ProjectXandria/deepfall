#!/bin/bash
# W6 LIVE re-gate after merging map_gen.gd (repair-leg fix) into the live tree.
# Fails a step on rc!=0, any SCRIPT ERROR, or any PASS=false.
LIVE=~/workspace/goals/game-off-2026-entry/deepfall-game
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w6-long-soak-stability
SUM=$PHASE/w6-gate-live-summary.txt
: > $SUM
run_step() {
  local tag="$1"; shift
  local log="$PHASE/w6-gate-live-$tag.log"
  echo "=== $tag ===" | tee -a $SUM
  timeout 600 xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path "$LIVE" --resolution 2400x1080 -- "$@" > "$log" 2>&1
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
# 1. bug seed on live: must be 40/40 connected=true now
timeout 120 xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path "$LIVE" --resolution 2400x1080 -- --seed=91838678 --dump-map > "$PHASE/w6-gate-live-dumpmap-91838678.log" 2>&1
echo "dumpmap 91838678 rc=$? $(grep -E 'DEEPFALL_PHASE1_READY' "$PHASE/w6-gate-live-dumpmap-91838678.log" | tail -1)" | tee -a $SUM
# 2. full suite, proper order (load test right after selftest, before p11)
run_step selftest --seed=20261101 --selftest
run_step selftest-load --seed=20261101 --selftest-load
run_step p11-tech --seed=20261101 --selftest-p11 --class=tech
run_step p11-red --seed=20261101 --selftest-p11 --class=red
run_step p11-mage --seed=20261101 --selftest-p11 --class=mage
echo "LIVE GATE CHAIN DONE $(date -u +%FT%TZ)" | tee -a $SUM
