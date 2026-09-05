# B42 Direct-Speed Refactor — design notes

Status: **step 1 implemented (2026-09-05). Steps 2-5 still outstanding.**

Background: the mod currently changes a zombie's speed by mutating the global
`ZombieLore.Speed` sandbox option inside a `makeInactive(true/false)` bracket
(`client_main.lua` `makeNormal` / `makeSprint`). B42 exposes per-zombie speed
control, which removes the need for that entirely.

API facts live in `D:\pz-dev\PHUNSTUFF.md` under **Zombie Speed (B42)** — they apply
to the whole Phun family, not just this mod. This doc is the design specific to
PhunSprinters.

---

## Why bother

Replacing the sandbox toggle with `doSprinter()` / `doFastShambler()` / `doShambler()`:

- Stops mutating global state that every other zombie in the world reads
- Removes a full `DoZombieStats()` stat re-roll (health, cognition, memory, sight,
  hearing) on every speed transition
- Makes transitions deterministic — the current path has a 2-in-3 chance of landing
  in `doFakeShambler`, so zeds in the same light respond inconsistently
- Deletes `getDefaultSpeed()`, `_defaultSpeed` and `zData.originalSpeed`

The light/Mode-4 path benefits most: it is the highest-frequency transition (per zed,
per light change) and the one where the nondeterminism is most visible to players.

**None of this touches the gameplay model.** `client_env.lua:testEnvironment` (mode,
dusk/dawn, global light) and `client_risk.lua:CalcPlayersSprinterPercentage` (moon,
hours, zone) are pure math over settings and climate. They decide *whether* a zed
should sprint; the refactor only changes *how that gets applied*.

---

## Core model: disable vanilla sprinters at startup, then manage

> **Revised twice on 2026-09-05.** v1 tracked each sprinter's *origin* (vanilla roll vs
> mod promotion) and branched on it. v2 replaced that with per-zed demotion on first
> sight. v3, below, does it once at startup instead. Both earlier versions are in git
> history. Each revision was a net deletion.

Two independent facts per zed:

- **Identity** — is this zed a sprinter? Sticky. Set by our risk test, and only by it.
- **Expression** — is it running *right now*? Recomputed constantly from mode, hours,
  light.

**Vanilla's ability to roll a sprinter is removed once, at startup.** After that there
is only ever one kind of sprinter — ours — and origin stops being a fact anyone needs
to carry.

```
at startup (client, once):
    Speed == 2 or 3 -> nothing to do; leave the admin's setting alone
    Speed == 4      -> SprinterPercentage = 0
                       (vanilla still rolls Rand.Next(2)+2, so the admin's exact
                        fast-shambler/shambler mix survives; only sprinters go)
    Speed == 1      -> VanillaSprinters decides: 2, 3, or 4 + SprinterPercentage 0

when we first make a zed sprint:
    baseSpeedType = zed.speedType     -- safe by construction: cannot be 1 unless ours

every update:
    risk test decides identity (every zed, no bypass)
    if identity == sprinter and it should run now:   -- mode / dusk-dawn / light / hours
        doSprinter()
    else:
        apply baseSpeedType
```

The `Speed == 4` line is the reason this beats per-zed demotion: demotion flattened a
Random server's whole distribution to one value, where zeroing the sprinter share
leaves it exactly as the admin configured it.

`baseSpeedType` replaces `zData.originalSpeed`, which stored the *global* sandbox enum
standing in for a per-zed fact.

### Why this is not the old hack

The pattern this refactor exists to kill was `sandboxOptions:set` + `makeInactive`
**per speed transition, dozens of times a second, per zed**. This is one call at
initialisation. The jar facts that make it safe — no disk write, no packet, nothing
overwrites it, and consumers read the live singleton — are recorded under **Mutating a
sandbox option at runtime** in PHUNSTUFF.md.

### What is left of the per-zed machinery

Almost nothing. There is no capture guard, no "is this read clean" question, no
fallback-and-retry, and no origin. `makeSprint` records `zed.speedType` in the moment
before it overwrites it, and `makeNormal` puts it back.

### One "normal", not two

Because a base is never sprinter, **un-promote and suppress have the same answer** —
apply `baseSpeedType` — so they are one function, `makeNormal`. The original design's
split existed only to stop un-promotion from deleting an admin's vanilla sprinter;
with demotion there is no vanilla sprinter left to delete.

### What this costs

This mod becomes the **sole authority on who sprints**. `ZombieLore.Speed` and
`ZombieLore.SprinterPercentage` stop producing sprinters from the moment the mod
initialises, and any other mod reading them sees the adjusted value. That is
deliberate, and it is the reason the model is simple.

It is not a loss of capability: a `Speed = 1` server that wants its old behaviour sets
`DefaultRisk = 100` and `Mode = Always`, which promotes every zed and gates nothing.
Every intermediate setting is reachable the same way. So no "respect vanilla sprinters"
escape hatch is provided — it would reintroduce exactly the two-class problem the model
exists to remove.

The upside beyond simplicity: behaviour is now identical across `Speed = 1/2/3/4`
servers, which removes a whole class of "why do zeds act differently on my server"
support question.

### MP

Resolved: the server **does** roll and broadcast speed for zeds no client owns —
`DoZombieStats()` is called by the server-authoritative `ZombiePopulationManager` and
`VirtualZombieManager`, and `ZombiePacket.speedMod`/`walkType` are written by
`NetworkZombieSimulator` and `FakeClientManager$ZombieSimulator`. So
`neuterVanillaSprinters` lives in `core.lua` and runs from `Core:ini()` on **both**
sides. A client-only call would have left server-simulated sprinters uncorrected.

Also resolved, and it corrected an earlier wrong claim in this doc: the live sandbox
**is** overwritten at runtime in MP. `receiveSandboxOptions` is a packet handler on
client and server, so an admin editing settings in-game re-pushes them and wipes the
change. Hence the re-run on `EveryOneMinute` in both `client_events.lua` and
`server_events.lua`; the function is written to no-op when nothing needs doing.

**Open risk, not verified:** `GameServer.receiveSandboxOptions` ends with
`saveServerLuaFile()`, and `GameClient.sendSandboxOptionsToServer` takes the options
object as a parameter. If the admin sandbox UI passes the live singleton rather than a
fresh copy, an admin pressing save on a modded server would persist our override into
the server config permanently. Worth confirming before shipping. It is one reason the
override is kept as narrow as it is — nothing is touched at all on a `Speed = 2`/`3`
server, and only `SprinterPercentage` on `Speed = 4`.

Speed itself replicates natively (`ZombiePacket`), so the owning client's verdict is
what every peer sees, and `baseSpeedType` stays client-local and untransmitted.

---

## Debug overlay was conflating three states (fixed 2026-09-05)

Worth recording, because it produced a convincing false positive during testing:
walking ~15 tiles appeared to re-roll nearby zeds between sprinter and non-sprinter.

The overlay's colour was driven by local zed modData, with green as the *default*, so
green meant all three of:

1. `sprinterIds[id] == nil` — never tested
2. `sprinterIds[id] == false` — tested, failed the roll
3. `sprinterIds[id] == true` but no usable local `data` — verdict exists, local state
   missing (modData wiped by `resetForReuse`, or not re-established yet)

So a zed being tested for the very first time as the player walked into range — the
mod working exactly as designed, since `updateZed` only tests inside the
`MinDistance2`..`MaxDistance2` band — was indistinguishable from a verdict flipping.

Colour is now driven by `sprinterIds`, the authoritative verdict: grey `untested`,
green `no`, yellow `walk`, red `run`, and **magenta `SPRINTER/nodata`** for state 3.
That magenta case is the one to watch when testing identity across chunk loads — it is
precisely "this zed's verdict survived but its local state did not".

---

## MP sync has been dead since 42.17 (confirmed 2026-09-05, two clients)

`Core.getId` uses `IsoMovingObject.getID()` on B42.17+. That is a **per-client** value:
a `protected final int` assigned from a static `IDCount` counter at construction, so
each process numbers its own objects independently. Two clients hold different
`IsoZombie` objects for the same logical zombie with different `getID()` values.

`sprinterIds` is keyed on it and is the mod's only cross-client channel. So client A
publishes a verdict under its local handle and client B looks that number up against an
unrelated zombie.

Confirmed by putting two clients on the same horde with both ids on the overlay:
`getID()` differed (141/144/145 vs 3812/3806/3809) while `onlineId` matched exactly
(4186, 4189, 4190, …). One client showed those zeds as `untested` while the other showed
`no` — the desync caught live.

The network identity is `onlineId` (`ZombiePacket.id`, used by `NetworkZombiePacker`,
`ZombieID`, `MovingObject`, `GameClient`). `getOnlineID()` **does still exist** on this
build, contrary to the `core.lua` comment "I suppose getOnlineID is no longer a thing in
B42.17".

Two ways out, and they point in opposite directions:

- **Fix the key** — use `getOnlineID()` in MP. Roughly a one-liner, restores real
  cross-client verdicts. Keeps the growth bug, the `0` sentinel and the chunk-reload
  re-roll. Note `onlineId` is also reset by `resetForReuse`, so it fixes matching, not
  lifetime.
- **Delete the channel** — go ephemeral. `sprinterIds` is the *only* use of
  `Core.getId` that crosses the wire; `queueIds`, `zData.id` and the overlay are all
  local, where a per-client handle is exactly right. So deleting it makes this bug
  disappear rather than needing the fix.

---

## Identity is already ephemeral (settled 2026-09-05 by observation)

The question was whether sprinter identity *should* persist across a player leaving an
area. The answer turned out to be that it already does not, and never has.

**The observation.** Zed `3156` sits in one spot, green. Leave, return: it is in a
different group further south, and red. Leave, return again: back in the original spot,
green. Same id, different zombie, different verdict, repeatably.

**Why.** `Core.getId` uses `getID()` on B42.17+ (`getOnlineID()` below that, which
`resetForReuse` resets outright). `IsoMovingObject.id` is `protected final int`,
assigned from a static `IDCount` counter at construction, and referenced only by
`CollisionManager`, `CombatManager`, `MovingObjectUpdateSchedulerUpdateBucket` and the
debug panels. Nothing saves or restores it. It is a **runtime object handle**, reused as
objects are created and destroyed — not a zombie identity. There is no stable
per-logical-zombie id in PZ at all.

**And the mod actively re-rolls.** `getZedData` treats a modData/id mismatch as a reset
and calls `Core.addToSend(id, nil)`, which sets `sprinterIds[id] = nil`. Since
`resetForReuse` wipes modData, every chunk round-trip clears the verdict and re-tests.
That is the green/red/green alternation, and it is our code doing it, not the engine.

**Conclusion: making verdicts per-encounter is not a behaviour change.** It is making
the actual behaviour explicit and deleting the machinery that pretends otherwise — the
`sprinterIds` batching, the server broadcast, the unbounded growth, the `0` sentinel
collision. All of it is keyed on a handle that does not mean what it is being asked to
mean, and is cleared on every chunk load regardless.

The gameplay worry that prompted this — "flee a room, creep back, the sprinter is gone"
— is not reachable: at room scale the zed stays loaded, so its modData and verdict both
survive. It takes a chunk unload, by which point it is a different zombie anyway.

For:
- Consistent with how PZ already treats zombies. The zed you come back to is usually a
  different zombie, not the same one changed.
- Deletes most of the mod's most bug-prone machinery: the `sprinterIds` batching, the
  server broadcast, the unbounded growth bug, the `0` sentinel collision, and the
  recycled-verdict-inheritance bug above.
- Makes the `Skeletons` visual-identification feature *easier*, not harder: a zed is
  dressed once when promoted, and PZ's own recycling undresses it.
- `testedAtRisk` (step 3) exists to stop a permanent false verdict depressing an area.
  If verdicts are ephemeral, most of that problem evaporates on its own.

Against:
- Re-rolling an encounter by leaving and returning. But the range required is chunk
  unload distance, far beyond `MaxDistance2` (35), and at that range PZ has usually
  replaced the population anyway — so this is "PZ respawns zombies", not a new exploit.
- Within a single encounter identity must not churn. That is already guaranteed: while
  the zed stays loaded, both its modData and `sprinterIds` survive.

**Not yet decided.** The empirical question that settles how visible this is: when a
"reverted" sprinter is observed, does the debug overlay show the *same id*? A different
id means it is simply a different zombie and there is nothing to preserve.

---

## Re-testing and the risk-drift problem

*(Unchanged by the 2026-09-05 model revision, and slightly simplified by it: with
demotion there is no "vanilla sprinter skips the risk roll" special case left, so
every zed goes through the test below.)*

Today a failed roll is permanent: `client_queue.lua` returns early on
`data.sprinter == false`, and `updateZed` only rolls when `sprinterIds[id] == nil`.

This produces a real bias. A newbie inside the hours ease-in window, or anyone in a
low-risk zone, tests every zed they meet as non-sprinter — permanently. That area
stays depressed for the life of the save, even after a veteran arrives.

`false` *does* carry meaning ("tested, answer was no") and must be kept. The fix is to
make it **attributed and revisitable** rather than permanent:

```
sprinterIds[id] = { at = <risk when tested>, sprinter = true|false }
```

Re-test only when a player's current risk **exceeds** the risk the zed was last
tested at. Worked example — newbie at risk 5 and veteran at risk 100 in the same area:

- Newbie owns a zed, fails the roll -> stored as tested-at-5
- Veteran later owns it -> 100 > 5 -> re-tests -> likely promotes -> tested-at-100
- Veteran-tested zeds are never re-tested by the newbie, so no cross-client ping-pong
- Newbie logs off -> the veteran's ongoing encounters progressively lift the ratio

With roughly even zed ownership this lands near the 50% average while both are online,
and drifts back toward the veteran afterwards. That falls out of the mechanism rather
than needing to be averaged explicitly.

**Accepted consequence:** it only ever drifts *up*. If the veteran logs off,
already-promoted zeds stay sprinters. `OnEmptyServer` and the per-session reset give
the eventual floor. This is a deliberate choice, not an oversight.

### Reset paths that already exist

- Client session — `Core.startTime` + the `d.modified < Core.startTime` check in
  `getZedData`
- Empty server — `OnEmptyServer` clears `sprinterIds` (`server_events.lua:26-29`).
  The tick-counter logic driving it is convoluted but works.
- Zombie recycling — vanilla's `resetForReuse()` calls `getModData():wipe()`.
  **No periodic scrubber needed.**
- Vestigial: `zData.exp = (Core.delta or 0) + (Core.settings.Exp or 300)`
  (`client_main.lua:182`). `Core.delta` is never set, `settings.Exp` is not a sandbox
  option, the field is never read. A half-built expiry mechanism — delete or finish it.

---

## Sync boundary

**Verdicts sync. Throttles and caches do not.**

Zed modData is not replicated (see PHUNSTUFF.md). Keep `sprinterIds` as the sync
channel — it batches a delta list into one command per second. Keep `baseSpeedType`
in zed modData as a client-local cache and do *not* transmit it: vanilla re-rolls the
underlying value on activation cycles anyway, so an occasional disagreement between
clients is cosmetic and self-healing, and `transmitModData()` is one packet per object.

That is a deliberate "no", not an accidental one.

### Gotcha: the `0` sentinel collides

`Core.addToSend` (`core.lua:218-220`) does `if value == 0 then value = nil end`, and
both wire encoders (`client_events.lua:44-51`, `server_events.lua:60-67`) encode nil
as `0`. The moment the payload carries a risk *number*, `0` becomes a legitimate value
being silently eaten as "clear this entry". Needs a different sentinel or a separate
removal list.

---

## Design decisions — settled 2026-09-05

All three original open questions are closed, and demote-on-sight dissolved two of
them rather than answering them.

1. **Zone caps vs vanilla sprinters.** ~~Should `maxSprinterRisk = 0` suppress a
   vanilla-rolled sprinter?~~ **Moot.** After demotion there are no vanilla sprinters,
   so a safe haven works by construction. No code needed.
2. **Suppression target.** *Decided: apply `baseSpeedType`, and make sure a base is
   never sprinter by removing vanilla's ability to roll one at startup.* The sandbox
   option `PhunSprinters.VanillaSprinters` is consulted **only on a `Speed = 1`
   server**, where every zed would otherwise run and there is no distribution worth
   preserving:
   - `1` Fast shamblers (default) — 0.85 speedMod, lunger, no run
   - `2` Shamblers — 0.55, no lunger
   - `3` Random — handed back to vanilla as `Speed = 4` with `SprinterPercentage = 0`,
     so vanilla's own `Rand.Next(2) + 2` does the mixing.

   On `Speed = 4` the option is unused: only `SprinterPercentage` is zeroed and the
   admin's mix is preserved. On `Speed = 2`/`3` nothing is touched at all.

   **Implemented.**
3. **Does mode/light gating apply to inherited sprinters, or only mod-promoted ones?**
   ~~Sandbox option?~~ **Moot.** Every sprinter is mod-promoted, so everything is
   gated, uniformly, on every server. No option needed.

---

## Bug list from the review (independent of the refactor)

Ordered roughly by impact.

- **`Core.getId` is not an identity, and `sprinterIds` does not persist anything.**
  Found 2026-09-05 by observation, then confirmed against the jar. See
  **Identity is already ephemeral** below. This supersedes an earlier claim in this doc
  that recycled zombies *inherit* the previous occupant's verdict — they do not, because
  `getZedData`'s reset path clears it first. The real behaviour is a re-roll on every
  chunk round-trip.

- **Unbounded `sprinterIds` growth.** `shouldSprint` publishes `false` for failed
  rolls, but `server_events.lua:85` and `:104` both gate cleanup on *truthiness*, so
  those entries are never removed — they persist in global ModData and get sent whole
  to every joining client via `server_commands.lua:23`. Fix: nil test, not truthy test.
- **`Speed = 4` breaks `makeNormal`.** `getDefaultSpeed()` returns 4, `makeNormal`
  writes it back, and the `makeInactive` toggle re-rolls — "make this zed normal" can
  randomly produce a sprinter. Disappears with the refactor.
- **PhunServer detection is probably dead.** `core.lua:236` still uses
  `getActivatedMods():contains("\\phunserver")`. That backslash prefix was
  deliberately dropped between `42.14/phunzones.lua` and `common/phunzones.lua`.
- **`shouldSprint` risk-0 asymmetry.** At risk 0 it publishes `nil` (correct — leaves
  the zed untested for others) but still sets `zData.sprinter = false` locally, which
  permanently excludes the zed from that client's queue.
- **Stale `originalSpeed`** survives in zed modData across sandbox changes. Removed by
  the refactor.
- ~~**Debug overlay can throw.**~~ **Fixed 2026-09-05.** Both guarded, and
  `getLightLevel(0)` became `getLightLevel(playerNum)` to match `adjustForLight`. Done
  out of order because the overlay is the instrument the in-game testing depends on.
- **Settings only re-read if `Debug` was on at startup** (`client_events.lua:60-69`).
  Same for the debug render hook — toggling Debug mid-session does nothing.
- **`transmitModData()` call is inverted and inert.** `client_main.lua:187-189` calls
  it only when `isLocal`; in SP both `GameClient.client` and `GameServer.server` are
  false, so it only does `flagForHotSave()`.
- `shouldSprint` uses `getPlayer()` rather than the zed's target — wrong player in
  splitscreen.
- `Core.getOption()` does two `getOptionByName()` lookups per call and sits in hot
  paths (`client_main.lua:108`, `:138`, per scream). Use cached `Core.settings`.
- `MaxQueue` code fallback is 10, sandbox default is 20.

### Dead code

- `Core.pendingIds` — written in `client_commands.lua:17`, never read
- `zData.exp` / `Core.delta` / `settings.Exp` — see above
- `PhunSprinters.Volume` sandbox option — defined, never read
- `Skeletons` — rewired 2026-09-05, then **disabled again the same day: the vanilla
  crash is real and still present on B42.** Reproduced by aiming at a skeleton outside
  debug mode. The sandbox option was **removed**, not merely defaulted off, so a player
  cannot switch a known client crash back on. The clearing path
  (`isSkeleton() -> setSkeleton(false)`) stays live so zeds carrying a skeleton from an
  earlier session are put back to normal, and `client_decorate.lua` documents exactly
  how to reinstate it if vanilla is ever fixed. The mechanism was sound — `IsSkeleton`
  is a `NetworkZombieVariables$Flag` in `ZombiePacket.booleanVariables`, so it
  replicates with no mod networking — which is why it briefly looked like a way to
  carry sprinter identity through suppression. That idea dies with the feature.
- `formatNumber` duplicated in `client_risk.lua:8` vs `Core.tools.formatNumber`
- `client_risk.lua:58` `if minRisk == nil` — unreachable, line 53 ends in `or 0`
- `client_queue.lua:37` passes a 4th `distance` arg `adjustForLight` does not take
- `client_main.lua:29-30` — `zzz` and `sprinters` unused
- `ui/tools.lua:108` `box.joypadParent = self` — `self` is nil at module scope
- `42.15/` is **byte-identical** to `common/` — delete it

### Repo hygiene

No `.gitignore` (though `xclude` references `CLAUDE.md`, `.claude`, `.gitignore`, none
of which exist). `README.md` is a one-line stub while `workshop.txt` has the full
write-up. `mod.info` has no `versionMin` or `modversion`.

---

## Suggested order

*Status: 1 and 2 done. 3 dropped as moot. 4 mostly dissolved — the identity model is
now "the zed's modData, and it dies with the zed". 5 outstanding.*

1. ~~Direct-speed refactor — kills the sandbox toggling, the `DoZombieStats` cost, the
   fake-shambler nondeterminism, the `originalSpeed` staleness and the `Speed = 4` bug
   in one pass~~ **done, see below**
2. `sprinterIds` cleanup on death/removal (the nil-test fix)
3. `testedAtRisk` re-testing, plus the `0`-sentinel change it forces
4. `baseSpeedType` capture and the un-promote / suppress split
5. `\\phunserver` prefix, dead code, `42.15/`

---

## What step 1 actually changed (2026-09-05)

### First pass: the mechanical refactor

`client_main.lua`:

- Deleted `_defaultSpeed`, `getDefaultSpeed()`, the file-level `sandboxOptions` local
  and every `sandboxOptions:set("ZombieLore.Speed", …)` / `makeInactive` bracket.
- Added `applySpeedType` (a 1/2/3 -> `doSprinter`/`doFastShambler`/`doShambler` table)
  and a local `applySpeed(zed, zData, target)` that no-ops when `zed.speedType` already
  matches or the zed is inactive, and records `zData.appliedSpeed`.
- `Core.getBaseSpeedType(zed, zData)` — captures vanilla's verdict off `zed.speedType`
  once. Falls back to `2` *without caching*, so the capture retries on the next update.
- `Core.reassertSpeed(zed, zData)` — re-applies `zData.appliedSpeed`. Necessary
  because an inactive -> active cycle sets `speedType` to `-1` and re-rolls it.
- `makeNormal` resolves its target *before* clearing `zData.sprinting`, since the
  capture guard reads that flag to decide whether `zed.speedType` is vanilla's or ours.
- `updateZed` calls `getBaseSpeedType` immediately after the id guard, so the capture
  happens on the first update while the zed is still untouched. Deferring it to
  `makeSprint` was not safe: if that first call landed on an inactive zed the capture
  would fail, and `zData.sprinting` would then block it permanently.
- `getZedData` no longer stores `originalSpeed`, and only restores speed on the reset
  path when `d.sprinting` — we undo what we did, and leave every other zed's vanilla
  speed alone.

`client_queue.lua`: the close-range branch is gated on `isSprinter` rather than
`Core.sprint and isSprinter`, with `Core.sprint` moved inward, and calls
`Core.reassertSpeed`. Those zeds never reach `updateZed`, so without this a zed that
cycled active inside `MinDistance2` would silently drop back to its sandbox roll.

`client_debug.lua`: overlay prints `baseSpeedType` instead of `originalSpeed`.

New: `PhunSprinters.VanillaSprinters` in `sandbox-options.txt` plus both
`Sandbox_EN.txt` and `Sandbox.json`. (Briefly named `SuppressedSprinterSpeed`; renamed
in the same session, before shipping, so there is no migration concern. Its meaning
narrowed twice as the model changed — it now applies only on a `Speed = 1` server.)

### Then revised the same day to demote-on-sight

- `getBaseSpeedType` now demotes: a clean read of `speedType == 1` is replaced by
  `demotedSpeedType()` (the `VanillaSprinters` option, with the Random roll taken once
  and stored). `baseSpeedType` is therefore never `1`.
- Its "is this read clean" guard changed from `not zData.sprinting` to
  `not zData.appliedSpeed` — the stricter test, since `appliedSpeed` is also set when
  we suppress, not only when we sprint.
- `Core.getSuppressedSpeedType` and `Core.restoreBase` are **deleted**; `makeNormal` is
  the single "put it at its base" operation.
- `updateZed`'s `elseif zData.sprinting` became a plain `else`. This is the change that
  makes demotion real rather than merely recorded: a demoted zed that was never
  sprinting still has to be *put* at its base. `applySpeed` no-ops when the zed is
  already correct, so the unconditional call is free.
- `getZedData`'s reset path keys off `d.appliedSpeed` rather than `d.sprinting`, for
  the same reason.
- `client_queue.lua`'s close-range early return gained `and isSprinter ~= nil`. A zed
  that streams in inside `MinDistance2` has never been tested, so it has never been
  demoted either, and under the old code it would never be queued — it would just
  sprint at the player. Untested zeds now reach the queue once regardless of distance.

### Then revised again to the startup neuter

Prompted by the observation that speed is not persisted, so changing the global once is
enough — every existing zed re-rolls on its next load or activation cycle. Verified
against the jar before committing to it; the findings are in PHUNSTUFF.md under
**Mutating a sandbox option at runtime**.

Net deletions from the demote-on-sight pass:

- `Core.getBaseSpeedType` and `demotedSpeedType()` — **gone**. The read is now two
  lines inside `makeSprint`, taken in the moment before we overwrite the value, with no
  guards: vanilla cannot produce a `1`, so a `1` can only be ours.
- The early capture call in `updateZed` — **gone**. Nothing to capture early.
- `updateZed`'s unconditional `else` — **reverted** to `elseif zData.sprinting`. Only
  zeds we actually made sprint need correcting.
- `client_queue.lua`'s `isSprinter ~= nil` — **reverted**. An untested zed is an
  ordinary non-sprinter again, not an undemoted hazard.

Added: `Core.neuterVanillaSprinters()` in `core.lua` (shared), called from the end of
`Core:ini()` so it runs on both the client's `setup()` and the server's
`OnServerStarted`, after `Core.settings` is populated. Re-run every minute on both
sides. The close-range `reassertSpeed` call and the `d.appliedSpeed` reset guard both
survive from the previous pass — they were not demotion-specific.

### Fix from the first in-game test (2026-09-05)

Test 1 (`Speed = 1`, Mode Always, DefaultRisk 100 — everything sprints) showed
`baseSpeedType` as `?` on every zed. Test 2 showed `?` too, but that one was correct:
nothing ever sprinted, and the base is only recorded when we make a zed sprint.

Cause: neutering changes what vanilla rolls **next**. Zeds already in the world keep
`speedType == 1` until their next activation cycle, and on a Sprinter server that is
every zed we meet at first. `makeSprint` refused to record a `1` on the reasoning that
"a 1 could only be ours" — true for a freshly rolled world, false during the changeover
— and never retried, so the base stayed nil for that zed's life. The zeds still behaved
correctly, because the nil fell through to the fallback; only the recorded value was
missing.

- `Core.captureBaseSpeed` (shared) replaces the inline read and **always** records
  something: vanilla's value when it is 2 or 3, otherwise `Core.neuteredSpeedType()` —
  what the neutered sandbox would have given that zed anyway.
- `Core.neuteredSpeedType()` replaces the arbitrary `FALLBACK_SPEED = 2` constant, so
  the fallback follows the `VanillaSprinters` setting instead of guessing.
- `Core.speedTypeOf(zed)` prefers the `getSpeedType()` accessor over the bare
  `zed.speedType` field. Both `speedType` and `inactive` are confirmed `public` on
  `IsoZombie`, but PZ's Lua binding does not reliably expose public fields and a real
  accessor exists, so use it. There is no `isInactive()`; `zed.inactive` has no
  alternative and stays a field read.
- Debug overlay now prints `base>live` — the recorded base, then the zed's current
  `speedType`. A `live` of `nil` means the read itself is broken, which is the signal
  the old overlay could not distinguish from a capture failure.

### Known limits

- Un-promoted zeds are not re-asserted (they return early from `updateZed`). Harmless
  now: with vanilla sprinters disabled, a drifted zed re-rolls to a non-sprinter.
- A zed that cycles inactive -> active *inside* `MinDistance2` and is not in
  `sprinterIds` is not re-asserted. Same reasoning — it can only re-roll to a
  non-sprinter, so nothing runs that should not.
- The startup call is client-local; see the MP note under **Core model**.
- `baseSpeedType` is a client-local cache and deliberately not transmitted — see
  **Sync boundary**.

### Not verified in-game

Everything above is a static change: all Lua parses, but nothing has been run against
a live B42 client. The reads that need confirming on a real zed are `zed.inactive` and
`zed.speedType` as **plain field accesses from Kahlua** — PHUNSTUFF.md says both are
public on B42, but that came from the jar, not from a running game.

### Also found

`Core.testPlayers` (`client_main.lua`) has no callers at all — add it to the dead-code
list in step 5.

---

## Step 2: the sync layer is gone (2026-09-05)

The sprinter verdict now lives in the zed's own modData and nowhere else. It is not
published, not synced, not persisted, and needs no cleanup — the zed dying or being
recycled disposes of it.

**Deleted**

- `Core.sprinterIds`, `Core.toSend`, `Core.lastSend`, `Core.pendingIds`,
  `Core.addToSend`, and the mod's global `ModData` table
- `commands.isSprinter` and `commands.playerSetup`, both directions, plus the
  per-second batched send on the client *and* the server, and the whole-table
  broadcast to every joining client
- `events.OnEmptyServer` and the `OnTickEvenPaused` tick-counter machinery that
  drove it — it existed only to clear the verdict table
- `OnZombieDead` and the PhunZones `OnZombieRemoved` handler — both only pruned it
- `OnReceiveGlobalModData` on the client
- `Core.pendingCalcs`, whose only clearer was the server's verdict push

**Bugs that ceased to exist rather than being fixed**

- Unbounded `sprinterIds` growth (the truthiness-vs-nil cleanup bug) — nothing to grow
- The `0` sentinel collision in `addToSend` — nothing to encode
- MP sync keyed on a per-client object handle — nothing crosses the wire, and every
  remaining use of `Core.getId` (`queueIds`, `zData.id`, the overlay) is local, where
  a per-client handle is exactly right
- The `shouldSprint` risk-0 asymmetry. Risk 0 now records a plain `false`, which was
  only ever dangerous because the verdict was permanent and global

**Replaced**

- `pendingCalcs` becomes a real precondition: `updateZed` will not test a zed until
  `pData.risk` exists. Previously the gate was "the server has sent us the table",
  which is not the thing that actually needs to be ready.

**Consequence to watch.** Each client now tests independently against its own risk. On
handover of a *suppressed* sprinter the new owner may reach a different verdict — see
the MP section. An actively sprinting zed carries its own evidence (`speedType == 1`
cannot occur without a mod having caused it), so the visible case is covered; adopting
that signal explicitly is not yet implemented.

**Step 3 (`testedAtRisk`) is dropped, not deferred.** It existed to stop a permanent
false verdict depressing an area. Verdicts are not permanent.

---

## Provenance

Every API claim above was verified by disassembling
`D:\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar` (B42) and diffing
against `D:\pz41\steamapps\common\ProjectZomboid` (B41). No claim here came from
recollection. If something looks wrong, re-check the jar rather than trusting this doc.
