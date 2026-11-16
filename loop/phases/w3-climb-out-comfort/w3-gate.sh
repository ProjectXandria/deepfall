#!/bin/bash
# W3 climb-out gate chain on scratch copy. Sequential, one Godot at a time.
# Resumable: each step writes a .done marker only on rc=0 + 0 SCRIPT ERRORs
# (soak also needs SOAK_DONE in its log); re-running skips done steps.
# Soak timeout 1800: a 180s soak can take 10-20 min wall under llvmpipe.
S=~/workspace/goals/game-off-2026-entry/loop-scratch/w3-climb-out-comfort
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w3-climb-out-comfort
cd "$S" || exit 1
run() { # name, timeout, args...
  local name="$1"; shift; local to="$1"; shift
  if [ -f "$P/w3-$name.done" ]; then
    echo "$name SKIPPED (already done)"
    echo "$name SKIPPED (already done)" >> "$P/w3-gate-summary.txt"
    return 0
  fi
  echo "=== $name start $(date +%H:%M:%S) ==="
  timeout "$to" xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path . --resolution 2400x1080 -- "$@" > "$P/w3-$name.log" 2>&1
  local rc=$?
  local errs=$(grep -c "SCRIPT ERROR" "$P/w3-$name.log" || true)
  # W3 lesson: rc=0 + 0 errors is NOT a pass — the selftest prints
  # PASS=false per phase but still exits 0. Any PASS=false fails the step.
  local badpass=$(grep -c "PASS=false" "$P/w3-$name.log" || true)
  echo "$name rc=$rc errors=$errs passfalse=$badpass"
  echo "$name rc=$rc errors=$errs passfalse=$badpass" >> "$P/w3-gate-summary.txt"
  if [ "$rc" = "0" ] && [ "$errs" = "0" ] && [ "$badpass" = "0" ]; then
    if [[ "$name" == soak* ]]; then
      grep -q "SOAK_DONE" "$P/w3-$name.log" && touch "$P/w3-$name.done" || echo "$name NO SOAK_DONE, not marked done"
    elif [[ "$name" == climb* ]]; then
      grep -q "CLIMB_PROBE_PASS" "$P/w3-$name.log" && touch "$P/w3-$name.done" || echo "$name NO CLIMB_PROBE_PASS, not marked done"
    else
      touch "$P/w3-$name.done"
    fi
  fi
}
echo "=== W3 scratch gate chain start $(date) ===" >> "$P/w3-gate-summary.txt"
run selftest 600 --seed=20261101 --selftest
run p11-tech 600 --seed=20261101 --selftest-p11 --class=tech
run p11-red 600 --seed=20261101 --selftest-p11 --class=red
run p11-mage 600 --seed=20261101 --selftest-p11 --class=mage
run selftest-load 600 --seed=20261101 --selftest-load
run climb-probe 600 --seed=20261101 --climb-probe
run sweep-s2 600 --seed=20261102 --selftest
run sweep-s3 600 --seed=20261104 --selftest
run soak 1800 --seed=20261101 --soak --soak-secs=180 --class=tech
echo "=== W3 scratch gate chain done $(date) ===" >> "$P/w3-gate-summary.txt"
