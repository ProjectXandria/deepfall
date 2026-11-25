#!/bin/bash
# W5 scratch gate chain: full suite on the SCRATCH tree.
# Solo sequential, xvfb, phone geometry. Fails on rc != 0, any
# SCRIPT ERROR, or any PASS=false (W3 incident lesson).
S=~/workspace/goals/game-off-2026-entry/loop-scratch/w5-animation-gaps
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w5-animation-gaps
G=~/tools/godot/godot
SAVE=~/.local/share/godot/app_userdata/"DEEPFALL Phase 1"/deepfall_save.json
FAIL=0
echo "=== W5 scratch gate chain start $(date -u) ===" | tee "$P/w5-gate-scratch-summary.txt"
cd "$S"
run_gate() { # name, extra args...
  local name="$1"; shift
  rm -f "$SAVE"
  timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 "$@" > "$P/w5-scratch-$name.log" 2>&1
  local rc=$?
  local err=$(grep -c 'SCRIPT ERROR' "$P/w5-scratch-$name.log")
  local pf=$(grep -c 'PASS=false' "$P/w5-scratch-$name.log")
  echo "$name rc=$rc errors=$err passfalse=$pf" | tee -a "$P/w5-gate-scratch-summary.txt"
  if [ "$rc" != "0" ] || [ "$err" != "0" ] || [ "$pf" != "0" ]; then FAIL=1; fi
}
run_gate selftest --selftest
run_gate p11-tech --selftest-p11
run_gate p11-red --selftest-p11 --class=red
run_gate p11-mage --selftest-p11 --class=mage
run_gate selftest-load --selftest-load
echo "=== W5 scratch gate chain done $(date -u) FAIL=$FAIL ===" | tee -a "$P/w5-gate-scratch-summary.txt"
exit $FAIL
