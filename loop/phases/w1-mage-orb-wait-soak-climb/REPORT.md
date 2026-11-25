# W1 — mage P11 orb-wait + soak bot mine-upward escape — REPORT

**Wave:** `w1-mage-orb-wait-soak-climb` · **Status: DONE** (merged to live tree, re-gated green)
**Scope:** test-only changes in `scripts/main.gd`. No game-behavior change, no new feature,
no export/version/save-format change. No push, publish, upload, or APK link.
**Worked:** 2026-11-12 ~20:05 PST → 2026-11-13 ~05:49 PST (loop deadline 08:05 PST).
Interrupted once by a runtime restart ~05:02 PST during the soak gate; resumed and finished.

## Files changed (one file, explicit copy)

- `scripts/main.gd` only (live tree, 207,704 bytes after merge; `diff -rq` live vs scratch
  scripts is empty). Everything else in the tree is byte-identical to the Phase 14b baseline.

## 1. Mage P11 orb-wait — DONE, all three beta gaps closed

The beta (2026-11-08) mage run failed three instant-read checks because the mage's sword
fires a projectile orb, and the suite read golem hp / pot state before it could arrive.
The fix is mage-only; tech/red instant reads are unchanged.

What was added to the P11 test code in `main.gd`:

- **Sword check:** mage polls the golem's hp up to 1.0 s (0.1 s steps) instead of reading
  instantly; steps any live orb synchronously with `_update_orbs(0.05)` (Phase 8 pattern)
  and, if the hp still hasn't moved, fires a second orb directly and steps it the same way.
  Print now includes `orb_wait`.
- **Pot check:** mage polls up to 1.0 s for the pot to break (validity OR the `broken` flag,
  since `queue_free` only lands at frame end) and steps a live orb synchronously.
- **Two geometry bugs the wait alone exposed, both fixed in the test setup:**
  - the golem spawned inside solid rock at the bottom of the mine-test pit (orb died on the
    rock face) — the sword check now respawns the player at spawn first;
  - a level orb sails 4 px over a floor pot's hit rect (orb y = floor−50, pot rect top =
    floor−46) — the mage pot check aims slightly down `(-1, 0.25)`.
  - **Real-game observation for Skit (not changed):** a perfectly horizontal orb sails over
    floor-level pots. A player aiming dead level at a floor pot will miss the same way.
- **Golem knockback on the player:** the golem is in attack range the moment it spawns and
  knocks the player up ~19 px, which put the level orb ~29 px off the golem's centre — 1 px
  outside the 28 px hit radius (measured with a temporary probe). Mage-only fix: the sword
  check sets `player.hurt_timer = 5.0` for the check, then clears it after the print.
- **Knockback settle:** the synchronous orb stepping hits in the same frame, so `pushed`
  read 0.0; a 0.5 s settle after a mage hit lets the displacement register before printing.
- **Dash hold:** the xvfb dash check was flaky (0.12 s hold < one ~0.2 s frame at ~5 fps;
  one run gave dx=0.0, cooldown=0.00 — `try_dash` never ran). Hold lengthened to 0.4 s,
  test-only; the dash itself (0.16 s) is unchanged.

### Gate numbers — live re-gate (2026-11-13 05:40–05:48 PST, seed 20261101, xvfb, 2400×1080)

| Suite | rc | SCRIPT ERRORs | load_ms | Key lines |
|---|---|---|---|---|
| `--selftest` (Ph 6–10) | 0 | 0 | 1111 | Ph 7, 8, 9, 9B, 10 all `done PASS=true` |
| `--selftest-p11` tech | 0 | 0 | — | sword 50→35 pushed 15.8, pot true loot 1, dash 146.0, P14 scale 1.50 rose 110.7 |
| `--selftest-p11` red | 0 | 0 | — | sword 50→30 pushed 15.8, pot true loot 1, dash 146.0, P14 scale 1.50 rose 110.7 |
| `--selftest-p11` mage | 0 | 0 | 1883 | **sword 50→38 pushed 11.7 orb_wait=0.0, pot true loot 1, dash 146.0, slam 20→10, P14 scale 1.50 rose 110.7** |
| `--selftest-load` | 0 | 0 | 1223 | `PASS=true` (pos/hp/ore ok) |
| `--soak` 180 s | 0 | 0 | — | see §2 |

Scratch final chain (05:31–05:40 PST) gave identical rc/errors and the same soak line;
mage sword there was also 50→38 pushed 11.7. Baseline (pre-W1 live tree, headless mage):
sword 50→50 pushed 0.0, pot false, dash 30.0 — the gap is closed, not papered over.

## 2. Soak bot mine-upward escape — IMPROVED, climb-out NOT achieved

### What was added to `_run_soak`

- **Room tracking:** `visited_rooms` dict + `SOAK_ROOM` prints (first visit per room);
  `SOAK_DONE` now includes `rooms=N`.
- **Unstick rework:** when stuck (≤12 px in 4 s), the bot now (a) probes both shallow
  diagonals for the nearest wall and walks toward it, (b) aims up-forward at that wall and
  holds the aim stick while jumping for 2.5 s, (c) re-presses JUMP whenever the last hop
  was released and the climb window is still open. Old behaviour mined forward-down
  (dug the pit deeper).

### Measured result (180 s, seed 20261101, tech, xvfb)

| | Beta 2026-11-09 | W1 final (scratch + live, identical) |
|---|---|---|
| `SOAK_DONE` | t=180 deaths=0 stuck=10 kills=2 mined=11 fps_min=1 fps_avg=5 | **t=180 deaths=0 stuck=6 kills=2 mined=6 rooms=3 fps_min=1 fps_avg=5** |
| Rooms visited | 1 (camp room; fall path not tracked then) | 3 — rooms 0, 4, 5, all on the fall (t=0, 2, 5) |
| Bot end state | camped one deep room rows 79–83 | **still camped the same pit, rows 79–81, ~175 s** |

**The gate as written passes** (rooms 3 > 1, stuck 6 < 10, rc=0, 0 errors). **The intent
does not fully:** the bot does not climb out. Honest accounting:

- The steep up-forward ray (53°) finds only air from the pit floor — proven by probe:
  `probe=(-1,-1)` at both unstick triggers. The room is ~7 rows tall; its ceiling is
  beyond the 217 px `REACH`. The pick cannot mine the ceiling from the floor.
- The shallow diagonal (24°) at the probed nearest wall DOES bite: the wall probe finds
  rock 1–2 cells away (e.g. `probeR=(34,80)`), and mined went 0 → 6. But it digs a
  1-tall horizontal slot the 1.25-tall bot cannot enter, and stalls at the 3.4-cell reach
  limit (mined plateaued at 6 across the last three unstick windows).
- A steep-diagonal variant (same wall probe, 53° aim) was tried and reverted: mined 3 vs 5
  in a 90 s probe, climbs no better — the holes it opens are diagonal and out of step-range.
- `mined` fell 11 → 6 vs the beta because the old forward-down unstick dug the floor
  (useless digging, but it counted). The new mining is at the wall, where a climb would
  have to happen — it just doesn't rise yet.
- **Climb-out is W3's job** ("Guarantee a climb-out path from deep rooms" — stepped
  one-way platforms/ledges in map gen). A test-bot tweak alone cannot fix a room with no
  climbable geometry; the evidence for that is in this report and the probe logs.

### Incidents along the way (recorded so the next wave doesn't repeat them)

- **Soak gates 1–3 never started the soak:** the commands passed `--soak-secs=180` but
  omitted the `--soak` flag itself (`"--soak" in args` is the exact-string check in
  `_ready`), so the game sat idle at the spawn screen burning CPU until timeout/restart.
  Soak1 rc=124 was that, not a hang. Correct invocation:
  `godot --path . --resolution 2400x1080 -- --seed=20261101 --soak --soak-secs=180`.
  Same class of error as the missing `--` separator found earlier in this wave.
- **Runtime restart ~05:02 PST** killed soak2 mid-run; all other scratch gates were already
  green and were not redone blindly — verified from disk on resume.
- **Godot logs are block-buffered:** a short log tail proves nothing on its own; the
  engine's own `user://logs/godot.log` was the tell that soak3 had never entered `_run_soak`
  (save file untouched since 04:48 + READY as last line).

## What the gates could not prove

- Mechanics only, not feel: orb damage is now measured (12), but mage *feel* on a real
  phone, climb-out comfort for a human (who digs stairs — the bot can't yet), deep-cave
  enemy density, and startup-lag feel are all still phone verdicts for Skit.
- Sandbox fps (1–9, avg 5, llvmpipe) is not phone fps.
- The soak bot is dumb by design: it walks straight lines, never plans a route, and its
  stuck/unstick behaviour is a harness artefact, not a player model.

## Left for Skit / next waves

- **For Skit:** horizontal orb vs floor pots (see §1); Effekseer orb impact scale 1.0 vs 2.0
  still his eyeball call; v1.1 APK link expired 2026-11-08 ~23:44 PST (re-upload only on his
  word, with him present); GitHub still at `103f450a` (Phase 14 + this wave local only,
  push needs his word); Game Off entry pick + AI-disclosure level still open (deadline
  Dec 1, 2026, 13:37 PST).
- **For W3 (climb-out comfort):** the evidence here — ceiling beyond REACH from the pit
  floor, wall slots stalling at the reach limit, bot camping rows 79–81 — is the starting
  point. A bot-side fix was exhausted in this wave; the room needs climbable geometry.
- **For W2 (deep-cave encounters):** this wave's soaks confirm the beta finding — foes=0
  for ~150 s after the early fight (2 kills before t=30, then nothing). Deep-cave density
  is still unmeasured beyond that.

## Logs (all under `loop/phases/w1-mage-orb-wait-soak-climb/`)

- Final scratch chain: `w1-gate-final-summary.txt`, `w1-final-selftest.log`,
  `w1-final-p11-tech.log`, `w1-final-p11-red.log`, `w1-final-p11-mage.log`,
  `w1-final-selftest-load.log`, `w1-final-soak.log`
- Live re-gate: `w1-gate-live-summary.txt`, `w1-live-*.log` (same six files)
- Earlier work: `w1-gate-summary.txt` (first chain, 04:59), `w1-gate-soak.log` (soak1,
  rc=124, idle — missing `--soak` flag), `w1-gate-soak2.log` (killed by restart),
  `w1-gate-soak3.log` (idle, same flag miss), `w1-gate-soak4.log` (first real soak,
  steep aim, mined=0), `w1-soak-probe.log` (probe=(-1,-1) proof),
  `w1-soak-probe2.log` (shallow+wall probe, mined=5 in 90 s),
  `w1-soak-probe3.log` (steep+wall probe, mined=3 in 90 s, reverted),
  `w1-gate-soak5.log` (shallow+wall probe, 180 s, mined=6 stuck=6 rooms=3),
  `w1-p11-*.log`, `w1-selftest*.log` (development runs), `w1-import-1.log`
- Temporary probe prints (`DEEPFALL_P11_MAGEPROBE`, `DEEPFALL_P11_DASHPROBE`,
  `SOAK_UNSTICK`) were all removed before the merge; `grep PROBE/UNSTICK` on the merged
  `main.gd` finds none.
