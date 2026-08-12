# Deep Contract — Design Notes

## Premise

Rig Abyss-9 is a deep-sea drilling platform 1,800 metres down. The crew signed fixed-term
contracts; the contracts auto-renew, the supply sub only takes rostered personnel, and the
company's position is that nobody is being held against their will. The player is a maintenance
technician who has decided to leave anyway.

The rig replaces the prison of The Escapists without softening the loop: the pressure hull is the
perimeter wall, the roster is the roll call, and the security detail does not need to be cruel to
be an obstacle.

## Vocabulary mapping

| The Escapists | Deep Contract |
| --- | --- |
| Cell | Bunk pod |
| Guard | Security officer, inspection drone |
| Roll call | Shift muster |
| Contraband | Spare parts, cutting torch, nav module, forged papers |
| Job | Welding, sludge clearing, galley duty |
| Gym / library | Conditioning bay / technical terminal / pressure chamber |
| Escape route | Submersible, supply sub, abandoned bore shaft |

## Player stats

| Stat | Raised by | Affects |
| --- | --- | --- |
| Conditioning | Conditioning bay | Move speed, how long a sprint lasts |
| Technical | Technical terminal | Which recipes unlock, job output |
| Pressure tolerance | Pressure chamber | Oxygen bottle duration, which depths are survivable |

## Daily schedule

| Time | Event | Location required |
| --- | --- | --- |
| 06:00 | Wake | — |
| 07:00 | Breakfast | Galley |
| 08:00 | Morning muster | Muster deck |
| 08:30 | Shift start | Assigned job station |
| 12:00 | Lunch | Galley |
| 14:00 | Free period | — |
| 16:00 | Training window | — |
| 18:00 | Dinner | Galley |
| 20:00 | Evening muster | Muster deck |
| 22:00 | Lights out | Bunk pod |

Missing a muster raises suspicion by 25. Suspicion drives shakedown frequency and patrol density.

## Deep-sea mechanics

These are the systems that separate the game from its inspiration.

**Oxygen.** Unpressurised sections run on a bottle. The countdown starts on entry and scales with
pressure tolerance. Reaching zero knocks the player out and wakes them in the infirmary, minus any
contraband they were carrying.

**Compartment pressure.** Some doors only open once the far side is equalised, which takes time
and is audible to anyone nearby. Others need a suit the player does not start with.

**Blackouts.** Power dips at 02:00 and 14:00 for 45 seconds. Lighting and cameras drop, and
officer vision radius shrinks sharply. Most routes are built around exploiting one of these.

## Escape routes

**Submersible.** Recover three drive components, build a cutting torch, breach the hangar door,
and launch. The longest route, and the only one that does not depend on the surface schedule.

**Supply sub.** Steal a uniform, forge a rotation docket, and reach the moon pool during the
resupply window while the manifest is being checked.

**Bore shaft.** Reserved for a later milestone; the abandoned shaft is on the map from the start
as a visible, unusable tease.

## Art direction

- Top-down 3/4 view: floors drawn orthographically, walls and furniture drawn face-on
- 32x32 tiles, 32x48 character sprites, 4 directions x 4 walk frames
- Fixed 16-colour palette: cold blue-greens for the hull, amber for warning lights, one red
  reserved exclusively for alarms and forbidden zones
- 640x360 base viewport, `canvas_items` stretch with `expand`, nearest-neighbour filtering
