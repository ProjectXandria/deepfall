#!/bin/bash
# W3 live re-gate on the merged live tree. Sequential, one Godot at a time.
# Same steps as the scratch chain (w3-gate.sh), logs w3-live-*.log.
# Soak timeout 1800: a 180s soak can take 10-20 min wall under llvmpipe.
L=~/workspace/goals/game-off-2026-entry/deepfall-game
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w3-climb-out-comfort
cd "$L" || exit 1
run() { # name, timeout, args...
  local name="$1"; shift; local to="$1"; shift
  echo "=== live-$name start $(date +%H:%M:%S) ==="
  timeout "$to" xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path . --resolution 2400x1080 -- "$@" > "$P/w3-live-$name.log" 2>&1
  local rc=$?
  local errs=$(grep -c "SCRIPT ERROR" "$P/w3-live-$name.log" || true)
  # W3 lesson: rc=0 + 0 errors is NOT a pass — the selftest prints
  # PASS=false per phase but still exits 0. Any PASS=false fails the step.
  local badpass=$(grep -c "PASS=false" "$P/w3-live-$name.log" || true)
  echo "live-$name rc=$rc errors=$errs passfalse=$badpass"
  echo "live-$name rc=$rc errors=$errs passfalse=$badpass" >> "$P/w3-gate-live-summary.txt"
  if [ "$rc" = "0" ] && [ "$errs" = "0" ] && [ "$badpass" = "0" ]; then
    if [[ "$name" == soak* ]]; then
      grep -q "SOAK_DONE" "$P/w3-live-$name.log" && touch "$P/w3-live-$name.done" || echo "live-$name NO SOAK_DONE, not marked done"
    elif [[ "$name" == climb* ]]; then
      grep -q "CLIMB_PROBE_PASS" "$P/w3-live-$name.log" && touch "$P/w3-live-$name.done" || echo "live-$name NO CLIMB_PROBE_PASS, not marked done"
    else
      touch "$P/w3-live-$name.done"
    fi
  fi
}
echo "=== W3 live gate chain start $(date) ===" >> "$P/w3-gate-live-summary.txt"
run selftest 600 --seed=20261101 --selftest
run p11-tech 600 --seed=20261101 --selftest-p11 --class=tech
run p11-red 600 --seed=20261101 --selftest-p11 --class=red
run p11-mage 600 --seed=20261101 --selftest-p11 --class=mage
run selftest-load 600 --seed=20261101 --selftest-load
run climb-probe 600 --seed=20261101 --climb-probe
run soak 1800 --seed=20261101 --soak --soak-secs=180 --class=tech
echo "=== W3 live gate chain done $(date) ===" >> "$P/w3-gate-live-summary.txt"
