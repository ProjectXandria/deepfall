#!/bin/bash
# W9 SCRATCH gate after the _rebuild_world card-state fix
# (clear _card_open/_card_pending/_card_reason/_respawn_timer/player.dead
# at _rebuild_world entry) into the live tree.
# Fails a step on rc!=0, any SCRIPT ERROR, or any PASS=false.
# The p11 suite prints NO PASS verdict, so p11 steps ALSO fail unless
# the anchor values are present (W8 lesson from run F2: a corrupted
# p11 run exits 0 with 12 failed checks and no verdict line).
TREE=~/workspace/goals/game-off-2026-entry/loop-scratch/w9-card-state-hardening-docs-refresh
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w9-card-state-hardening-docs-refresh
SUM=$PHASE/w9-gate-scratch-summary.txt
: > $SUM
run_step() {
  local tag="$1"; shift
  local log="$PHASE/w9-gate-scratch-$tag.log"
  echo "=== $tag ===" | tee -a $SUM
  timeout 600 xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path "$TREE" --resolution 2400x1080 -- "$@" > "$log" 2>&1
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
check_p11() {
  # $1 = tag, $2 = expected sword line fragment, e.g. "golem_hp 50->35"
  local tag="$1"; local sword="$2"
  local log="$PHASE/w9-gate-scratch-$tag.log"
  local ok=OK
  for pat in "pot_broken=true" "$sword" "DEEPFALL_P14 done" "touch_jump=true rose=110.7" "slam ghoul_hp 20->10" "dash dx=146.0"; do
    if ! grep -q "$pat" "$log"; then echo "  MISSING: $pat" | tee -a $SUM; ok=FAIL; fi
  done
  echo "p11-values $tag -> $ok" | tee -a $SUM
}
# Full suite, proper order (load test right after selftest, before p11)
run_step selftest --seed=20261101 --selftest
run_step selftest-load --seed=20261101 --selftest-load
run_step p11-tech --seed=20261101 --selftest-p11 --class=tech
check_p11 p11-tech "golem_hp 50->35"
run_step p11-red --seed=20261101 --selftest-p11 --class=red
check_p11 p11-red "golem_hp 50->30"
run_step p11-mage --seed=20261101 --selftest-p11 --class=mage
check_p11 p11-mage "golem_hp 50->38"
# No-class form: the original stall report — must also pass on live
run_step p11-noclass --seed=20261101 --selftest-p11
check_p11 p11-noclass "golem_hp 50->35"
echo "SCRATCH GATE CHAIN DONE $(date -u +%FT%TZ)" | tee -a $SUM
