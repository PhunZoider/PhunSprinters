# PhunSprinters B42 test plan

For the `b42-speed-refactor` branch. Written 2026-09-05, after the speed refactor, the
sync-layer removal, adoption, and the step 5 cleanup.

Design and rationale live in `B42-speed-refactor.md`. This is only how to check it works.

---

## Setup

- **A fresh world.** The old test world had a sandbox fault unrelated to this mod (see
  "The DefaultRisk hunt" in the design doc). Do not use it.
- **`PhunSprinters.Debug = true`.** The overlay is the instrument for most of this.
  It can now be toggled mid-session, but have it on from the start anyway.
- **Edit sandbox values with the server down.** It rewrites on shutdown.
- Have the server console visible. Several checks are log lines, not in-game effects.

### Reading the overlay

Each zed within 25 tiles is labelled:

```
<getID>/<onlineId> (<state>) <adjLight>/<light>/<threshold> <base>><live> [SKEL]
```

| Colour | State | Meaning |
|---|---|---|
| grey | `untested` | never entered the 14–35 tile test band |
| green | `no` | tested, failed the roll |
| yellow | `walk` | one of ours, not running right now |
| red | `run` | one of ours, running |

`base>live` is the speed it returns to, then its actual `speedType` right now.
**`live` showing `nil` means the speedType read is broken — stop and report that.**

`getID` is per-client and will differ between clients; `onlineId` is the network
identity and must match. Use `onlineId` to line up the same zed across two clients —
**but only in multiplayer. In single player `onlineId` is `-1` for every zed**, so use
`getID` there. It is stable within a session, and reused across zeds after that.

`PhunSprinters.dumpSettings("check")` from the console prints every setting three ways
if a value ever looks wrong.

---

## A. Vanilla sprinters are disabled — single player, fastest to run

The whole model rests on vanilla never rolling a `speedType` of 1. Check this first;
if any of it fails, nothing downstream is meaningful.

| # | Setup | Expect |
|---|---|---|
| A1 | `Zombie Speed = Fast Shamblers (2)` | **No** "Vanilla sprinters disabled" console line. Admin's setting untouched. |
| A2 | `Zombie Speed = Shamblers (3)` | Same — no line, nothing changed. |
| A3 | `Zombie Speed = Sprinters (1)`, Mode `Dusk till dawn`, daytime | Console: `Vanilla sprinters disabled: ZombieLore.Speed was 1, now N`. **Nothing runs.** Before this branch every zed sprinted. |
| A4 | `Zombie Speed = Random (4)`, **`SprinterPercentage` non-zero** | Console: `SprinterPercentage set to 0`. Overlay `live` shows a **mix of 2 and 3**, never 1. This is the distribution being preserved rather than flattened. |

`SprinterPercentage` must be non-zero for A4 to prove anything — at 0 the neuter is a
no-op and vanilla was never going to roll a sprinter anyway.

**A5 — `VanillaSprinters` option**, on `Zombie Speed = Sprinters` only:

- `Fast shamblers` → `base` reads 2
- `Shamblers` → `base` reads 3
- `Random (fixed per zed)` → mix of 2 and 3, and **each zed keeps its own** across
  repeated suppress/resume cycles

---

## B. Sprint and suppress

| # | Setup | Expect |
|---|---|---|
| B1 | Mode `Always`, `DefaultRisk = 100` | Every zed red `run`. `base>live` = `N>1`. |
| B2 | Mode `Dusk till dawn` | Red at night, yellow `walk` by day. Chime plays on the transition. |
| B3 | `SlowInLight = true`, night | Shine a torch at a red zed → drops to yellow, `live` becomes its `base`. Kill the light → back to red. |
| B4 | Mode `When its too dark around them` (4) | Same as B3 but per-tile, without needing `SlowInLight`. |
| B5 | Walk a sprinter between lit and dark repeatedly | `base` never changes. Only `live` moves. |
| B6 | Mode `Dusk till dawn`. Stand **inside 14 tiles** of a known sprinter across a dusk *and* a dawn | It starts at dusk and stops at dawn without you moving. Regressed once: the close-range path could hold a sprint but never start or stop one, so close zeds stayed red through the day. |

B5 is the one that catches a regression in `captureBaseSpeed` — a `base` that drifts
means we are re-reading our own output.

---

## C. Speed is held against vanilla's re-rolls

Vanilla resets `speedType` on every inactive → active cycle. `reassertSpeed` exists for
this, and it is easy to break without noticing.

| # | Steps | Expect |
|---|---|---|
| C1 | Get a zed sprinting, walk out past ~50 tiles, come back | Still sprinting. Note `getID` before leaving (SP) or `onlineId` (MP). |
| C2 | Get a sprinter within 14 tiles (`MinDistance2`) and stay there a while | Stays red. These zeds never reach `updateZed`, so they are held by the separate path in `enqueueUpdate`. |
| C3 | Leave the area entirely so the chunk unloads, return | Different zeds, fresh verdicts, all fine. **A different id means it is simply a different zombie — not a bug.** |

---

## D. Risk

| # | Setup | Expect |
|---|---|---|
| D1 | `DefaultRisk = 0`, no PhunZones coverage | Every zed green `no`. None grey-stuck. |
| D2 | `DefaultRisk = 100` | Every zed promoted. |
| D3 | `DefaultRisk = 50` | Roughly half. Sample a few dozen, not five. |
| D4 | PhunZones zone with `maxSprinterRisk = 0` | **No sprinters in that zone.** This was broken until `02fa329` — the cap was skipped entirely when it was 0. |
| D5 | `HoursDiscount = 100`, fresh character | Risk scales in with survived hours; `risk=` lines in the console climb. |

**D1 and D4 need a spot PhunZones does not cover, or a zone you control.** A zone's
`minSprinterRisk` overrides `DefaultRisk` entirely, so testing `DefaultRisk` inside a
covered zone tells you nothing.

---

## E. Multiplayer

The sprinter verdict is **not** synced. Speed, skeleton state and outfit replicate
natively; each client tests independently against its own risk.

| # | Steps | Expect |
|---|---|---|
| E1 | Two clients on one horde, compare labels | `getID` **differs**, `onlineId` **matches**. Verdicts may legitimately differ. |
| E2 | Client A promotes a zed (it goes red) | Client B, once in range, **adopts** it — also red. Console on B: `Adopting sprinter … promoted by another controller`. |
| E3 | After E2, client A leaves the area | B keeps managing it: still suppresses in light, still stops at dawn. **This is the orphan case that was broken before `4bcd2cc`.** |
| E4 | Client A has a zed *suppressed* (yellow), hands over to B | B may test it fresh and disagree. **Known gap, not a bug** — see the design doc. It is walking either way. |
| E5 | Admin edits a setting mid-session | Both clients pick it up (vanilla re-pushes sandbox). |
| E6 | Fresh client joins a running server | No Lua errors. `dumpSettings` on the client matches the server. |

---

## F. The step 5 fixes

Small, easy to forget, and two of them were live bugs.

| # | Check | Expect |
|---|---|---|
| F1 | `Volume = 0` | Zed screech **silenced**. It never was before — the screech was reading the wrong option. |
| F2 | `Volume = 100`, `SprintingChangeNotificationVolume = 0` | Screech loud, day/night chime silent. The two are now independent. |
| F3 | Run with `phunserver2` + `phunserver2daynight` | Console: `PhunServer2DayNight detected, following its day/night events`. Dusk/dawn follow its offsets, and the transition lands **immediately**, not up to a minute later. |
| F3b | Run with the deprecated PhunLib and no PhunServer2DayNight | Console names `PhunLib` instead. Legacy path still works. |
| F3c | Run with **neither** | No such line, no errors, dusk/dawn still work from `Core:calcNight` on the minute tick. |
| F4 | Toggle `Debug` off mid-session, then on | Overlay stops, then starts. Previously it only wired if Debug was on at startup. |
| F5 | Splitscreen, two local players in different zones | Each zed tests against the player it is targeting, not always player one. |

---

## G. Startup and footprint

| # | Check | Expect |
|---|---|---|
| G1 | Server start | No Lua errors. `Initializing Core`, then the settings dump when Debug is on. |
| G2 | Client start, SP and MP | Same, no errors. |
| G5 | Log in **at night**, Mode `Dusk till dawn` | Sprinters are active immediately, not after a delay, and no spurious chime a minute in. The client used to start with `isNight` unset, which read as day. |
| G3 | Play a session on `Zombie Speed = Sprinters`, quit | The save's sandbox file **still says Sprinters**. Our neuter is in-memory only and must never persist. |
| G4 | Remove the mod, load the save | Zeds behave per the sandbox. No leftovers. |

G3 is the one that matters for shipping: we mutate a global sandbox option at runtime,
and the whole justification is that it never reaches disk.

---

## Known behaviours that are not bugs

Do not spend time on these:

- **A zed's verdict changes after you leave and return.** Zombie identity is ephemeral
  in PZ; that is usually a different zombie on a recycled id handle.
- **Two clients disagreeing about a zed that is not currently running.** Expected —
  each tests against its own risk.
- **`base` showing `?`.** Only recorded once a zed has actually sprinted.
- **Grey `untested` zeds close to the player.** Zeds are tested in the 14–35 tile band;
  one that spawned closer and stayed there is never tested, and is therefore not a
  sprinter. Harmless.
- **Skeleton sprinters missing.** Deliberately disabled — the vanilla crash on aiming at
  a skeleton is real and still present on B42.

---

## Still unverified

- **Whether the server rolls speed for zeds no client owns.** `neuterVanillaSprinters`
  runs server-side to cover it, but the behaviour itself has not been observed.
- **Whether an admin saving sandbox settings on a modded server persists our
  `ZombieLore.*` override** into the server config. `GameServer.receiveSandboxOptions`
  ends in `saveServerLuaFile`, and whether the admin UI sends the live singleton or a
  fresh copy is not established. Diff the server's `_SandboxVars.lua` before and after
  an admin save to settle it.
