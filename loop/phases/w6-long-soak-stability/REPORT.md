# W6 — Long-Soak Stability — REPORT

**Wave:** `w6-long-soak-stability` · **Date:** 2026-11-13/14 · **Scope:** DEEPFALL only, refine-only, local only.
**Brief:** no game changes unless a crash/bug is found (then fix minimally and re-run). `--soak` 600 s on 3 seeds (20261101 + 2 fresh), tech, plus 180 s each for red and mage. Record deaths/stuck/kills/mined/fps_min/fps_avg per run and rooms visited. Any stuck cluster or foes=0 stretch over 120 s gets a named finding with position/seed, not a silent pass. Gates: all soaks rc=0, 0 SCRIPT ERRORs.

**Verdict: DONE — one real bug found and fixed (map-gen connectivity, seed 91838678), all soaks and all gates green after the fix. No deaths in any run. No foes=0 stretch over 120 s in any run (longest: 68 s, pre-fix S3).**

## Soak results

All runs: Godot 4.8 beta 1, `xvfb-run -a -s "-screen 0 2560x1440x24" --resolution 2400x1080`, `-- --seed=<N> --soak --soak-secs=<N> --class=<class>`. `rooms` = distinct rooms visited (SOAK_ROOM count). `foes0` = seconds with zero foes in the bot's window; `foes0max` = longest unbroken such stretch. `near0` = seconds with no foe within the bot's 280 px encounter radius.

| Run | Seed | Class | Dur | Deaths | Stuck | Kills | Mined | Rooms | Climb | Deep | fps_min | fps_avg | foes0 | foes0max | near0 | rc | SCRIPT ERRORs |
|-----|------|-------|-----|--------|-------|-------|-------|-------|-------|------|---------|---------|-------|----------|-------|----|---------------|
| S1 | 20261101 | tech | 600 s | 0 | 27 | 0 | 6 | 4 (0,4,2,3) | 39 | 56 | 1 | 3 | 224 | 53 | 600 | 0 | 0 |
| S2 | 57109915 | tech | 600 s | 0 | 29 | 5 | 47 | 4 (0,4,7,10) | 4 | 84 | 1 | 5 | 0 | 0 | 560 | 0 | 0 |
| S3 (pre-fix map) | 91838678 | tech | 600 s | 0 | 22 | 6 | 44 | 4 (0,5,8,2) | 3 | 83 | 1 | 4 | 88 | 68 | 574 | 0 | 0 |
| S3-fix (fixed map) | 91838678 | tech | 600 s | 0 | 25 | 5 | 51 | 4 (0,5,8,2) | 3 | 83 | 2 | 4 | 20 | 6 | 570 | 0 | 0 |
| S4 | 20261101 | red | 180 s | 0 | 7 | 0 | 2 | 4 (0,4,2,3) | 36 | 54 | 1 | 2 | 28 | 15 | 180 | 0 | 0 |
| S5 | 20261101 | mage | 180 s | 0 | 5 | 0 | 0 | 3 (0,4,2) | 27 | 56 | 1 | 3 | 70 | 50 | 180 | 0 | 0 |

Logs: `w6-soak-s1-tech-20261101-600s.log`, `w6-soak-s2-tech-57109915-600s.log`, `w6-soak-s3-tech-91838678-600s.log`, `w6-soak-s3fix-tech-91838678-600s.log`, `w6-soak-s4-red-20261101-180s.log`, `w6-soak-s5-mage-20261101-180s.log`. Partial/killed attempts preserved separately (`-PARTIAL-t334`, `-PARTIAL-t30`, `-ATTEMPT1-t520`, `-ATTEMPT2-t10-killed`, `-ATTEMPT3-t100-killed`).

Fresh seeds rolled 2026-11-13 17:25 PST: **57109915**, **91838678**. Anchor seed 20261101 READY stayed byte-identical through the whole wave: `rooms=40/40 ore_veins=138 spawn=(10,44) exit=(190,42) connected=true`.

### Attempt history (why S3-fix has four attempts)

- **S1/S2 first attempts:** killed when backgrounded exec sessions were SIGTERMed (668 s and ~90 s wall). Fix: all soaks run DETACHED via `run-soak-detached.sh` (setsid + nohup, writes `<tag>.log` + `<tag>.done`). Lesson: backgrounded exec sessions die with the agent session; detached processes survive exec-level kills.
- **S3-fix attempt 1:** killed by the runner's `timeout 1800` at t=520/600 (rc=124), 0 errors. A 600 s soak needs up to ~30+ min wall at sandbox fps; 1800 s is too tight on a slow run. Runner now takes `SOAK_TIMEOUT` (default 1800); the re-run used 3600.
- **S3-fix attempt 2:** launched while another agent's Godot (`--selftest-p11`, live tree) was already running — my check and launch were in one command, so I never saw the conflict before launching. Killed my soak ~7 min in (log t=10). Lesson: check-then-launch must be gated in the shell (`pgrep` gate in the launch command), never launch on an unchecked assumption.
- **S3-fix attempt 3:** killed at t=100 (log clean, hp 84, kills 2, mined 10, 0 errors) together with its waiter by a full session restart/compaction. Corrected rule: setsid+nohup survives exec-session SIGTERM but NOT a session restart/compaction. No `.done` was written because the runner bash died too — not a game crash.
- **S3-fix attempt 4:** completed rc=0, SOAK_DONE t=600 (the row in the table above).

## Named findings

### FINDING W6-1 — map-gen connectivity fails on seed 91838678 (BUG, FIXED)
- **Evidence:** S3 `--dump-map` on the pre-fix tree: `rooms=39/40 ore_veins=139 spawn=(6,68) exit=(188,70) connected=false`. Diagnostic (`DEEPFALL_W6_UNREACHED`) named room **[180, 76, 14, 10], center (187, 81)** unreachable even after the repair pass. The exit room ([183, 62, 10, 10], cell (188, 70)) stayed reachable, so the run was completable by mining — but the game's own connectivity guarantee failed. First non-connected map seen in the project.
- **Root cause (verified from code + `MAP_LEGS` in `w6-diag-91838678-dumpmap.log`):** the spanning-tree leg into that room is `[188, 67, 81]` (from the exit room's center) and the repair leg is `[187, 66, 81]` — both vertical shafts at x187..189 crossing the exit room's floor row 71. The exit room's brick floor (whole bottom row → tile 8, laid after corridors) severs the shaft first; the repair re-carves it, then the floor guard's SOLID re-fill severs it again. The repair is futile for this geometry — deterministic, not flaky.
- **Fix (scratch `scripts/map_gen.gd` only, repair path only, merged to live):** the repair corridor shifts its vertical leg to a slot inside the target room that avoids the severed spans — the exit room's whole floor row and the spawn anchor's 3 SOLID cells. Tries center, then left edge (`r[0]`), then right edge (`r[0]+r[2]-3`); falls back to center if all blocked (no worse than today). No RNG calls; the repair runs only when a room is unreached, so already-connected seeds are byte-identical. The `DEEPFALL_W6_UNREACHED` diagnostic print was KEPT in the merged file (fires only when a room is unreached — a tripwire, zero cost otherwise).
- **Files/lines:** `scripts/map_gen.gd`, repair block ~lines 195–224 (30 added lines incl. comment) + diagnostic ~lines 238–243. One file only.
- **Verification:** `--dump-map` after the fix, all rc=0, 0 SCRIPT ERRORs: 91838678 → **40/40, ore 139 (unchanged), connected=true**, no UNREACHED; 20261101 → READY byte-identical (40/40, ore 138, spawn (10,44), exit (190,42), connected=true); 57109915 → 40/40, ore 92, connected=true (unchanged). 5-seed sweep (34288107, 71509382, 10455829, 88204713, 29063451): all 40/40 connected=true (ore 104/118/94/139/103). Independent corroboration: another agent's A/B run on the live (unfixed) tree the same night reproduced `91838678 rooms=39/40 connected=false` (`loop/selftest-p11-ab-noskeleton-2026-11-14.log`).
- **Gameplay effect of the fix:** none beyond connectivity. S3-fix vs S3 on the same seed: same deep-floor regime (deep 83, climb 3, rooms 0,5,8,2), mined 51 vs 44, kills 5 vs 6, foes0max 6 s vs 68 s — foes now reach the bot through the repaired corridor.

### FINDING S1-NOCOMBAT — no combat for the whole S1 run (bot artifact, NOT a proven game bug)
- S1: `near0=600` — no foe within the bot's 280 px encounter radius for the entire 600 s; kills=0, mined=6. Partly bot behavior (random walk, no foe-seeking; the beta 180 s soak did get 2 kills, S2/S3 got 5–6). This run proves no-crash/no-death, not combat stability. Same pattern in S4 (near0=180) and S5 (near0=180): the 180 s runs on seed 20261101 never met a foe.

### FINDING S2-DEEP-FLOOR-CAMP — bot camps the deep floor on seed 57109915 (bot artifact + map shape, NOT a proven game defect)
- Bot reached row 84 by ~t=108 and stayed on rows 82–84 for the rest of the run; 23 of 29 stuck events on that floor band (x44–69, t=117–596); only one climb (climb=4, t=48). The W3 climb-out guarantee still stands as a probe (10 rows, deterministic) and S1 climbed 39 — but on this seed the bot never tried to climb because the deep floor is roomy and foe-rich. The run exercised deep-floor combat/mining only (kills=5, hp 100→76, foes 3–9 in window most ticks, foes0=0).

### Stuck clusters (positions/seeds)
- **Seed 20261101, fall shaft rows 46–56 x22–26:** S1 cluster A (t=16–137, 5 events), S4 t=16 (26,46) + t=36 (24,54), S5 t=16 (26,46) + t=37 (24,54) + t=98/110 (24,56)/(24,54). Same shaft, three classes — the bot falls in and takes a while to mine out. It always gets out (S1 climb 39, S4 climb 36, S5 climb 27).
- **Seed 20261101, mid rows 32–35:** S1 cluster B (t=187–236, 3 events).
- **Seed 20261101, upper band rows 19–24 x10–28:** S1 cluster C (t=261–578, 19 events, dominant in S1); S4 t=118/134 (23,22), t=164 (21,21), t=180 (15,21); S5 t=137 (22,47).
- **Seeds 57109915 / 91838678, deep-floor band rows 81–84:** S2 (23 events, x44–69), S3 (22 events, rows 81–83 x21–47), S3-fix (25 events, rows 81–82 x23–47). The bot camps the roomy deep floor and bumps along it; kills/mining continue throughout (S3-fix: 5 kills, 51 mined).
- No stuck cluster stranded the bot permanently in any run; every run ended with the bot mobile and the game healthy.

### Foes=0 stretches
- No run exceeded the 120 s named-finding threshold. Longest: S3 pre-fix `foes0max=68 s`; S1 `foes0max=53 s` (224 s total foes=0, incl. foes=0 on every 10 s tick t=510–600); S5 `foes0max=50 s`; S4 `foes0max=15 s`; S2 `foes0=0` (never zero); S3-fix `foes0max=6 s`.

## Gates

### Scratch gates (after the fix, `w6-gate-scratch.sh`, chain log `w6-gate-scratch-chain.log`, summary `w6-gate-scratch-summary.txt`)
- 5-seed `--dump-map` sweep: 34288107 (40/40, ore 104), 71509382 (40/40, ore 118), 10455829 (40/40, ore 94), 88204713 (40/40, ore 139), 29063451 (40/40, ore 103) — all `connected=true`, all rc=0.
- `--selftest` (seed 20261101): rc=0, errors=0, passfalse=0. READY byte-identical, load_ms=1390.
- `--selftest-load` (right after selftest, proper sequence): rc=0, errors=0, passfalse=0. `DEEPFALL_SELFTEST_LOAD mined=1 torches=0 slain=0 pos_ok=true hp_ok=true ore_ok=true PASS=true`.
- `--selftest-p11 --class=tech`: rc=0, errors=0, passfalse=0. Sword 50→35, pot true loot 1, dash dx=146.0, hp=100, P14 `screen_scale=1.50 touch_jump=true rose=110.7`.
- `--selftest-p11 --class=red`: rc=0, errors=0, passfalse=0. Sword 50→30, pot true loot 1, dash dx=146.0, hp=120, P14 1.50/110.7.
- `--selftest-p11 --class=mage`: rc=0, errors=0, passfalse=0. Sword 50→38 (orb), pot true loot 1, dash dx=146.0, hp=80, P14 1.50/110.7.
- Chain finished 2026-11-14T03:11:33Z, all OK.

### Live re-gate (after merging `map_gen.gd` to the live tree, `w6-gate-live.sh`, summary `w6-gate-live-summary.txt`)
- Merge: explicit `cp` of scratch `scripts/map_gen.gd` → live `scripts/map_gen.gd` only (never rsync --delete into live). Post-merge sha identical in both trees (`13b0594b…`). Post-merge diff live-vs-scratch shows ONLY the KayKit additions, live-only (see below) — `map_gen.gd` identical.
- `--dump-map --seed=91838678` on live: rc=0, **40/40, ore 139, connected=true** (load_ms=2095) — the fix works on the live tree.
- `--selftest` (seed 20261101): rc=0, errors=0, passfalse=0. READY byte-identical, load_ms=1558.
- `--selftest-load` (right after selftest, proper sequence): rc=0, errors=0, passfalse=0. `PASS=true`, `PASS7=true`, `class_ok=true` (mage).
- `--selftest-p11 --class=tech`: rc=0, errors=0, passfalse=0. Sword 50→35, pot true loot 1, dash dx=146.0, hp=100, P14 `1.50/110.7`. `ENEMY_SPAWNS total=26` (7th slug in the pool).
- `--selftest-p11 --class=red`: rc=0, errors=0, passfalse=0. Sword 50→30, pot true loot 1, dash dx=146.0, hp=120, P14 1.50/110.7.
- `--selftest-p11 --class=mage`: rc=0, errors=0, passfalse=0. Sword 50→38 (orb), pot true loot 1, dash dx=146.0, hp=80, P14 1.50/110.7.
- Chain finished 2026-11-14T06:06:42Z, all OK. The live tree as it stands (KayKit additions + W6 fix) passes the full suite.

## Live-tree state note (not W6 work — recorded so the diff reads correctly)
While W6 was running, another agent applied KayKit packs to the LIVE tree (MEMORY.md, 2026-11-13): Skeleton Warrior 7th enemy slug `skeleton-warrior` (hp 25, speed 80, dmg 8, aggro 280) + chest prop. Live-only diffs vs scratch: `scripts/enemy.gd` (6 lines), `scripts/main.gd` (15 lines: slug in ENEMY_SLUGS, chest in prop kinds), `scripts/phys_prop.gd` (4 lines: chest def). The same agent's A/B experiment transiently removed `skeleton-warrior` from live `main.gd` and restored it byte-identical (verified: sha `6cda5f18…`, count 1) before W6's merge. W6's merge touched `map_gen.gd` only; the live re-gate above validates the combined tree (KayKit + W6 fix).

## What the gates could NOT prove
- **Sandbox fps is not phone fps.** All soaks ran at fps 1–7 under the software renderer (fps_avg 2–5). Nothing here says anything about S25 frame rate, input feel, or touch responsiveness. Real-phone playtesting is still Skit's verdict.
- **The soak bot is not a player model.** It random-walks, never seeks foes, never aims, never chooses to climb. Combat/mining/climb numbers are lower bounds on what the game supports, not measurements of play. The bot's stuck events are navigation artifacts, not player-facing defects, unless a position also strands a real player.
- **`--selftest-p11` with NO `--class` stalls in this sandbox (pre-existing, not W6).** The no-class (all-classes) invocation stalls after `DEEPFALL_PHASE1_READY` — 45-min solo run killed by its timeout, two earlier runs, and the A/B arm at 300 s (EXIT 124), identical with `skeleton-warrior` removed. The per-class gates above (`--class=tech/red/mage`) DO complete with full P11/P14 lines, so each class is verified individually; only the single-command all-classes form is unverified here. The stall is a test-harness stall, not a game crash (0 SCRIPT ERRORs, game boots/loads/spawns fine). Diagnosing it is out of W6's refine-only scope; next step is either a dedicated diagnosis or settling it on the real phone.
- **Phase 6 `a3` timing flake:** did not appear in this wave; not chased.
- **Load_ms noise:** sandbox `load_ms` readings swing wildly with host load (1390–6579 ms across runs on identical seeds); they are not phone load times. Only the READY fields (rooms/ore/spawn/exit/connected) are treated as evidence.

## Left for Skit
- Orb-scale call (Effekseer mage orb 1.0 vs 2.0) — untouched, still his.
- Phone-feel verdicts: deep-cave density, climb-out comfort, startup feel, S25 fps.
- GitHub push (still at `103f450a`), APK re-upload (v1.1 link expired Nov 8), Game Off entry pick (DEEPFALL vs Shiftworlds), AI-disclosure level.
- The p11 no-class stall (above) — diagnose in-sandbox or settle on the phone.
- In-game sighting of the KayKit skeleton-warrior spawn/kill and chest break is still unverified (kaykit thread's open item, not W6's).
