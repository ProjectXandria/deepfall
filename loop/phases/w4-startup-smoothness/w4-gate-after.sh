#!/bin/bash
# W4 post-optimisation gate chain (scratch): dump-diff world identity on
# 3 seeds, load_ms after x3, profile x3, full gate suite. Solo sequential,
# xvfb, phone geometry. Any failure is recorded in the summary; the
# script exits non-zero if any check fails.
S=~/workspace/goals/game-off-2026-entry/loop-scratch/w4-startup-smoothness
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w4-startup-smoothness
G=~/tools/godot/godot
SAVE=~/.local/share/godot/app_userdata/"DEEPFALL Phase 1"/deepfall_save.json
FAIL=0
echo "=== W4 post-opt gate start $(date -u) ===" | tee "$P/w4-after-summary.txt"
cd "$S"

# --- 1. dump-diff: world identity on 3 seeds ---
for seed in 20261101 20261102 20261104; do
  rm -f "$SAVE"
  timeout 600 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=$seed --dump-layers > "$P/w4-dump-after-$seed.log" 2>&1
  rc=$?
  grep '^DUMP ' "$P/w4-dump-after-$seed.log" | sort > "$P/w4-dump-after-$seed.sorted"
  if diff -q "$P/w4-dump-before-$seed.sorted" "$P/w4-dump-after-$seed.sorted" > /dev/null; then
    dd="IDENTICAL"
  else
    dd="DIFFERS ($(diff "$P/w4-dump-before-$seed.sorted" "$P/w4-dump-after-$seed.sorted" | wc -l) diff lines)"
    FAIL=1
  fi
  ready=$(grep -o 'DEEPFALL_PHASE1_READY seed=[0-9]* rooms=[0-9]*/[0-9]* ore_veins=[0-9]* spawn=([0-9]*, [0-9]*) exit=([0-9]*, [0-9]*) connected=true' "$P/w4-dump-after-$seed.log" | head -1)
  echo "dump seed=$seed rc=$rc cells=$(wc -l < "$P/w4-dump-after-$seed.sorted") $dd READY[$ready]" | tee -a "$P/w4-after-summary.txt"
done

# --- 2. load_ms after x3 (plain launches, same form as baseline) ---
for i in 1 2 3; do
  rm -f "$SAVE"
  timeout 300 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 --screenshot > "$P/w4-after-load$i.log" 2>&1
  rc=$?
  echo "load$i rc=$rc $(grep -o 'load_ms=[0-9]*' "$P/w4-after-load$i.log" | tail -1) errors=$(grep -c 'SCRIPT ERROR' "$P/w4-after-load$i.log")" | tee -a "$P/w4-after-summary.txt"
done

# --- 3. profile after x3 (stage breakdown for the report) ---
for i in 1 2 3; do
  rm -f "$SAVE"
  timeout 300 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 --screenshot --profile > "$P/w4-after-profile$i.log" 2>&1
  rc=$?
  echo "profile$i rc=$rc $(grep -o 'load_ms=[0-9]*' "$P/w4-after-profile$i.log" | tail -1) errors=$(grep -c 'SCRIPT ERROR' "$P/w4-after-profile$i.log")" | tee -a "$P/w4-after-summary.txt"
done

# --- 4. full gate suite ---
run_gate() { # name, extra args...
  local name="$1"; shift
  rm -f "$SAVE"
  timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 "$@" > "$P/w4-after-$name.log" 2>&1
  local rc=$?
  local err=$(grep -c 'SCRIPT ERROR' "$P/w4-after-$name.log")
  local pf=$(grep -c 'PASS=false' "$P/w4-after-$name.log")
  echo "$name rc=$rc errors=$err passfalse=$pf" | tee -a "$P/w4-after-summary.txt"
  if [ "$rc" != "0" ] || [ "$err" != "0" ] || [ "$pf" != "0" ]; then FAIL=1; fi
}
run_gate selftest --selftest
run_gate p11-tech --selftest-p11
run_gate p11-red --selftest-p11 --class=red
run_gate p11-mage --selftest-p11 --class=mage
run_gate selftest-load --selftest-load
echo "=== W4 post-opt gate done $(date -u) FAIL=$FAIL ===" | tee -a "$P/w4-after-summary.txt"
exit $FAIL
