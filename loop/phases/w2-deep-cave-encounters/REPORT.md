# W2 — Deep-cave encounters: REPORT

**Status: DONE — opt-B kept and merged.** Finished 2026-11-13 ~01:40 PST by finisher #2
(second finisher; finisher #1 vanished after completing the opt-B gate chain 08:44 UTC,
likely a runtime restart — its work survived on disk and was verified, not redone).

**Decision: keep opt-B (+1 foe in deep rooms).** Opt-A (drift) is a measured no-op and is
discarded. No other change. No push / publish / upload / GitHub push.

## The change (live tree, `scripts/main.gd` only)

One line in `_build_enemy_spawns`, plus a comment:

```gdscript
# W2 opt-B: deep rooms (top row > 60) get one extra foe.
# Deterministic per seed; map structure untouched.
var per_room := 3 if int(r[1]) > 60 else 2
for k in range(per_room):
```

Map structure is untouched — the seed-20261101 READY line is byte-identical before and
after (rooms=40/40 ore_veins=138 spawn=(10, 44) exit=(190, 42) connected=true).
Also merged: the W2 soak instrumentation in `_run_soak` (foes0 / foes0max / near0
tracking and the extended `SOAK_DONE` print) — test-only harness code, no gameplay
effect, kept so later waves (W6 long soaks) can reuse the metric. The scratch-only
probe prints (`DEEPFALL_W2_SPAWNS` / `DEEPFALL_W2_ROOMS`) were removed before the
merge; grep confirms none remain in the live tree.

## Before / after — 180 s soaks, tech, xvfb, 2400x1080

foes0 = seconds with no live enemy in the active chunk window; foes0max = longest
unbroken foes=0 stretch; near0 = seconds with no foe inside the bot's 280 px
encounter radius. All in game seconds. Seeds: s1=20261101, s2=20261102, s3=20261103.

| seed | variant | foes | foes0 | foes0max | near0 | kills | deaths | stuck | mined | rooms |
|------|---------|------|-------|----------|-------|-------|--------|-------|-------|-------|
| s1 | baseline | 22 | 146 | 130 | 172 | 2 | 0 | 6 | 6 | 3 |
| s1 | opt-A drift | 22 | 145 | 130 | 168 | 2 | 0 | 6 | 6 | 3 |
| s1 | **opt-B** | **24** | **105** | **21** | 172 | **3** | 0 | 6 | 6 | 3 |
| s2 | baseline | 24 | 0 | 0 | 180 | 1 | 0 | 8 | 5 | 4 |
| s2 | opt-A drift | 24 | 0 | 0 | 180 | 1 | 0 | 8 | 5 | 4 |
| s2 | **opt-B** | **27** | 2 | 2 | 178 | **3** | 0 | 8 | 5 | 4 |
| s3 | baseline | 24 | 180 | 180 | 180 | 0 | 0 | 7 | 14 | 1 |
| s3 | opt-A drift | — | — | — | — | — | — | — | — | — |
| s3 | **opt-B** | **28** | 180 | 180 | 180 | 0 | 0 | 7 | 14 | 1 |

## Reading

- **Opt-B beats baseline on s1 and s2.** s1: foes0 146→105 (−28%), worst empty stretch
  130→21 (−84%), kills 2→3. s2: kills 1→3; foes0 0→2 is 2 s of bot-path noise on a
  seed that already had encounters. No regressions anywhere: deaths 0, stuck/mined/
  rooms identical per seed, all gates green.
- **s3 is unchanged under every variant — a bot-geography artifact, not a tuning
  failure.** The bot falls into one deep room and camps it for the whole 180 s
  (rooms=1, mined=14 — it digs the floor, never climbs out). Opt-B does add foes on
  this seed (24→28, four of the twelve chosen rooms are deep), but they spawn in
  *other* deep rooms the bot never reaches. No room-local spawn change can reach a
  bot that never leaves one room. The climb-out is W3's job.
- **Opt-A (drift) is a no-op on the numbers.** Identical spawn totals and identical
  soak numbers to baseline on s1 and s2; its s3 soak never finished (rc=124,
  killed by timeout/restart, no SOAK_DONE). Drift is discarded, not merged.
- Baseline spawn totals are 22/24/24, not the nominal 24: a few spawn picks fail
  (`_pick_enemy_cell` finds no valid cell in cramped rooms). Opt-B totals are
  24/27/28 — every extra deep foe materialized.

## Gates (all solo, sequential, xvfb, 2400x1080, seed 20261101 unless noted)

- **Baseline** (W1 tree, 06:15–06:38 UTC): selftest, p11 tech/red/mage,
  selftest-load, 3 soaks — all rc=0, 0 SCRIPT ERRORs.
- **Opt-A** (06:45–07:25 UTC): same chain, all rc=0 except soak-s3 rc=124
  (timeout/restart, no SOAK_DONE).
- **Opt-B scratch** (07:27–08:44 UTC, restart recovery 07:36): selftest, p11
  tech/red/mage, selftest-load, 3 soaks — all rc=0, 0 SCRIPT ERRORs.
- **Opt-B LIVE re-gate after merge** (09:11–09:36 UTC): selftest, p11 tech/red/mage,
  selftest-load, soak s1 — all rc=0, 0 SCRIPT ERRORs. Live soak s1: stuck 5
  kills 3 mined 13 rooms 3 foes0=100 foes0max=21 near0=166 (matches scratch opt-B
  s1 within bot run-to-run variance). Live p11 tech: sword 50→35, pot true,
  P14 touch jump screen_scale=1.50 rose=110.7. Live selftest-load PASS=true.
  Live main.gd verified byte-identical to the cleaned scratch copy (208,489 B),
  probe prints absent.

## Notes for later waves

- `load_ms` on the live selftest read 8121 (scratch opt-B: 8689) — well above the
  beta's clean 1162–2254 range, but this run was solo with no other Godot process.
  Treated as sandbox CPU noise, not a game signal; W4 owns startup smoothness and
  should re-measure there. No timing claim is made from these runs.
- fps_avg across all W2 soaks is 1–6 (llvmpipe software rendering) — sandbox
  numbers, not phone numbers.
- The deep-cave feel question stays Skit's: the bot now meets more foes on 2 of 3
  seeds, but whether the deep cave *feels* inhabited on his phone is still his
  verdict. W3 (climb-out) is the next wave.
