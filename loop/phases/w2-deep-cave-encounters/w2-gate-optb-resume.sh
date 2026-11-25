#!/bin/bash
# W2 opt-B chain RESUME after runtime restart killed it mid p11-red.
# selftest + p11-tech already rc=0 errors=0; resume from p11-red.
S=~/workspace/goals/game-off-2026-entry/loop-scratch/w2-deep-cave-encounters
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w2-deep-cave-encounters
cd "$S" || exit 1
run() { # name, timeout, args...
  local name="$1"; shift; local to="$1"; shift
  echo "=== $name start $(date +%H:%M:%S) ==="
  timeout "$to" xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path . --resolution 2400x1080 -- "$@" > "$P/w2-optb-$name.log" 2>&1
  local rc=$?
  local errs=$(grep -c "SCRIPT ERROR" "$P/w2-optb-$name.log" || true)
  echo "$name rc=$rc errors=$errs"
  echo "$name rc=$rc errors=$errs" >> "$P/w2-gate-optb-summary.txt"
}
echo "=== W2 OPT-B resume $(date) (restart recovery; selftest+p11-tech already green) ===" >> "$P/w2-gate-optb-summary.txt"
run p11-red 600 --seed=20261101 --selftest-p11 --class=red
run p11-mage 600 --seed=20261101 --selftest-p11 --class=mage
run selftest-load 600 --seed=20261101 --selftest-load
run soak-s1 1800 --seed=20261101 --soak --soak-secs=180 --class=tech
run soak-s2 1800 --seed=20261102 --soak --soak-secs=180 --class=tech
run soak-s3 1800 --seed=20261103 --soak --soak-secs=180 --class=tech
echo "=== W2 OPT-B scratch gate chain done $(date) ===" >> "$P/w2-gate-optb-summary.txt"
