# Per-zed performance investigation

Status: **in progress (2026-10-14).** Probe built, detail mode run once at Risk 0. The
non-sprinter path is now broken down (see "detail-300 breakdown"), and there are plain
totals at Risk 0 and Risk 100, and a Risk 100 detail run. Optimisations made the same day
(see "Changes made"); next is re-measuring them in game with the same runs.

## Why

The goal is a per-zed sprinter speed *range* (min/max), adjustable per PhunZones zone.
Before building it, the concern was how much work the mod already does per tick.

The range itself adds no per-tick cost: speed is decided once per zed, when it first
sprints (`applySpeedScale` in `client_main.lua` returns immediately after that). So
the range is not blocked by this investigation. The question is the existing
`OnZombieUpdate` -> `Core.enqueueUpdate` path, which runs for every zed in range on
every tick.

## The probe

`media/lua/client/PhunSprinters/client_probe.lua`. Inert until started from the debug
Lua console:

```lua
PhunSprinters.probe.spawn(300)                 -- ring of zeds 15-30 tiles out
PhunSprinters.probe.start(60, "label")         -- measure, then print a report
PhunSprinters.probe.start(60, "off", true)     -- same, with the mod's per-zed work disabled
PhunSprinters.probe.start(60, "detail", false, true)  -- same, plus a per-sub-step breakdown
PhunSprinters.probe.stop()
```

It swaps `Core.enqueueUpdate`, `Core.processQueue` and `Core.testEnvironment` for timed
wrappers and restores them afterwards. Callers look these up by name on each call, so
the real code is untouched.

PZ Lua has only a millisecond clock (`getTimestampMs`; `os.time` is the same). Calls are
timed individually and summed: a call of d ms crosses a clock tick with probability d,
so the sum converges on the true total over many calls. The probe measures the clock
step first (1 ms on this machine) and subtracts the cost of a clock read (~0.1 us).

### Detail mode

Also wraps the sub-steps, which are called as `Core.<name>` too: `getId`, `getZedData`,
`isIgnoredMutant`, `mutantType`, `speedTypeOf`, `adoptIfSprinting`, `applySprintState`,
`applyZedVisualState`, `updateZed`, `shouldSprint`, `adjustForLight`, `effectiveLight`,
`makeSprint`, `makeNormal`, `reassertSpeed`, `scream`. The report then gets one table per
top-level caller (under enqueueUpdate, under processQueue, called from elsewhere), sorted by
**self** time, with inclusive time beside it. The self time of `enqueueUpdate` is the code
that isn't wrapped: the queued and verdict checks, square and distance lookups, the
insert. The self time of `processQueue` is the dequeue loop plus the once-per-tick player
lookup. (Before the 2026-10-14 changes these were `getPlayer` plus squares, and
`table.remove(queue, 1)`.)

The wrapper's own cost is calibrated at start (printed as "detail wrapper costs N us/call")
and subtracted. Even so, nesting distorts things a little, so use plain runs for totals and
detail runs for proportions. Checked under LuaJIT with stubbed globals and functions of known
cost: the self/inclusive attribution adds up and every function is restored afterwards. In
game the wrapper costs ~1.6 us per call, and totals come out about 1.25x the plain figure.

## Results so far

| Run | Zeds | Sprinters | enqueueUpdate | processQueue | Mod total |
|---|---|---|---|---|---|
| Risk 100, Mode 4, night, god mode | 300 | 299 (255 running) | 1.09 ms/tick, 3.6 us/call | 0.36 ms/tick (~18 us per zed) | **1.45 ms/tick, 14% of a 10.2 ms frame** |
| "Risk 0" (flawed, see below) | 0 -> 300 | 53 | 1.05 ms/tick, 5.8 us/call | 0.13 ms/tick | 1.18 ms/tick, 12% |
| Empty world | 0 | 0 | - | - | 0.004 ms/tick |
| 2026-10-14 off-300 (mod disabled), Risk 0, uncapped | 300 (300 -> 252 in range) | 0 | 0.059 ms/tick, 0.20 us/call | 0 | **0.06 ms/tick**: the event dispatch itself is nearly free |
| 2026-10-14 detail-300, Risk 0 | 300 (252 -> 231 in range) | 0 | 2.22 ms/tick, 7.4 us/call (inflated, see below) | 0.003 (queue empty) | proportions only |

| 2026-10-14 on-300, Risk 0 | 300 (300 -> 283 in range) | 0 | 1.78 ms/tick, 5.9 us/call | 0.002 (queue empty) | **1.78 ms/tick**, 13.3% of a 13.4 ms frame |
| 2026-10-14 on-300, Risk 100 | 300 (300 -> 293 in range) | 300 (2-3 running) | 0.70 ms/tick, 2.3 us/call | 0.40 ms/tick (~20 us per zed) | **1.10 ms/tick**, 9.2% of a 12.0 ms frame |

- **Risk 0 costs more than Risk 100.** A queued sprinter returns early at the `queueIds`
  check, but a zed already tested "no" never queues and runs the whole check path on
  every tick, forever. Most zeds are "no" in normal play, so this is the case to fix.
- **At 300 sprinters the queue already throttles them.** With MaxQueue 20, each queued
  zed gets an `updateZed` (and its light check) about every 15 ticks. Only zeds inside
  MinDistance2 are handled every tick. So checking "no" zeds every N ticks, with N around
  10, is no slower than what sprinters already get.
- **Frame time still doesn't show the cost:** 13.4 ms on vs 13.8 ms off. The run was
  uncapped, so the frame is presumably limited by something else (likely rendering).
  The 1.1-1.8 ms is real main-thread CPU time that this machine absorbs at 300 zeds.
- The detail run's 2.2 ms against this plain 1.78 ms puts the wrapper inflation at
  about 1.25x, not 2x.

### detail-r100 breakdown (Risk 100, 300 sprinters, ~280 queued)

- **`processQueue`: 56% is its own loop** (0.28 of 0.5 ms/tick, ~14 us per dequeue), i.e.
  `table.remove(queue, 1)` shifting ~280 entries. `updateZed` for 20 zeds is only 0.2 ms.
- **The light check is cheap:** `adjustForLight` + `effectiveLight` run ~2-3 us per zed.
  It was never the problem.
- **`enqueueUpdate` for a queued sprinter** is `getId` (0.9 us) plus `isDead`,
  `getPlayer` and the `queueIds` lookup (1.5 us), 300 times per tick.
- `getId` runs 2x per dequeued zed (`processQueue` and `getZedData`).

## Changes made 2026-10-14 (not yet measured in game)

In `client_queue.lua`, plus `Core.getNumId` in `core.lua`:

1. **"No" zeds are rechecked every 10 ticks** (`NOT_SPRINTER_RECHECK_TICKS`), staggered by
   id, and checked before the distance lookup. Sprinters and untested zeds are unchanged,
   so the light check is too.
2. **Head/tail index queue** instead of `table.remove(queue, 1)`. `Core.queue` and
   `Core.queueIds` are gone; the state is local to `client_queue.lua`.
3. **The "already queued?" test comes first**, keyed on `Core.getNumId` (a plain
   `getID`/`getOnlineID`, with no `instanceof` and no `tostring`). The dequeue reuses the
   stored key, so `getId` now runs only inside `getZedData`.
4. **The player's square is looked up once per tick** in `processQueue`, not per zed.
   Until the first tick, or if there is no player square, `enqueueUpdate` does nothing.

Checked under LuaJIT with stub zeds: FIFO order, MaxQueue per tick, close and far zeds,
"no" zeds looked at once per 10 ticks, the queue draining and resetting. Given the same
inputs, the old and new queue update exactly the same zeds the same number of times.

### Results after the changes (2026-10-14, v2 runs)

Grouped by the settings each report printed. Some run labels didn't match those settings.

| Run | Sprinters / 300 | enqueueUpdate | processQueue | Mod total | Before |
|---|---|---|---|---|---|
| Risk 100 | 300 | 0.79 ms, 2.6 us/call | **0.14 ms** | **0.93 ms** | 1.10 (0.70 + 0.40) |
| Risk 100 | 152 | 0.66 ms, 2.2 us/call | 0.14 ms | 0.81 ms | - |
| Risk 0 | 181 (stale verdicts) | 0.69-0.75 ms, 2.3-2.5 us/call | 0.16 ms | 0.85-0.91 ms | 1.78 (all "no") |

- **The new queue works:** `processQueue` fell 0.40 -> 0.14 ms (-64%).
- **`enqueueUpdate` didn't drop for queued sprinters:** 0.70 before, 0.66-0.79 after. So
  `getId`'s `tostring` wasn't the expensive part. The floor is now ~2.3-2.6 us per zed per
  tick: the event dispatch (~0.2 us), `isDead`, `getNumId` and a table lookup. **Java calls
  from Kahlua are the unit of cost.**
- **The clean Risk 0 case was not re-measured.** Both Risk 0 runs had 181 sprinters, so the
  zeds were tested while the player's cached risk was still non-zero. (Same cause as the
  earlier "53 sprinters" run: cached risk only recalculates once per game minute.) Mixed
  runs come in at ~2.4 us per zed against 5.9 us for all-"no" before, which suggests the
  recheck-every-10-ticks change works, but that is an inference.
- Frame time is still unaffected either way, as before.
- **r0-v3 (Risk 0, fresh spawn): 0.84 ms/tick** (0.685 enqueue + 0.155 queue,
  2.28 us/call), against 1.78 before, about -53%. Slow in light felt unchanged in play.
  But this run **also had 51 sprinters (48 running) at DefaultRisk 0**, about the same 17%
  as the first flawed run's 53. With DefaultRisk 0, risk is 0 unless a PhunZones zone sets
  `minSprinterRisk` (`client_risk.lua`), and `shouldSprint` never says yes at 0. So these
  probably came from somewhere else: a stale cached risk, a zone, or vanilla-rolled
  sprinters taken over by `adoptIfSprinting` (e.g. if debug-spawned zeds skip the
  neutered sandbox). **Unresolved. This is a behaviour question, separate from perf.**

Levers left, none built:
- In `enqueueUpdate`, test `queued` before `isDead`, which saves a Java call for every
  queued zed.
- Key `queued` on the zed object rather than its ID, so a queued zed costs no Java calls.
  This depends on how Kahlua hashes Java objects, which needs verifying in game.
- Structural: drop per-zed `OnZombieUpdate` and sweep `getCell():getZombieList()` in
  slices from `OnTick`, so the cost scales with the slice size rather than the horde. Zeds
  inside MinDistance2 would then get updates every few ticks instead of every tick.

Already true before this change, not new: zeds rejoin the queue in `OnZombieUpdate` order,
not the order they left, so updates are uneven (6 to 10 per zed over 20 ticks in the
test).

### detail-300 breakdown (Risk 0, every zed tested "no", nothing queued)

In game the detail wrapper costs **1.57 us/call** (0.09 us under LuaJIT). The probe
subtracts it, but the total still came out at 2.2 ms against 1.78 ms in a plain run, so
treat these as shares of `enqueueUpdate`, not as absolute times:

| Self time in | Share | Calls/tick | What it is |
|---|---|---|---|
| `enqueueUpdate` itself | 37% | 300 | `getPlayer`, two `getSquare`, `DistToProper`, settings lookups, `queueIds` |
| `getId` | 24% | 539 (1.8 per zed) | `instanceof` + `isZombie` + `tostring`, ~1 us each |
| `getZedData` itself | 17% | 239 | `isDead`, `getModData`, id/startTime compare |
| `adoptIfSprinting` + `speedTypeOf` | 14% | 239 | the "promoted by another controller?" check |
| `isIgnoredMutant` + `mutantType` | 8% | 239 | The Mutants API lookup |

What it shows:

- **The tax is paid by zeds whose verdict is already "no".** At Risk 0 none of them queue,
  yet each in-range zed still does the distance check, `getZedData`, the mutant check and
  the adopt check on every tick, indefinitely. The idea that queued zeds return early
  (the earlier `getId` theory) doesn't apply here: the queue was empty. Even so, `getId`
  is the largest single function.
- **Kahlua function calls cost on the order of 1 us.** Removing calls matters more than
  making any one of them cheaper.
- The "53 sprinters at risk 0" anomaly did not recur: with a clean setup this run had 0
  sprinters. That points to the earlier run's setup (cached risk or the spawn ramp), not
  to the code.
- **The cost is the per-zed tax every zed pays, not the sprinter light path.** Mostly
  non-sprinters still cost ~5.8 us per call. (Earlier guess was the Mode 4 light check;
  the data does not support that.) Likely candidates: two `getId` calls (each a
  `tostring`), two `getSquare` plus `DistToProper`, `getModData`, the The Mutants API
  call in `isIgnoredMutant`, and `adoptIfSprinting`.
- `processQueue` likely pays for `table.remove(queue, 1)`, which shifts a queue of ~280
  entries 20 times per tick.
- **Frame time cannot confirm the totals on this machine.** p50 is 10 ms in every run,
  with or without zeds: the game looks capped at ~100 FPS, and extra work is absorbed into
  idle time. The ms/tick figure is still real CPU time (~12-14% of the 10 ms budget). It
  would show as lost frames on a slower machine or a bigger horde.

## Problems with the runs so far

1. The "risk 0" run started the probe **before** spawning, so it timed the spawn ramp.
2. It had **53 sprinters at Default Risk 0**, which should be impossible
   (`shouldSprint` returns false for risk <= 0). Suspects: cached player risk still at 100
   (risk recalculates once per *game* minute), the zeds being adopted as vanilla
   sprinters, or a PhunZones zone setting `minSprinterRisk`. Check
   `print(getPlayer():getModData().PhunSprinters.risk)` before spawning.
3. No "off" baseline has been taken yet.

## Next steps

1. **Clean reruns.** Set options, check the cached risk, `spawn(300)`, wait ~30 s, then
   start. Do pairs: `start(60, "off-300", true)` and `start(60, "on-300")`. Uncap the
   frame rate and turn off vsync so the frame-time difference can confirm the mod total.
2. ~~Add a "detail" mode to the probe.~~ Done 2026-10-14 (see above). After the clean
   pair, in the same scene, run `start(60, "detail-300", false, true)`.
3. Optimise whatever that shows. Options already identified, none built:
   - Per-zed data in a weak-keyed Lua table instead of `getModData` and string IDs.
   - A cheaper queue than `table.remove(t, 1)`.
   - Throttling per zed, but **not** the light check: Slow in light has to stay
     responsive.
4. Then build the speed range: `SprinterSpeedMin`/`Max` sandbox options plus
   `minSprinterSpeed`/`maxSprinterSpeed` PhunZones fields. Derive each zed's value from a
   hash of its online ID, so every client agrees without syncing, and take bounds from
   the **zed's** zone (`PhunZones.getPhysicalZone(zed)` works on any object), decided once
   when it first sprints.
