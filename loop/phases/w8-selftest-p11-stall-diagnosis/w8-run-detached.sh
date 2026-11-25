#!/bin/bash
# w8-run-detached.sh <tag> <timeout_secs> <godot user args...>
# Detached Godot run on the W8 scratch copy. pgrep gate first (never launch
# into another agent's Godot run); writes <tag>.log + <tag>.done in the wave
# dir. Logs to workspace, never /tmp. setsid+nohup survives exec-session
# SIGTERM but NOT a full session restart — if interrupted, check disk state.
set -u
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w8-selftest-p11-stall-diagnosis
SCRATCH=~/workspace/goals/game-off-2026-entry/loop-scratch/w8-selftest-p11-stall-diagnosis
TAG="$1"; TIMEOUT="$2"; shift 2
LOG="$PHASE/w8-$TAG.log"
if pgrep -f "tools/godot/godot" >/dev/null; then
  echo "GODOT ALREADY RUNNING — refusing to launch $TAG" | tee "$LOG"
  exit 3
fi
rm -f "$PHASE/w8-$TAG.done"
setsid nohup bash -c "timeout $TIMEOUT xvfb-run -a -s '-screen 0 2560x1440x24' ~/tools/godot/godot --path $SCRATCH --resolution 2400x1080 -- $* > $LOG 2>&1; echo EXIT=\$? >> $LOG; touch $PHASE/w8-$TAG.done" >/dev/null 2>&1 &
echo "launched $TAG runner-pid=$! log=$LOG timeout=$TIMEOUT args: $*"
