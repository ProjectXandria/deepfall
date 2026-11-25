#!/bin/bash
# W6 detached soak runner: survives agent-session SIGTERM (setsid+nohup).
# Usage: run-soak-detached.sh <tag> <seed> <class> <secs> [extra args...]
# Writes <tag>.log and <tag>.done (rc + timestamp) in the phase dir.
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w6-long-soak-stability
SCRATCH=~/workspace/goals/game-off-2026-entry/loop-scratch/w6-long-soak-stability
TAG="$1"; SEED="$2"; CLASS="$3"; SECS="$4"
cd "$SCRATCH" || exit 1
timeout ${SOAK_TIMEOUT:-1800} xvfb-run -a -s "-screen 0 2560x1440x24" ~/tools/godot/godot --path . --resolution 2400x1080 -- --seed="$SEED" --soak --soak-secs="$SECS" --class="$CLASS" > "$PHASE/$TAG.log" 2>&1
RC=$?
echo "rc=$RC finished=$(date -u +%FT%TZ)" > "$PHASE/$TAG.done"
exit $RC
