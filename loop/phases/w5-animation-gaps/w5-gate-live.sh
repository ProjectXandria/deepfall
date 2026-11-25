#!/bin/bash
# W5 live re-gate after merge: full suite on the LIVE tree.
# Solo sequential, xvfb, phone geometry. Fails on rc != 0, any
# SCRIPT ERROR, or any PASS=false (W3 incident lesson).
# The plain --selftest-load step is vacuous on its own (it deletes
# the save first, so it prints "FAIL no save file found" — W4
# lesson); the proper sequence is load-setup (--selftest, creates
# the save) then load-proper (--selftest-load with the save present).
S=~/workspace/goals/game-off-2026-entry/deepfall-game
P=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w5-animation-gaps
G=~/tools/godot/godot
SAVE=~/.local/share/godot/app_userdata/"DEEPFALL Phase 1"/deepfall_save.json
FAIL=0
echo "=== W5 live gate chain start $(date -u) ===" | tee "$P/w5-gate-live-summary.txt"
cd "$S"
run_gate() { # name, extra args...
  local name="$1"; shift
  rm -f "$SAVE"
  timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 "$@" > "$P/w5-live-$name.log" 2>&1
  local rc=$?
  local err=$(grep -c 'SCRIPT ERROR' "$P/w5-live-$name.log")
  local pf=$(grep -c 'PASS=false' "$P/w5-live-$name.log")
  echo "$name rc=$rc errors=$err passfalse=$pf" | tee -a "$P/w5-gate-live-summary.txt"
  if [ "$rc" != "0" ] || [ "$err" != "0" ] || [ "$pf" != "0" ]; then FAIL=1; fi
}
run_gate selftest --selftest
run_gate p11-tech --selftest-p11
run_gate p11-red --selftest-p11 --class=red
run_gate p11-mage --selftest-p11 --class=mage
run_gate selftest-load --selftest-load
# Proper load sequence: selftest creates the save, then load reads it.
rm -f "$SAVE"
timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 --selftest > "$P/w5-live-load-setup.log" 2>&1
timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" "$G" --path "$S" --resolution 2400x1080 -- --seed=20261101 --selftest-load > "$P/w5-live-selftest-load-proper.log" 2>&1
rc=$?
err=$(grep -c 'SCRIPT ERROR' "$P/w5-live-selftest-load-proper.log")
pf=$(grep -c 'PASS=false' "$P/w5-live-selftest-load-proper.log")
echo "selftest-load-proper rc=$rc errors=$err passfalse=$pf" | tee -a "$P/w5-gate-live-summary.txt"
if [ "$rc" != "0" ] || [ "$err" != "0" ] || [ "$pf" != "0" ]; then FAIL=1; fi
echo "=== W5 live gate chain done $(date -u) FAIL=$FAIL ===" | tee -a "$P/w5-gate-live-summary.txt"
exit $FAIL
