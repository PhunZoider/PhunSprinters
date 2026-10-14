# PhunSprinters 2

A dynamic sprinter system for Project Zomboid B42.

While vanilla gives you a fixed percentage of sprinters, everywhere, forever,
PhunSprinters makes it situational: risk changes with where you are, how long you have
survived, the moon phase, and the light around each zombie.

[Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252110) ·
[Discord](https://discord.gg/v2USyAtP6q)

---

## How risk is calculated

Risk is worked out **per player**, recalculated every minute and whenever you cross into
a new zone. Each zombie then rolls against it **once**, the first time a player gets
close enough to test it.

```
base   =  zone minSprinterRisk,  or Default Risk if the zone does not set one
risk   =  base  x  moon multiplier  x  hours factor
risk   =  capped at the zone's maxSprinterRisk   (100 if the zone does not set one)
risk   =  clamped to 0-100
```

| Term              | Where it comes from                                                             |
| ----------------- | ------------------------------------------------------------------------------- |
| `base`            | The zone's `minSprinterRisk`, falling back to the **Default Risk** setting      |
| `moon multiplier` | The **Moon Phase Multiplier** for tonight's phase, divided by 100               |
| `hours factor`    | `hours survived / Hours Discount`, capped at 1. Always 1 if Hours Discount is 0 |
| cap               | The zone's `maxSprinterRisk`                                                    |

A worked example. Default Risk 40, full moon (multiplier 200), 30 hours survived with an
Hours Discount of 100, in a zone with no overrides:

```
base          40
full moon     40 x 2.00   = 80
hours factor  80 x 0.30   = 24      (30 hours of the 100 needed)
cap           no zone cap, so 100
result        24% of zombies you meet will be sprinters
```

At 100 hours survived the same player sits at 80%. The moon swings it up and down
nightly from there.

### What "risk" actually decides

Risk is the **chance a given zombie is a sprinter**, not how fast anything moves. A
zombie that fails the roll is a normal zombie for good. A zombie that passes becomes one
of ours, and then the **mode** and **light** rules decide whether it is actually running
at any given moment.

The verdict lives on the zombie and dies with it. Zombies are recycled aggressively by
the game, so a zombie you meet after leaving and returning to an area is usually a
different zombie with its own roll, not the same one changing its mind.

---

## Modes

| Mode                               | When sprinters run                                                                                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1. Dusk till dawn                  | Walk during the day, run once the sun goes down                                                                                                              |
| 2. Always                          | Always run, the way vanilla sprinters do                                                                                                                     |
| 3. When it is too dark outside     | Run at night, and during weather that drops visibility, even in daytime                                                                                      |
| 4. When it is too dark around them | Run whenever the light on their own tile drops below your Darkness Level. Even if it's bright outside, turn the lights off in a room and watch it come alive! |

Mode 4 is the most interesting and the most expensive. It is evaluated per zombie per
tile, so your torch matters moment to moment.

### Light suppression

**Slow in light** brings mode 4's behaviour to modes 1, 2 and 3: a sprinter that is
already running drops back to a walk when the light on its tile rises above your
**Darkness Level**, and picks up again when it gets dark. Mode 4 already works this way,
so the setting does nothing there.

The light figure compared against Darkness Level is 0-100:

- **Indoors**, and **outdoors at night**, it is the light on the zombie's own tile, so a
  torch beam genuinely suppresses what it lands on.
- **Outdoors in daylight** it is the global fog-adjusted brightness instead, because the
  per-tile value outdoors is always effectively full daylight and would ignore weather.

---

## Sprinter speed

Full-speed sprinters are a lot. **Sprinter Speed %** slows them down without taking them
away, so you can play with sprinters that are dangerous rather than instant death.

| Value | Effect                          |
| ----- | ------------------------------- |
| 100   | Vanilla sprinters. The default  |
| 75    | 25% slower                      |
| 50    | Half speed                      |
| 25    | The minimum, a quarter speed    |

It slows the whole run, including the final lunge, by playing the sprint animations
slower. Zombie movement follows the animation, so the zombie genuinely covers less
ground; it is not a cosmetic change.

### A range of speeds

Set **Slowest Sprinter Speed %** below Sprinter Speed and each sprinter gets its own speed
somewhere between the two. With 50 and 90, some sprinters barely outpace a jog and others
are nearly vanilla, so a crowd stops arriving as one wall.

Slowest Sprinter Speed defaults to 100. At or above Sprinter Speed it does nothing, and
every sprinter runs at exactly Sprinter Speed, as before. A PhunZones zone can override
either end of the range; see [Zone recipes](#zone-recipes).

- **Only our sprinters are affected.** A zombie this mod never made sprint, such as a
  Mutants type you have ticked to ignore, runs at the normal vanilla speed.
- **Each sprinter keeps its speed.** A sprinter's speed is fixed when it first starts
  running, so changing the setting affects new sprinters, not ones already chasing you.
  Settings reach clients within a game minute, so give it a moment before testing.
- **It does not survive a restart**, the same as the sprinter verdict itself. After a
  restart zombies are tested afresh, and any new sprinters get the current value.

This works by replacing the vanilla zombie sprint animation files with copies whose speed
is read from the setting. Other "slower sprinters" mods replace the same files, so run
one or the other, not both. See [Compatibility](#compatibility).

---

## Zone recipes

These need [PhunZones 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252660).
PhunSprinters reads two risk values off whatever zone the player is standing in, and two
speed values off whatever zone the sprinter is standing in when it first starts running:

| Key                | Effect                                                             |
| ------------------ | ------------------------------------------------------------------ |
| `minSprinterRisk`  | Replaces Default Risk as the base for this zone                    |
| `maxSprinterRisk`  | Caps the final risk in this zone, after moon and hours are applied |
| `minSprinterSpeed` | Replaces Slowest Sprinter Speed % in this zone, 25-100             |
| `maxSprinterSpeed` | Replaces Sprinter Speed % in this zone, 25-100                     |

All are optional. Leave one unset and the global setting applies. A sprinter keeps its
speed when it follows you into another zone.

**Slower sprinters near spawn.** Set `minSprinterSpeed` to `40` and `maxSprinterSpeed` to
`60` in a starter town, so the sprinters new players meet are survivable.

**A safe haven.** Set `maxSprinterRisk` to `0`. No sprinters in that zone, whatever the
moon is doing and however long the player has survived. Good for a starter town or a
designated trading post.

**A guaranteed nightmare.** Set `minSprinterRisk` to `100` and `maxSprinterRisk` to
`100`. Everything sprints there, always, regardless of the hours ease-in. Good for a
military base or a late-game loot zone that should stay lethal.

**Graduated difficulty.** Leave Default Risk low, say `10`, and raise `minSprinterRisk`
per zone as you move away from spawn: `20` in the suburbs, `50` downtown, `80` in the
mall. The map itself becomes the difficulty curve.

**A dangerous area that eases in.** Set `minSprinterRisk` to `80` but leave Hours
Discount at, say, `200`. New characters get a fraction of it; veterans get the full
weight. The zone is always the most dangerous place on the map, relative to whoever is
standing in it.

**A cap that still lets the moon matter.** Set `minSprinterRisk` to `30` and
`maxSprinterRisk` to `50`. Normal nights sit near 30, full moons push toward the cap, and
the zone never becomes a bloodbath.

---

## Hours discount

Ramps difficulty with time survived rather than throwing full risk at a fresh character.

```
hours factor = hours survived / Hours Discount     (capped at 1)
```

With Hours Discount at `100` and an area risk of 50%:

| Hours survived | Effective risk |
| -------------- | -------------- |
| 0              | 0%             |
| 25             | 12.5%          |
| 50             | 25%            |
| 75             | 37.5%          |
| 100 and beyond | 50%            |

Set it to `0` to disable the ramp entirely. Hours carry across death, so a player who
dies at hour 90 does not restart the ease-in.

Useful on fresh servers, and for keeping a new player's first night survivable on a
server where the veterans want full risk.

---

## Moon phases

The moon **multiplies** risk. It does not replace it, so a zone with 0 risk stays at 0
however full the moon is.

| Phase    | Setting                       | Default |
| -------- | ----------------------------- | ------- |
| New      | `MoonPhaseMultiplierNew`      | 50      |
| Crescent | `MoonPhaseMultiplierCrescent` | 75      |
| Quarter  | `MoonPhaseMultiplierQuarter`  | 90      |
| Gibbous  | `MoonPhaseMultiplierGibbous`  | 100     |
| Full     | `MoonPhaseMultiplierFull`     | 200     |

Values are percentages: `200` doubles the risk, `50` halves it, `100` leaves it alone.
Waxing and waning phases share a setting, so the eight game phases map onto these five.

With a 20% area risk: a full moon night is 40%, a new moon night is 10%.

Set a phase to `0` and there are no sprinters at all on those nights, which makes new
moons a genuine window to travel in.

---

## The sensor panel

A small panel beside the clock shows tonight's moon and a row of pips for your current
risk. Hover it for the breakdown: the area's risk, the moon modifier, any hours discount,
whether conditions currently let sprinters run, and tomorrow's moon.

With **Always Show UI** on, everyone sees it. Turn it off and the panel only appears while
wearing a **Military Sensor** on either wrist; tick **Lootable Sensor** to put those into
the loot tables. Turn both off for no panel at all. Both need a restart.

**UI Layout** switches the panel between horizontal and vertical.

---

## Sounds

Two sounds, each with a server volume in the sandbox settings:

- **Percentage Sprinters Volume**: the screech a sprinter gives the first time it runs.
- **Sprinting Change Volume**: a chime when conditions change, as sprinting becomes
  possible (dusk, bad weather) or stops being possible (dawn). It announces the
  conditions, not a particular zombie, so with Slow in light or mode 4 it can sound a
  while before anything actually runs.

Setting either to `0` turns it off for everyone. Each player can then scale both for
themselves under **Options > Mods > Phun Sprinters**: `100` is as the server set it, `0`
mutes it for that player alone, and up to `200` makes it louder.

---

## Settings reference

| Setting                        | Default        | What it does                                                               |
| ------------------------------ | -------------- | -------------------------------------------------------------------------- |
| Mode                           | Dusk till dawn | When sprinters run. See above                                              |
| Slow in light                  | off            | Light drops a running sprinter back to a walk                              |
| Darkness Level                 | 74             | The 0-100 light level sprinting is gated on                                |
| Sprinter Speed %               | 100            | How fast sprinters run, 25-100% of vanilla. See [Sprinter speed](#sprinter-speed) |
| Slowest Sprinter Speed %       | 100            | Bottom of the speed range. At or above Sprinter Speed, there is no range    |
| Default Risk                   | 1              | Base sprinter chance where no zone overrides it                            |
| Hours Discount                 | 0              | Hours of survival before full risk applies. 0 disables                     |
| Moon Phase Multipliers         | 50-200         | Per-phase risk multipliers                                                 |
| Replace vanilla sprinters with | Fast shamblers | What the game's own sprinters become. See below                            |
| Percentage Sprinters Volume    | 10             | Volume of the sprinter screech. See [Sounds](#sounds)                      |
| Sprinting Change Volume        | 15             | Volume of the chime when conditions change. See [Sounds](#sounds)          |
| Decorate Sprinters             | on             | Dress sprinters up around the holidays, if the relevant mods are installed |
| Always Show UI                 | on             | Show the [sensor panel](#the-sensor-panel) without needing the wearable    |
| Lootable Sensor                | off            | Put the military sensor into loot, for when the UI is not always shown     |
| UI Layout                      | Horizontal     | Sensor panel orientation                                                   |
| Min / Max Distance             | 14 / 35        | The band, in tiles, where zombies are tested                               |
| Max Queue                      | 20             | Zombies evaluated per tick. Lower it if you see stutter in hordes          |
| Ignore (mutant type)           | Leaper, Weeper | Per-type opt-out for The Mutants. See [Compatibility](#compatibility)      |
| Debug                          | Off            | Per-zombie overlay: Simple (speed only) or Extended (detail and logging)   |

---

## Using this with the vanilla Zombie Speed setting

PhunSprinters has to own who runs, so it takes vanilla's sprinters off the board when the
world loads.

| Your Zombie Speed | What happens                                                                                                      |
| ----------------- | ----------------------------------------------------------------------------------------------------------------- |
| Sprinters         | Converted to whatever **Replace vanilla sprinters with** says. PhunSprinters decides which of them run from there |
| Random            | Only the sprinter share is removed. Your fast shambler and shambler mix is untouched                              |
| Fast Shamblers    | Nothing changes. There were no vanilla sprinters to replace                                                       |
| Shamblers         | Nothing changes                                                                                                   |

This is what makes the rest of the mod work. A vanilla sprinter used to ignore light
suppression, dusk till dawn and zone limits entirely, because there was no way to slow
one down.

**Nothing is written to your save.** The change applies for the session only, so removing
the mod gives your settings back exactly as they were.

**Want vanilla behaviour back?** Set Default Risk to 100 and Mode to Always.

**Replace vanilla sprinters with** is read once, when the world loads. Changing it
mid-session has no effect until a restart, because by then the conversion has already
happened.

---

## Multiplayer

Sprinter verdicts are **not** synced, deliberately. Each client tests the zombies near it
against its own risk, which means the zombie coming at you reflects _your_ zone, _your_
survival time and _your_ moon, rather than whoever happened to see it first.

Speed itself replicates natively, so everyone sees the same thing. If another player has
already made a zombie sprint, your client adopts that verdict rather than second-guessing
it, so a sprinter does not lose its identity when it changes hands.

Sprinter speed needs no syncing either. Where a sprinter lands in the speed range comes
from its network id, not a dice roll, so every client works out the same speed for the
same zombie from the server's settings. The exceptions are right after an admin changes
the settings, and a sprinter standing right on a zone border with different speeds on
each side. In both cases another client can adopt it at a different speed, and it briefly
animates at a different pace than it moves.

Server settings are authoritative. Clients follow them.

---

## Troubleshooting

Set **Debug** to Simple or Extended. It can be changed without a restart, though it takes
up to a minute to apply. Labels are only drawn for admins.

**Simple** labels each zombie within 25 tiles with its current speed (Sprinter, Fast
Shambler or Shambler), coloured the same way as the Extended states below.

**Extended** also logs verbosely to the console, and each label reads:

```
<id> <state> [L<light>] <base>><live> [<speed>%]
```

| Colour | State      | Meaning                            |
| ------ | ---------- | ---------------------------------- |
| grey   | `untested` | Has not entered the test band yet  |
| green  | `no`       | Tested, not a sprinter             |
| yellow | `walk`     | One of ours, not running right now |
| red    | `run`      | One of ours, running               |

`L<light>` only appears in the modes where light decides anything, and is directly
comparable with your Darkness Level. `base>live` is the speed the zombie returns to when
it stops running, then what it is doing now. `<speed>%` is a sprinter's own sprint speed,
once it has been given one.

Global values, the adjusted light, fog, dawn and dusk times, and your current risk, are
in the sensor panel's tooltip.

`PhunSprinters.dumpSettings("check")` in the console prints every setting three ways, for
when a value does not look like what you configured.

---

## Compatibility

- [PhunZones 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252660) for
  per-zone risk. Optional.
- [PhunServer 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3792193021)
  Day/Night, if installed, drives dusk and dawn instead of our own calculation. Optional,
  detected automatically.
- [The Mutants](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056). Each
  mutant type has its own "Ignore" tick box. A ticked type is left entirely to The Mutants:
  never tested, never sped up, never slowed down. An unticked type rolls against risk like
  any other zed, and when it is not chosen (or it is daytime) it keeps the speed The Mutants
  gave it. Leapers and Weepers are ticked by default because The Mutants already makes them
  run; if you untick them they still run whenever we are not making them sprint.
- **Other slower-sprinter mods**, such as Slower Sprinters. They replace the same zombie
  sprint animation files this mod uses for [Sprinter speed](#sprinter-speed), so whichever
  loads last wins and the other's speed setting stops working. Use one or the other.

B42 only. B41 users should stay on
[PhunSprinters 1](https://steamcommunity.com/sharedfiles/filedetails/?id=3532685233).
