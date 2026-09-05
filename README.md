# PhunSprinters 2

A dynamic sprinter system for Project Zomboid B42.

Vanilla gives you a fixed percentage of sprinters, everywhere, forever. PhunSprinters
makes it situational: risk changes with where you are, how long you have survived, the
moon phase, and the light around each zombie.

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

| Term | Where it comes from |
|---|---|
| `base` | The zone's `minSprinterRisk`, falling back to the **Default Risk** setting |
| `moon multiplier` | The **Moon Phase Multiplier** for tonight's phase, divided by 100 |
| `hours factor` | `hours survived / Hours Discount`, capped at 1. Always 1 if Hours Discount is 0 |
| cap | The zone's `maxSprinterRisk` |

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

| Mode | When sprinters run |
|---|---|
| 1. Dusk till dawn | Walk during the day, run once the sun goes down |
| 2. Always | Always run, the way vanilla sprinters do |
| 3. When it is too dark outside | Run at night, and during weather that drops visibility, even in daytime |
| 4. When it is too dark around them | Run whenever the light on their own tile drops below your Darkness Level |

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

## Zone recipes

These need [PhunZones 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252660).
PhunSprinters reads two values off whatever zone the player is standing in:

| Key | Effect |
|---|---|
| `minSprinterRisk` | Replaces Default Risk as the base for this zone |
| `maxSprinterRisk` | Caps the final risk in this zone, after moon and hours are applied |

Both are optional. Leave one unset and the global setting applies.

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
|---|---|
| 0 | 0% |
| 25 | 12.5% |
| 50 | 25% |
| 75 | 37.5% |
| 100 and beyond | 50% |

Set it to `0` to disable the ramp entirely. Hours carry across death, so a player who
dies at hour 90 does not restart the ease-in.

Useful on fresh servers, and for keeping a new player's first night survivable on a
server where the veterans want full risk.

---

## Moon phases

The moon **multiplies** risk. It does not replace it, so a zone with 0 risk stays at 0
however full the moon is.

| Phase | Setting | Default |
|---|---|---|
| New | `MoonPhaseMultiplierNew` | 50 |
| Crescent | `MoonPhaseMultiplierCrescent` | 75 |
| Quarter | `MoonPhaseMultiplierQuarter` | 90 |
| Gibbous | `MoonPhaseMultiplierGibbous` | 100 |
| Full | `MoonPhaseMultiplierFull` | 200 |

Values are percentages: `200` doubles the risk, `50` halves it, `100` leaves it alone.
Waxing and waning phases share a setting, so the eight game phases map onto these five.

With a 20% area risk: a full moon night is 40%, a new moon night is 10%.

Set a phase to `0` and there are no sprinters at all on those nights, which makes new
moons a genuine window to travel in.

---

## Settings reference

| Setting | Default | What it does |
|---|---|---|
| Mode | Dusk till dawn | When sprinters run. See above |
| Slow in light | off | Light drops a running sprinter back to a walk |
| Darkness Level | 74 | The 0-100 light level sprinting is gated on |
| Default Risk | 1 | Base sprinter chance where no zone overrides it |
| Hours Discount | 0 | Hours of survival before full risk applies. 0 disables |
| Moon Phase Multipliers | 50-200 | Per-phase risk multipliers |
| Replace vanilla sprinters with | Fast shamblers | What the game's own sprinters become. See below |
| Percentage Sprinters Volume | 10 | Volume of the sprinter screech. 0 silences it |
| Sprinting Change Volume | 15 | Volume of the sound when conditions change. 0 silences it |
| Decorate Sprinters | on | Dress sprinters up around the holidays, if the relevant mods are installed |
| Always Show UI | on | Show the sensor panel without needing the wearable |
| Lootable Sensor | off | Put the military sensor into loot, for when the UI is not always shown |
| UI Layout | Vertical | Sensor panel orientation |
| Min / Max Distance | 14 / 35 | The band, in tiles, where zombies are tested |
| Max Queue | 20 | Zombies evaluated per tick. Lower it if you see stutter in hordes |
| Debug | off | Verbose logging and the per-zombie overlay |

---

## Using this with the vanilla Zombie Speed setting

PhunSprinters has to own who runs, so it takes vanilla's sprinters off the board when the
world loads.

| Your Zombie Speed | What happens |
|---|---|
| Sprinters | Converted to whatever **Replace vanilla sprinters with** says. PhunSprinters decides which of them run from there |
| Random | Only the sprinter share is removed. Your fast shambler and shambler mix is untouched |
| Fast Shamblers | Nothing changes. There were no vanilla sprinters to replace |
| Shamblers | Nothing changes |

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
against its own risk, which means the zombie coming at you reflects *your* zone, *your*
survival time and *your* moon, rather than whoever happened to see it first.

Speed itself replicates natively, so everyone sees the same thing. If another player has
already made a zombie sprint, your client adopts that verdict rather than second-guessing
it, so a sprinter does not lose its identity when it changes hands.

Server settings are authoritative. Clients follow them.

---

## Troubleshooting

Turn **Debug** on. It can be toggled without a restart, though it takes up to a minute to
apply.

Each zombie within 25 tiles gets a label:

```
<id> <state> [L<light>] <base>><live>
```

| Colour | State | Meaning |
|---|---|---|
| grey | `untested` | Has not entered the test band yet |
| green | `no` | Tested, not a sprinter |
| yellow | `walk` | One of ours, not running right now |
| red | `run` | One of ours, running |

`L<light>` only appears in the modes where light decides anything, and is directly
comparable with your Darkness Level. `base>live` is the speed the zombie returns to when
it stops running, then what it is doing now.

Global values, the adjusted light, fog, dawn and dusk times, and your current risk, are
in the sensor panel's tooltip.

`PhunSprinters.dumpSettings("check")` in the console prints every setting three ways, for
when a value does not look like what you configured.

---

## Compatibility

- [PhunZones 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252660) for
  per-zone risk. Optional.
- PhunServer 2 Day/Night, if installed, drives dusk and dawn instead of our own
  calculation. Optional, detected automatically.
- **TheySEEyou**: sprinter screams are suppressed when it is active, to avoid two mods
  shouting at once.

B42 only. B41 users should stay on
[PhunSprinters 1](https://steamcommunity.com/sharedfiles/filedetails/?id=3532685233).
