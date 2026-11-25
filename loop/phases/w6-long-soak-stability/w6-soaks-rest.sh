#!/bin/bash
# W6 remaining soaks, sequential, detached: S3-fix (fixed map), S4 red, S5 mage.
PHASE=~/workspace/goals/game-off-2026-entry/deepfall-game/loop/phases/w6-long-soak-stability
"$PHASE/run-soak-detached.sh" w6-soak-s3fix-tech-91838678-600s 91838678 tech 600
"$PHASE/run-soak-detached.sh" w6-soak-s4-red-20261101-180s 20261101 red 180
"$PHASE/run-soak-detached.sh" w6-soak-s5-mage-20261101-180s 20261101 mage 180
echo "REST SOAKS DONE $(date -u +%FT%TZ)" >> "$PHASE/w6-soaks-rest.log"
