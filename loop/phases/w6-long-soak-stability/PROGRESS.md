# W6 — Long Soak Stability — PROGRESS NOTE (updated as runs complete)

- Wave: w6-long-soak-stability. Spawned 2026-11-13 17:25 PST from main chat (Skit: "Continue" 17:22 PST).
- Start state verified: live tree = Phase 14b + W1–W5 (main.gd 230,615 B, mtime Nov 13 07:28; map_gen.gd 11,376 B; enemy.gd 13,588 B). No Godot running at spawn. queue.json W1–W5 done, W6/W7 pending. state.json active=w6-long-soak-stability.
- Scratch: `~/workspace/goals/game-off-2026-entry/loop-scratch/w6-long-soak-stability/` — rsync copy of deepfall-game/ WITHOUT exports/. `diff -rq scripts` clean vs live at setup.
- Method: solo, sequential, one Godot run at a time; xvfb-run -a -s "-screen 0 2560x1440x24", --resolution 2400x1080, Godot 4.8 beta 1. Soak form: `-- --seed=<N> --soak --soak-secs=<N>` (both flags — W1 lesson).
- Fresh seeds rolled 2026-11-13 17:25 PST: **57109915** and **91838678**. Anchor seed 20261101.

## Planned runs (all tech unless noted)

| # | seed | class | secs | status |
|---|------|-------|------|--------|
| S1 | 20261101 | tech | 600 | RUNNING (started ~17:26 PST, log w6-soak-s1-tech-20261101-600s.log) |
| S2 | 57109915 | tech | 600 | pending |
| S3 | 91838678 | tech | 600 | pending |
| S4 | 20261101 | red | 180 | pending |
| S5 | 20261101 | mage | 180 | pending |

## Results (fill as runs complete)

### INCIDENT — exec-session SIGTERM kills soaks (2026-11-13 ~17:36 + ~17:38 PST)
- S1 first attempt (backgrounded exec): session SIGTERMed at 668 s wall; log ends t=334, NO SOAK_DONE. S2 attempt: session SIGTERMed after ~90 s wall; log ends t=30. In both cases the Godot child died with the session.
- Root cause (working theory): backgrounded exec sessions are tied to the agent session and get SIGTERMed when it is interrupted/restarted; detached setsid+nohup processes survive (W2 precedent: a backgrounded chain finished after its agent died).
- Fix: all soaks now run DETACHED via `run-soak-detached.sh` (setsid + nohup, `timeout 1800`, writes `<tag>.log` + `<tag>.done`). Partial logs preserved as `-PARTIAL-t334` / `-PARTIAL-t30`.
- S1 partial (334/600 soak-s) is still usable evidence — see Findings below.
- Wall-time factor: 334 soak-s took ~660 wall-s (~2.0x) at sandbox fps 3–7. A 600 s soak needs ~20 min wall; `timeout 1800` covers it. 180 s soaks need ~6 min wall.

### S1 partial (first attempt, seed 20261101, tech, t=0–334 of 600)
- No SOAK_DONE (killed). 0 deaths, hp 100 throughout. kills=0, mined=0 at t=330.
- 17 SOAK_STUCK events; CLIMB_END climb=12/27/30/30/30/37/38 (max 38 rows). Rooms visited: 0, 4, 2, 3 (4 rooms).
- foes=0 tick stretches: t=30–40, t=70–110 (40 s), t=230–250. None >120 s in ticks.
- fps 3–7.

### S1 DONE (redo, detached) — seed 20261101, tech, 600 s — rc=0, 0 SCRIPT ERRORs
- Finished 2026-11-14T02:08:00Z (~29 min wall, ~2.9x). READY byte-identical: rooms=40/40 ore_veins=138 spawn=(10,44) exit=(190,42) connected=true, load_ms=1790.
- SOAK_DONE: deaths=0 stuck=27 kills=0 mined=6 rooms=4 climb=39 deep=56 fps_min=1 fps_avg=3 foes0=224 foes0max=53 near0=600.
- Stuck clusters (27 events): A — fall shaft rows 46–56 x22–26 (t=16–137, 5 events); B — mid rows 32–35 (t=187–236, 3 events); C — upper band rows 19–24 x10–28 (t=261–578, 19 events, dominant).
- foes=0: total 224 s of 600; longest unbroken stretch 53 s (foes0max) — under the 120 s named-finding threshold, but the late run t=510–600 shows foes=0 on every 10 s tick.
- FINDING S1-NOCOMBAT: near0=600 — no foe within the bot's 280 px encounter radius for the ENTIRE run; kills=0, mined=6. The bot wandered/climbed 600 s and never entered combat range. Partly bot behavior (random walk, no foe-seeking; beta 180 s soak did get 2 kills), so NOT a proven game bug — but this run proves no-crash/no-death, not combat stability. S2/S3 + red/mage soaks may add combat data.

### S2 DONE (detached) — seed 57109915, tech, 600 s — rc=0, 0 SCRIPT ERRORs
- Finished 2026-11-14T02:28:37Z (~17 min wall). READY: rooms=40/40 ore_veins=92 spawn=(7,69) exit=(190,18) connected=true, load_ms=3071.
- SOAK_DONE: deaths=0 stuck=29 kills=5 mined=47 rooms=4 climb=4 deep=84 fps_min=1 fps_avg=5 foes0=0 foes0max=0 near0=560.
- FINDING S2-DEEP-FLOOR-CAMP: bot reached row 84 by ~t=108 and stayed on rows 82–84 for the rest of the run; 23 of 29 stuck events on that floor band (x44–69, t=117–596); only one climb (climb=4, t=48). The W3 climb-out guarantee still stands as a probe (10 rows, deterministic) and S1 climbed 39 — but on this seed the bot never tried to climb, because the deep floor is roomy and foe-rich. Bot artifact + map shape, NOT a proven game defect; the run exercised deep-floor combat/mining only.
- Combat DID happen here (unlike S1): kills=5, hp 100 → 92 → 76 (held at 76 for the last ~48 ticks), foes 3–9 in window on most ticks, foes0=0 (never zero). near0=560: only ~40 s total with a foe inside the 280 px radius — the 5 kills came in that window.

### S3 DONE (detached) — seed 91838678, tech, 600 s — rc=0, 0 SCRIPT ERRORs
- Finished 2026-11-14T03:00:21Z (~24 min wall). READY: rooms=**39/40** ore_veins=139 spawn=(6,68) exit=(188,70) **connected=false** — see bug finding below.
- SOAK_DONE: deaths=0 stuck=22 kills=6 mined=44 rooms=4 climb=3 deep=83 fps_min=1 fps_avg=4 foes0=88 foes0max=68 near0=574.
- Stuck: 22 events, ALL rows 81–83 x21–47 (deep-floor band, same pattern as S2). Rooms visited: 0, 5, 8, 2. hp 100 → 68 by t=100, held at 68. foes0max=68 (< 120 s threshold). near0=574 (only ~26 s with a foe in radius; 6 kills in that window).

### BUG FOUND — map-gen connectivity fails on a fresh seed (W6's one game fix)
- **Finding:** seed 91838678 generates rooms=39/40, connected=false — the first non-connected map seen. Diagnostic (`DEEPFALL_W6_UNREACHED`, scratch map_gen.gd): room **[180, 76, 14, 10], center (187, 81)** is unreachable even after the repair pass. It is NOT the exit room (exit is [183, 62, 10, 10], cell (188, 70)); the exit stayed reachable and the run was completable by mining, but the game's own connectivity guarantee failed.
- **Root cause (verified from code + MAP_LEGS):** the spanning-tree leg into that room is `[188, 67, 81]` (from the exit room's center) and the repair leg is `[187, 66, 81]` — both vertical shafts at x187..189 crossing the exit room's floor row 71. The exit room's brick floor (whole bottom row → tile 8, laid after corridors) severs the shaft first; the repair re-carves it, then the floor guard's SOLID re-fill severs it again. The repair is futile for this geometry — deterministic, not flaky.
- **Fix (scratch map_gen.gd only, repair path only):** the repair corridor shifts its vertical leg to a slot inside the target room that avoids the severed spans — the exit room's whole floor row and the spawn anchor's 3 SOLID cells. Tries center, then left edge (r[0]), then right edge (r[0]+r[2]-3); falls back to center if all blocked (no worse than today). No RNG calls; repair runs only when a room is unreached.
- **Verification of the fix (--dump-map):** 91838678 → **40/40, ore 139 (unchanged), connected=true**, no UNREACHED. 20261101 → READY byte-identical (40/40, ore 138, spawn (10,44), exit (190,42), connected=true). 57109915 → 40/40, ore 92, spawn (7,69), exit (190,18), connected=true (unchanged). 0 SCRIPT ERRORs in all three logs.
- **Seed sweep (post-fix, --dump-map):** 34288107 (40/40, ore 104, connected=true), 71509382 (40/40, ore 118, true), 10455829 (40/40, ore 94, true), 88204713 + 29063451 pending in the gate chain. (Note: sweep used the seeds hardcoded in the gate script, not the python roll printed alongside — all five are fresh 8-digit seeds; the python roll was redundant.)
- **Full scratch gates after the fix:** running in the detached gate chain (selftest → proper selftest-load → p11 tech/red/mage; each step fails on rc!=0, SCRIPT ERROR, or PASS=false). S3 re-soak (600 s, fixed map) + S4/S5 still to run.

### S4 DONE (detached) — seed 20261101, red, 180 s — rc=0, 0 SCRIPT ERRORs
- Finished 2026-11-14T04:06:29Z. READY byte-identical (40/40, ore 138, spawn (10,44), exit (190,42), connected=true; load_ms=5808 — sandbox CPU noise, same phenomenon as W2's 8121 ms read; the READY fields that matter are identical).
- SOAK_DONE: deaths=0 stuck=7 kills=0 mined=2 rooms=4 climb=36 deep=54 fps_min=1 fps_avg=2 foes0=28 foes0max=15 near0=180.
- Red climbed 36 rows (matches W3's live climb=36). near0=180: no foe in radius the whole run; kills=0.

### S5 DONE (detached) — seed 20261101, mage, 180 s — rc=0, 0 SCRIPT ERRORs (verify at report time)
- Finished 2026-11-14T04:16:12Z.
- SOAK_DONE: deaths=0 stuck=5 kills=0 mined=0 rooms=3 climb=27 deep=56 fps_min=1 fps_avg=3 foes0=70 foes0max=50 near0=180.
- Mage: 0 kills, 0 mined, near0=180 (whole run). foes0max=50 (< 120 s).

### S3-fix (fixed map, seed 91838678, tech, 600 s) — TWO FAILED ATTEMPTS, re-run pending
- Attempt 1: killed by the runner's `timeout 1800` at t=520/600 (rc=124), 0 SCRIPT ERRORs, mined=44, slain=4. The 600 s soak needs up to ~30+ min wall at sandbox fps; 1800 s is too tight on a slow run. Partial log preserved as `-ATTEMPT1-t520`. Runner now takes `SOAK_TIMEOUT` (default 1800); the re-run uses 3600.
- Attempt 2: launched 04:25 UTC while ANOTHER agent's Godot run (`--selftest-p11` on the LIVE tree, log `loop/selftest-p11-kaykit-solo-2026-11-14.log`, mage) was already running — my launch command's pgrep check ran in the same command as the launch, so I never saw it before launching. My error: check-then-launch must be two separate steps. Killed my soak ~7 min in (log t=10; the kill needed explicit PIDs — the process-group kill left the timeout/godot alive; direct `kill -TERM` on the Godot/timeout/runner PIDs worked). Partial log preserved as `-ATTEMPT2-t10-killed`. The kaykit run's early phase ran under concurrent CPU load (its READY load_ms=1637, in the normal range); its later checks ran solo after my kill — note this honestly if citing it.
- Re-run (attempt 3, SOAK_TIMEOUT=3600) launches ONLY after the kaykit Godot exits. Waiter set.
- 04:52: kaykit run still going (34 min elapsed, 43:25 CPU — progressing, not stuck; likely `--selftest-p11` with NO --class runs all 3 classes sequentially, ~3x a single-class run).
- 05:03: kaykit run hit its `timeout 2700` (45 min) and was killed; log ends at READY, no P11 verdict — that run produced nothing usable. Its wrapper immediately started an A/B experiment on the LIVE tree: removed `skeleton-warrior` from ENEMY_SLUGS in live main.gd (backup at /tmp/main-kaykit-backup.gd, 230,857 B, sha 6cda5f186f891529, count 1), runs `--selftest-p11` capped at 300 s (`loop/selftest-p11-ab-noskeleton-2026-11-14.log`), then restores main.gd from the backup and diffs. Live main.gd is MUTATED right now (count 0, sha 91dc6754598e4629) — NOT my doing, NOT part of W6. Before my live re-gate I MUST verify the restore (live main.gd back to sha 6cda5f186f891529, count 1); if the restore failed, flag it, do not gate a mutated tree. My merge touches map_gen.gd only, never main.gd. S3-fix attempt 3 still waits for the A/B run to finish.
- 05:12: A/B run done, live main.gd RESTORED (count 1, sha 6cda5f186f891529 ✓). Its log REPRODUCES the W6 bug on the live (unfixed) tree: seed 91838678 rooms=39/40 connected=false — independent corroboration. No Godot running.
- MEMORY.md update from the kaykit thread (read 05:12): (a) KayKit packs were applied to the LIVE tree — Skeleton Warrior 7th enemy slug `skeleton-warrior` (hp 25, speed 80, dmg 8, aggro 280) + chest prop; my scratch copy predates this, so after my merge the live-vs-scratch diff will show the KayKit additions as live-only — expected, not W6, report it. (b) **Selftest-p11 STALL is pre-existing, not KayKit, not W6:** `--selftest-p11` with NO --class stalls after READY (45-min solo run + two earlier runs + the A/B arm at 300 s, EXIT 124, identical with skeleton removed). My W6 gates used `--selftest-p11 --class=X` (single class) and DID complete with full P11/P14 lines — the stall is specific to the no-class (all-classes) invocation. Out of W6 scope (refine-only; the stall is a test-harness stall, not a game crash); report honestly that the no-class full-suite command cannot complete in this sandbox, per-class gates are green.
- 05:12:24: S3-fix ATTEMPT 3 launched (SOAK_TIMEOUT=3600), shell-gated on no-Godot. Waiter set (25 min).
- 05:14:38: the waiter was SIGTERMed at 128 s AND attempt 3 died with it — log ends cleanly at t=100 (hp 84, kills 2, mined 10, 0 errors), no .done, no Godot, runner gone. The whole setsid tree was killed at once (bash died too, so no .done was written — NOT a game crash). Cause: this was a full session restart/compaction (my context was compacted at this point), not a single-exec SIGTERM. CORRECTED RULE: setsid+nohup survives exec-session SIGTERM but NOT a session restart/compaction. Preserved as `-ATTEMPT3-t100-killed`.
- 05:36:07: S3-fix ATTEMPT 4 launched (SOAK_TIMEOUT=3600), shell-gated solo. Waiter set (20 min).
- 05:57:21: S3-fix ATTEMPT 4 DONE rc=0 — SOAK_DONE deaths=0 stuck=25 kills=5 mined=51 rooms=4 climb=3 deep=83 fps_min=2 fps_avg=4 foes0=20 foes0max=6 near0=570. 0 SCRIPT ERRORs, READY 40/40 ore 139 connected=true, UNREACHED trips 0. Stuck all rows 81–82 (deep-floor band, same as pre-fix).
- 06:02–06:06: map_gen.gd merged to live by explicit cp (sha 13b0594b… identical); live re-gate ALL OK (dumpmap 91838678 40/40 connected=true; selftest, selftest-load PASS=true, p11 tech 50→35 / red 50→30 / mage 50→38, P14 1.50/110.7; all rc=0 errors=0 passfalse=0).
- 06:27: REPORT.md written; queue.json W6 done; state.json active=null, log entry appended. W6 DONE. No Godot running. W7 is the main agent's, not mine.

### Runs (detached)
| # | seed | class | secs | status |
|---|------|-------|------|--------|
| S1 redo | 20261101 | tech | 600 | DONE rc=0 (see above) |
| S2 | 57109915 | tech | 600 | DONE rc=0 (see above) |
| S3 | 91838678 | tech | 600 | DONE rc=0 (see above; pre-fix map) |
| S3-fix | 91838678 | tech | 600 | ATTEMPT 1 killed t=520 by timeout 1800; ATTEMPT 2 killed t=10 (my launch error — concurrent run); ATTEMPT 3 pending after kaykit run exits |
| S4 | 20261101 | red | 180 | DONE rc=0 (see above) |
| S5 | 20261101 | mage | 180 | DONE rc=0 (see above) |

## Findings

(none yet — any stuck cluster or foes=0 stretch >120s gets a named finding with position/seed)

## Fixes

(none expected unless a crash/bug is found; if found, minimal fix on scratch + full re-gate + explicit file-copy merge + live re-gate)

## Gate status

- All soaks rc=0, 0 SCRIPT ERRORs: pending.
