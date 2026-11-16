# DEEPFALL 12-hour improvement loop

Started 2026-11-12 ~20:05 PST on Skit's word ("Continue a 12 hour improvement
loop, refining the current game buils until a higher quality"). Ends
2026-11-13 ~08:05 PST. Scope: DEEPFALL only (this chat's game). Shiftworlds
untouched.

## Standing rules (do not break these for any wave)

- REFINE ONLY. No new features, no Fungal Hollows (region 2), no new
  mechanics. Skit's 2026-11-08 directive ("no new features yet, just refine,
  master, perfect, and dial in what we have") still stands.
- NEVER merge / push / publish / submit / upload. No GitHub push (GitHub is
  still at 103f450a, P11-13). No APK upload or download link without Skit's
  word. Local work only, staged + verified.
- No removal of depth. No save-format break without a version bump + a note
  in the report (SAVE_VERSION is 9; v8 saves are ignored by design).
- Effekseer mage-orb impact scale (1.0 vs 2.0) is SKIT'S EYEBALL CALL.
  Do not change it in the loop. Leave it queued as needs-his-call.
- One wave in flight, maximum. Verify the previous builder is really done
  (REPORT.md present, state.json updated, no live Godot process on the
  scratch copy) before starting the next.
- Merge hygiene: build on a scratch COPY outside the live tree
  (`~/workspace/goals/game-off-2026-entry/loop-scratch/<slug>/`, copy of
  deepfall-game/ WITHOUT exports/). Gates run on the scratch copy first.
  Merge into the live tree by explicit file copy only (never rsync
  --delete into the live tree). After merging, re-run the gates on the
  live tree before the wave is called done.
- Godot verification rules (binding, from the beta run):
  - Solo, sequential, ONE Godot run at a time. Concurrent runs contaminate
    timing-sensitive touch tests (clean load_ms 1162-2254; contaminated
    7894-10529).
  - `xvfb-run -a -s "-screen 0 2560x1440x24"` with `--resolution 2400x1080`,
    seed 20261101 where deterministic. NO `--headless` for phone-geometry
    proof (headless reports screen scale 0.05, not 1.50); headless is fine
    for the suite after the 2026-11-08 `_share_card` guard fix.
  - Godot 4.8 beta 1 at `~/tools/godot/godot`. Editor import segfaults
    intermittently (exit 134) — re-run `--editor --quit` until exit 0.
  - Logs go to the WORKSPACE (project dir or loop/phases/<slug>/), NEVER
    /tmp — /tmp logs vanish across containers.
  - A redirected Godot log is block-buffered; a frozen-looking tail proves
    nothing. Check `ps` CPU time and the exit/timeout result.
- Gates per wave (all must pass, rc=0, 0 SCRIPT ERRORs):
  `--selftest` (Phases 6-10), `--selftest-p11` (tech AND red AND mage via
  `--class=`), `--selftest-load`. Plus the wave's own check (soak, seed
  sweep, etc.) with numbers in REPORT.md.
- Every wave ends with `loop/phases/<slug>/REPORT.md`: what changed (files
  + lines), gate numbers (test counts, load_ms, soak numbers), what the
  gates could NOT prove, and anything left for Skit. Then update queue.json
  (status done/failed) and state.json (clear active, append log).

## Queue

See `queue.json`. W1 runs immediately on spawn; W2-W7 run one per hourly
cron tick (`deepfall-improvement-loop-12h`). If the queue empties before the
deadline, the tick refills from the roadmap in BETA-REPORT.md section 4 or
stands down with a digest — it never invents a new feature to fill time.

## Stop

At/after 2026-11-13 08:05 PST the tick does no further wave work: it
disables the cron job, writes the final digest
(`loop/DIGEST-2026-11-13.md`), and reports it to Skit in the side chat.
