#!/bin/bash
# W4 baseline: 3 plain launches (load_ms) + full gate suite, solo sequential, xvfb.
S=~/workspace/goals/game-off-2026-entry/loop-scratch/w4-startup-smoothness
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w4-startup-smoothness
G=~/tools/godot/godot
SAVE=~/.local/share/godot/app_userdata/"DEEPFALL Phase 1"/deepfall_save.json
cd "$S"
echo "=== W4 baseline start $(date -u) ===" | tee "$P/w4-baseline-summary.txt"
for i in 1 2 3; do
  rm -f "$SAVE"
  timeout 300 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 --screenshot > "$P/w4-baseline-load$i.log" 2>&1
  rc=$?
  echo "load$i rc=$rc $(grep -o 'load_ms=[0-9]*' "$P/w4-baseline-load$i.log" | tail -1) errors=$(grep -c 'SCRIPT ERROR' "$P/w4-baseline-load$i.log")" | tee -a "$P/w4-baseline-summary.txt"
done
run_gate() { # name, extra args...
  local name="$1"; shift
  rm -f "$SAVE"
  timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 "$@" > "$P/w4-baseline-$name.log" 2>&1
  local rc=$?
  local err=$(grep -c 'SCRIPT ERROR' "$P/w4-baseline-$name.log")
  local pf=$(grep -c 'PASS=false' "$P/w4-baseline-$name.log")
  echo "$name rc=$rc errors=$err passfalse=$pf" | tee -a "$P/w4-baseline-summary.txt"
}
run_gate selftest --selftest
run_gate p11-tech --selftest-p11
run_gate p11-red --selftest-p11 --class=red
run_gate p11-mage --selftest-p11 --class=mage
run_gate selftest-load --selftest-load
echo "=== W4 baseline done $(date -u) ===" | tee -a "$P/w4-baseline-summary.txt"
