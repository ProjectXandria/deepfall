#!/bin/bash
# W2 option (a) drift chain on scratch copy. Sequential, one Godot at a time.
S=~/workspace/goals/game-off-2026-entry/loop-scratch/w2-deep-cave-encounters
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w2-deep-cave-encounters
cd "$S" || exit 1
run() { # name, timeout, args...
  local name="$1"; shift; local to="$1"; shift
  echo "=== $name start $(date +%H:%M:%S) ==="
  timeout "$to" xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path . --resolution 2400x1080 -- "$@" > "$P/w2-opta-$name.log" 2>&1
  local rc=$?
  local errs=$(grep -c "SCRIPT ERROR" "$P/w2-opta-$name.log" || true)
  echo "$name rc=$rc errors=$errs"
  echo "$name rc=$rc errors=$errs" >> "$P/w2-gate-opta-summary.txt"
}
echo "=== W2 OPT-A (drift) scratch gate chain start $(date) ===" > "$P/w2-gate-opta-summary.txt"
run selftest 600 --seed=20261101 --selftest
run p11-tech 600 --seed=20261101 --selftest-p11 --class=tech
run p11-red 600 --seed=20261101 --selftest-p11 --class=red
run p11-mage 600 --seed=20261101 --selftest-p11 --class=mage
run selftest-load 600 --seed=20261101 --selftest-load
run soak-s1 1200 --seed=20261101 --soak --soak-secs=180 --class=tech
run soak-s2 1200 --seed=20261102 --soak --soak-secs=180 --class=tech
run soak-s3 1200 --seed=20261103 --soak --soak-secs=180 --class=tech
echo "=== W2 OPT-A scratch gate chain done $(date) ===" >> "$P/w2-gate-opta-summary.txt"
