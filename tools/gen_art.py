#!/usr/bin/env python3
"""Generate every sprite in the game from code.

Nothing here comes from an asset pack, so the project owns its art outright and
has no attribution obligations at submission time. Output is deterministic: the
same script always produces byte-identical PNGs, which lets CI regenerate and
diff to prove the committed art matches the source.

    python3 tools/gen_art.py            # write PNGs into assets/generated/
    python3 tools/gen_art.py --check    # fail if committed PNGs are stale
"""

from __future__ import annotations

import argparse
import io
import random
import sys
from pathlib import Path
from typing import Callable

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from palette import (  # noqa: E402
    ABYSS,
    ALARM,
    AMBER,
    AMBER_DARK,
    BONE,
    HULL,
    HULL_DARK,
    HULL_HIGHLIGHT,
    HULL_LIGHT,
    HULL_SHADOW,
    INK,
    PALETTE,
    RUST,
    STEEL,
    STEEL_DARK,
    STEEL_LIGHT,
    TRANSPARENT,
    WHITE,
    Surface,
)

TILE = 32
ACTOR_W = 32
ACTOR_H = 48
ICON = 16
ATLAS_COLUMNS = 8

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_ROOT = REPO_ROOT / "assets" / "generated"


# --------------------------------------------------------------------------
# Terrain tiles
# --------------------------------------------------------------------------


def floor_grate(s: Surface) -> None:
    """Load-bearing walkway grating: the default surface across the rig."""
    s.fill(HULL_SHADOW)
    for cy in range(0, TILE, 8):
        for cx in range(0, TILE, 8):
            s.rect(cx + 1, cy + 1, 6, 6, HULL_DARK)
            s.hline(cx + 1, cy + 1, 6, HULL)
            s.set(cx + 1, cy + 1, HULL_LIGHT)
            s.set(cx + 6, cy + 6, ABYSS)


def floor_tile(s: Surface) -> None:
    """Bunk and galley flooring: cleaner than grating, still not bright.

    Kept a shade below the walls on purpose. When floor and wall sit at the
    same value the room reads as one flat field and the player loses track of
    where the walls are.
    """
    s.fill(INK)
    for cy in (0, 16):
        for cx in (0, 16):
            s.rect(cx + 1, cy + 1, 14, 14, STEEL_DARK)
            s.hline(cx + 1, cy + 1, 13, STEEL)
            s.vline(cx + 1, cy + 1, 13, STEEL)
            s.set(cx + 14, cy + 14, ABYSS)


def floor_concrete(s: Surface) -> None:
    """Machinery deck: poured, stained, deliberately noisy."""
    rng = random.Random(0x5EA_F100)
    s.fill(HULL_SHADOW)
    for _ in range(90):
        s.set(rng.randrange(TILE), rng.randrange(TILE), HULL_DARK)
    for _ in range(24):
        s.set(rng.randrange(TILE), rng.randrange(TILE), HULL)
    for _ in range(6):
        x, y = rng.randrange(TILE - 3), rng.randrange(TILE - 1)
        s.hline(x, y, 3, RUST)


def floor_wet(s: Surface) -> None:
    """Moon-pool decking, permanently slick and catching the overhead lamps."""
    rng = random.Random(0x5EA_F101)
    s.fill(HULL_DARK)
    for y in range(0, TILE, 4):
        s.hline(0, y, TILE, HULL_SHADOW)
    for _ in range(18):
        x, y = rng.randrange(TILE - 4), rng.randrange(TILE)
        s.hline(x, y, rng.randint(2, 4), HULL)
    for _ in range(7):
        s.set(rng.randrange(TILE), rng.randrange(TILE), HULL_LIGHT)


def floor_restricted(s: Surface) -> None:
    """Hazard-striped deck marking a zone the player is not cleared for."""
    s.fill(HULL_SHADOW)
    for y in range(TILE):
        for x in range(TILE):
            band = (x + y) % 16
            if band < 8:
                s.set(x, y, AMBER_DARK if (x + y) % 2 else AMBER)
            else:
                s.set(x, y, INK)
    for y in range(0, TILE, 8):
        s.hline(0, y, TILE, HULL_SHADOW)


def _hull_wall_base(s: Surface) -> None:
    """Shared body for wall tiles: lit cap on top, shaded face below.

    The 10px cap is what sells the 3/4 view; without it walls read as flat
    floor paint from directly above.
    """
    s.rect(0, 0, TILE, 10, STEEL_LIGHT)
    s.hline(0, 0, TILE, BONE)
    s.hline(0, 1, TILE, BONE)
    s.hline(0, 8, TILE, STEEL)
    s.hline(0, 9, TILE, STEEL_DARK)

    s.rect(0, 10, TILE, TILE - 10, HULL_DARK)
    s.hline(0, 10, TILE, HULL)
    s.hline(0, TILE - 1, TILE, HULL_SHADOW)
    s.vline(0, 10, TILE - 10, HULL_SHADOW)
    s.vline(16, 10, TILE - 10, HULL_SHADOW)
    for y in (15, 27):
        for x in (4, 12, 20, 28):
            s.set(x, y, STEEL)
            s.set(x, y + 1, HULL_SHADOW)


def wall_hull(s: Surface) -> None:
    _hull_wall_base(s)


def wall_hull_top(s: Surface) -> None:
    """Interior of a thick wall block, seen purely from above."""
    s.fill(STEEL_LIGHT)
    for y in range(0, TILE, 8):
        s.hline(0, y, TILE, STEEL)
    for x in range(0, TILE, 16):
        s.vline(x, 0, TILE, STEEL)
    s.hline(0, 0, TILE, BONE)


def wall_window(s: Surface) -> None:
    """Porthole onto the abyss, with something bioluminescent drifting past."""
    _hull_wall_base(s)
    s.ellipse(16, 21, 8, 7, ABYSS)
    s.ring(16, 21, 9, 8, STEEL_LIGHT)
    s.ring(16, 21, 8, 7, STEEL_DARK)
    for x, y in ((12, 19), (20, 23), (17, 17)):
        s.set(x, y, HULL_LIGHT)
    s.set(13, 20, HULL_HIGHLIGHT)


def wall_alarm(s: Surface) -> None:
    """Wall section carrying an alarm strobe, used to fence restricted areas."""
    _hull_wall_base(s)
    s.rect(12, 14, 8, 6, STEEL_DARK)
    s.rect(13, 15, 6, 4, ALARM)
    s.hline(13, 15, 6, AMBER)
    s.rect(11, 20, 10, 1, STEEL_DARK)


def door_closed(s: Surface) -> None:
    """Powered sliding door, shut. The amber lamp says it still has power."""
    s.rect(0, 0, TILE, TILE, INK)
    s.rect(0, 0, TILE, 4, STEEL_DARK)
    s.hline(0, 1, TILE, STEEL)
    s.rect(0, TILE - 3, TILE, 3, STEEL_DARK)

    for left, right in ((1, 15), (17, 31),):
        s.rect(left, 4, right - left, TILE - 7, STEEL)
        s.frame(left, 4, right - left, TILE - 7, STEEL_DARK)
        s.rect(left + 2, 8, right - left - 4, 3, HULL_DARK)
        s.rect(left + 2, 20, right - left - 4, 3, HULL_DARK)

    s.vline(15, 4, TILE - 7, INK)
    s.vline(16, 4, TILE - 7, INK)
    s.rect(12, 14, 3, 5, STEEL_DARK)
    s.rect(17, 14, 3, 5, STEEL_DARK)
    s.rect(13, 1, 6, 2, AMBER)


def door_open(s: Surface) -> None:
    """Same frame with both leaves retracted into the jambs."""
    floor_grate(s)
    s.rect(0, 0, TILE, 4, STEEL_DARK)
    s.hline(0, 1, TILE, STEEL)
    s.rect(0, TILE - 3, TILE, 3, STEEL_DARK)
    for x in (0, TILE - 6):
        s.rect(x, 4, 6, TILE - 7, STEEL)
        s.frame(x, 4, 6, TILE - 7, STEEL_DARK)
        s.rect(x + 1, 10, 4, 12, HULL_DARK)
    s.rect(13, 1, 6, 2, HULL_HIGHLIGHT)


def hatch_closed(s: Surface) -> None:
    """Pressure hatch: only opens once the far compartment is equalised."""
    s.rect(0, 0, TILE, TILE, STEEL_DARK)
    s.ellipse(16, 16, 14, 14, STEEL)
    s.ring(16, 16, 14, 14, STEEL_DARK)
    s.ring(16, 16, 9, 9, STEEL_LIGHT)
    for dx, dy in ((0, -7), (0, 7), (-7, 0), (7, 0), (-5, -5), (5, 5), (-5, 5), (5, -5)):
        s.set(16 + dx, 16 + dy, STEEL_DARK)
        s.set(16 + dx, 16 + dy - 1, STEEL_DARK)
    s.ellipse(16, 16, 3, 3, AMBER)
    s.ellipse(16, 16, 2, 2, AMBER_DARK)


def hatch_open(s: Surface) -> None:
    s.rect(0, 0, TILE, TILE, STEEL_DARK)
    s.ellipse(16, 16, 13, 13, ABYSS)
    s.ring(16, 16, 14, 14, STEEL)
    s.ring(16, 16, 12, 12, HULL_SHADOW)
    s.rect(2, 12, 5, 8, STEEL_LIGHT)


def vent(s: Surface) -> None:
    s.rect(0, 0, TILE, TILE, HULL_SHADOW)
    s.rect(3, 3, TILE - 6, TILE - 6, INK)
    for y in range(6, 27, 5):
        s.hline(5, y, TILE - 10, STEEL)
        s.hline(5, y + 1, TILE - 10, STEEL_DARK)
    s.frame(3, 3, TILE - 6, TILE - 6, STEEL_DARK)


def _pipe_body(s: Surface, horizontal: bool) -> None:
    if horizontal:
        s.rect(0, 10, TILE, 12, HULL_DARK)
        s.hline(0, 10, TILE, HULL_SHADOW)
        s.hline(0, 13, TILE, HULL)
        s.hline(0, 14, TILE, HULL_LIGHT)
        s.hline(0, 21, TILE, HULL_SHADOW)
        for x in (6, 25):
            s.vline(x, 9, 14, STEEL)
            s.vline(x + 1, 9, 14, STEEL_DARK)
    else:
        s.rect(10, 0, 12, TILE, HULL_DARK)
        s.vline(10, 0, TILE, HULL_SHADOW)
        s.vline(13, 0, TILE, HULL)
        s.vline(14, 0, TILE, HULL_LIGHT)
        s.vline(21, 0, TILE, HULL_SHADOW)
        for y in (6, 25):
            s.hline(9, y, 14, STEEL)
            s.hline(9, y + 1, 14, STEEL_DARK)


def pipe_horizontal(s: Surface) -> None:
    """Pipes are props, not terrain, so they leave the deck showing around them."""
    _pipe_body(s, horizontal=True)


def pipe_vertical(s: Surface) -> None:
    _pipe_body(s, horizontal=False)


def moonpool(s: Surface) -> None:
    """Open water inside the rig; the supply sub surfaces here.

    Kept clearly brighter than the abyss outside the portholes so the player
    reads it as a surface they can stand beside, not a hole they fall into.
    """
    rng = random.Random(0x5EA_F102)
    s.fill(HULL)
    for y in range(0, TILE, 3):
        length = rng.randint(8, 20)
        x = rng.randrange(TILE - length)
        s.hline(x, y, length, HULL_DARK)
        s.hline(x + 1, y + 1, max(length - 4, 2), HULL_SHADOW)
    for _ in range(14):
        x, y = rng.randrange(TILE - 5), rng.randrange(TILE)
        s.hline(x, y, rng.randint(3, 5), HULL_LIGHT)
    for _ in range(6):
        s.set(rng.randrange(TILE), rng.randrange(TILE), HULL_HIGHLIGHT)


TERRAIN_TILES: tuple[tuple[str, Callable[[Surface], None]], ...] = (
    ("floor_grate", floor_grate),
    ("floor_tile", floor_tile),
    ("floor_concrete", floor_concrete),
    ("floor_wet", floor_wet),
    ("floor_restricted", floor_restricted),
    ("wall_hull", wall_hull),
    ("wall_hull_top", wall_hull_top),
    ("wall_window", wall_window),
    ("wall_alarm", wall_alarm),
    ("door_closed", door_closed),
    ("door_open", door_open),
    ("hatch_closed", hatch_closed),
    ("hatch_open", hatch_open),
    ("vent", vent),
    ("moonpool", moonpool),
)


# --------------------------------------------------------------------------
# Props
# --------------------------------------------------------------------------


def bunk(s: Surface) -> None:
    s.rect(4, 2, 24, 28, STEEL_DARK)
    s.rect(5, 3, 22, 26, STEEL)
    s.rect(6, 4, 20, 9, BONE)
    s.hline(6, 4, 20, WHITE)
    s.rect(6, 13, 20, 15, HULL)
    s.hline(6, 13, 20, HULL_LIGHT)
    s.hline(6, 14, 20, HULL_LIGHT)
    for y in range(17, 28, 4):
        s.hline(7, y, 18, HULL_DARK)
    s.frame(4, 2, 24, 28, STEEL_DARK)
    s.hline(4, 30, 24, HULL_SHADOW)


def locker(s: Surface) -> None:
    s.rect(3, 1, 26, 30, STEEL_DARK)
    s.rect(4, 2, 24, 28, STEEL)
    s.vline(15, 2, 28, STEEL_DARK)
    s.vline(16, 2, 28, STEEL_LIGHT)
    for y in (6, 8, 10):
        s.hline(7, y, 6, INK)
        s.hline(19, y, 6, INK)
    s.rect(13, 16, 2, 5, AMBER)
    s.rect(17, 16, 2, 5, AMBER)
    s.hline(3, 31, 26, HULL_SHADOW)


def workbench(s: Surface) -> None:
    s.rect(1, 8, 30, 14, STEEL_LIGHT)
    s.hline(1, 8, 30, WHITE)
    s.rect(1, 22, 30, 3, STEEL_DARK)
    s.rect(3, 25, 4, 6, STEEL_DARK)
    s.rect(25, 25, 4, 6, STEEL_DARK)
    # Tools left out on the surface, so the station reads as usable at a glance.
    s.rect(5, 12, 9, 2, STEEL_DARK)
    s.rect(4, 11, 3, 4, STEEL_DARK)
    s.rect(18, 11, 6, 6, AMBER)
    s.rect(19, 12, 4, 4, AMBER_DARK)
    s.rect(26, 13, 3, 6, RUST)


def console(s: Surface) -> None:
    s.rect(2, 4, 28, 20, STEEL_DARK)
    s.rect(4, 6, 24, 12, ABYSS)
    rng = random.Random(0x5EA_C0DE)
    for row in range(3):
        y = 8 + row * 3
        x = 6
        while x < 26:
            length = rng.randint(2, 5)
            s.hline(x, y, min(length, 26 - x), HULL_LIGHT)
            x += length + rng.randint(1, 3)
    s.rect(4, 19, 24, 4, STEEL)
    for i, colour in enumerate((AMBER, HULL_LIGHT, ALARM, HULL_LIGHT)):
        s.rect(6 + i * 6, 20, 3, 2, colour)
    s.rect(2, 24, 28, 6, STEEL_DARK)
    s.hline(2, 24, 28, STEEL)


def crate(s: Surface) -> None:
    """Supply crate: plain steel with one hazard band, not a wall of chevrons."""
    s.rect(4, 6, 24, 24, STEEL_DARK)
    s.rect(5, 7, 22, 22, STEEL)
    s.frame(5, 7, 22, 22, STEEL_LIGHT)
    s.hline(5, 12, 22, STEEL_DARK)
    s.hline(5, 24, 22, STEEL_DARK)

    for y in range(14, 21):
        for x in range(6, 26):
            s.set(x, y, AMBER if (x - y) % 8 < 4 else INK)
    s.hline(6, 14, 20, AMBER_DARK)
    s.hline(6, 20, 20, AMBER_DARK)

    s.rect(12, 8, 8, 3, STEEL_DARK)
    s.rect(13, 9, 6, 1, STEEL_LIGHT)
    s.hline(4, 30, 24, HULL_SHADOW)


def table(s: Surface) -> None:
    s.rect(2, 8, 28, 14, STEEL)
    s.hline(2, 8, 28, STEEL_LIGHT)
    s.hline(2, 21, 28, STEEL_DARK)
    s.rect(4, 22, 3, 8, STEEL_DARK)
    s.rect(25, 22, 3, 8, STEEL_DARK)
    s.rect(12, 11, 8, 8, BONE)
    s.rect(13, 12, 6, 6, AMBER)


def chair(s: Surface) -> None:
    s.rect(8, 4, 16, 12, STEEL_DARK)
    s.rect(9, 5, 14, 10, HULL_DARK)
    s.rect(7, 16, 18, 8, STEEL)
    s.hline(7, 16, 18, STEEL_LIGHT)
    s.rect(9, 24, 3, 6, STEEL_DARK)
    s.rect(20, 24, 3, 6, STEEL_DARK)


def lamp(s: Surface) -> None:
    """Ceiling lamp fixture; the blackout system kills these on a timer."""
    s.rect(11, 1, 10, 5, STEEL_DARK)
    s.rect(12, 2, 8, 3, STEEL)
    s.rect(3, 6, 26, 16, STEEL_DARK)
    s.rect(4, 7, 24, 14, AMBER_DARK)
    s.rect(5, 8, 22, 11, AMBER)
    s.rect(7, 9, 18, 7, WHITE)
    s.hline(4, 21, 24, HULL_SHADOW)
    # Spill onto the deck below the fixture.
    s.checker(2, 22, 28, 4, AMBER_DARK)
    s.checker(6, 26, 20, 3, AMBER_DARK, phase=1)


def conditioning_rig(s: Surface) -> None:
    """Squat rack: uprights, a loaded bar, and a bench the player lies on."""
    s.rect(3, 2, 4, 26, STEEL_DARK)
    s.rect(4, 3, 2, 24, STEEL)
    s.rect(25, 2, 4, 26, STEEL_DARK)
    s.rect(26, 3, 2, 24, STEEL)
    for y in (8, 13, 18):
        s.rect(2, y, 6, 2, STEEL_LIGHT)
        s.rect(24, y, 6, 2, STEEL_LIGHT)

    s.rect(1, 10, 30, 3, STEEL_DARK)
    s.rect(1, 11, 30, 1, STEEL_LIGHT)
    for x in (0, 3, 26, 29):
        s.rect(x, 7, 3, 9, INK)
        s.rect(x, 8, 3, 7, STEEL_DARK)

    s.rect(9, 20, 14, 7, HULL_DARK)
    s.rect(10, 21, 12, 5, HULL)
    s.hline(10, 21, 12, HULL_LIGHT)
    s.rect(14, 27, 4, 4, STEEL_DARK)
    s.hline(9, 30, 14, HULL_SHADOW)


def technical_terminal(s: Surface) -> None:
    s.rect(5, 2, 22, 18, STEEL_DARK)
    s.rect(7, 4, 18, 12, ABYSS)
    rng = random.Random(0x5EA_7E12)
    for row in range(4):
        y = 5 + row * 3
        x = 8
        while x < 24:
            length = rng.randint(2, 6)
            s.hline(x, y, min(length, 24 - x), HULL_HIGHLIGHT if row == 0 else HULL_LIGHT)
            x += length + rng.randint(1, 3)
    s.rect(5, 20, 22, 4, STEEL)
    s.rect(8, 24, 16, 6, STEEL_DARK)
    for i in range(5):
        s.rect(10 + i * 3, 26, 2, 2, STEEL_LIGHT)


def pressure_chamber(s: Surface) -> None:
    s.rect(4, 2, 24, 28, STEEL_DARK)
    s.rect(5, 3, 22, 26, STEEL)
    s.ellipse(16, 14, 8, 8, ABYSS)
    s.ring(16, 14, 9, 9, STEEL_LIGHT)
    s.ellipse(16, 14, 3, 5, HULL)
    s.rect(9, 24, 14, 4, STEEL_DARK)
    s.rect(10, 25, 4, 2, AMBER)
    s.rect(18, 25, 4, 2, HULL_LIGHT)
    s.hline(4, 30, 24, HULL_SHADOW)


def market_crate(s: Surface) -> None:
    """The rig's unofficial trader works out of a stack of these."""
    s.rect(2, 12, 28, 18, RUST)
    s.frame(2, 12, 28, 18, INK)
    s.rect(4, 14, 24, 6, AMBER_DARK)
    s.rect(4, 21, 11, 7, STEEL_DARK)
    s.rect(17, 21, 11, 7, STEEL_DARK)
    s.rect(5, 22, 9, 5, STEEL)
    s.rect(18, 22, 9, 5, STEEL)
    s.rect(9, 4, 14, 8, BONE)
    s.hline(9, 4, 14, WHITE)
    for x in range(11, 21, 3):
        s.vline(x, 6, 4, INK)


def drive_component(s: Surface) -> None:
    """A submersible drive part lying loose; one of three the player must find."""
    s.ellipse(16, 18, 11, 9, STEEL_DARK)
    s.ellipse(16, 18, 9, 7, STEEL)
    s.ellipse(16, 18, 4, 3, HULL_DARK)
    for dx, dy in ((-8, -3), (8, -3), (-8, 3), (8, 3), (0, -7), (0, 7)):
        s.rect(16 + dx - 1, 18 + dy - 1, 3, 3, STEEL_LIGHT)
    s.rect(13, 8, 6, 4, AMBER)
    s.hline(13, 8, 6, AMBER_DARK)
    s.hline(6, 27, 20, HULL_SHADOW)


def hangar_door(s: Surface) -> None:
    """Blocks the submersible route until it is cut open."""
    s.rect(0, 0, TILE, TILE, INK)
    for y in range(TILE):
        for x in range(TILE):
            if (x - y) % 12 < 6:
                s.set(x, y, AMBER_DARK if (x + y) % 2 else AMBER)
    s.rect(0, 0, TILE, 3, STEEL_DARK)
    s.rect(0, TILE - 3, TILE, 3, STEEL_DARK)
    s.rect(2, 12, 28, 8, STEEL_DARK)
    s.rect(3, 13, 26, 6, STEEL)
    s.rect(12, 14, 8, 4, ALARM)


def sub_dock(s: Surface) -> None:
    """Boarding gantry at the moon pool: where the supply sub ties up."""
    s.rect(2, 4, 28, 4, STEEL_DARK)
    s.rect(3, 5, 26, 2, STEEL_LIGHT)
    s.rect(2, 24, 28, 4, STEEL_DARK)
    s.rect(3, 25, 26, 2, STEEL)

    for x in range(4, 28, 5):
        s.rect(x, 8, 3, 16, STEEL)
        s.rect(x, 8, 3, 1, STEEL_LIGHT)
        s.rect(x, 23, 3, 1, HULL_SHADOW)

    for x in (1, 30):
        s.rect(x, 2, 2, 26, STEEL_DARK)
        s.rect(x, 2, 2, 2, AMBER)
    s.rect(13, 0, 6, 3, AMBER)
    s.rect(14, 1, 4, 1, INK)
    s.hline(2, 28, 28, HULL_SHADOW)


PROP_TILES: tuple[tuple[str, Callable[[Surface], None]], ...] = (
    ("bunk", bunk),
    ("locker", locker),
    ("workbench", workbench),
    ("console", console),
    ("crate", crate),
    ("table", table),
    ("chair", chair),
    ("lamp", lamp),
    ("conditioning_rig", conditioning_rig),
    ("technical_terminal", technical_terminal),
    ("pressure_chamber", pressure_chamber),
    ("market_crate", market_crate),
    ("drive_component", drive_component),
    ("hangar_door", hangar_door),
    ("pipe_horizontal", pipe_horizontal),
    ("pipe_vertical", pipe_vertical),
    ("sub_dock", sub_dock),
)


# --------------------------------------------------------------------------
# Characters
# --------------------------------------------------------------------------

DIRECTIONS = ("down", "left", "right", "up")


class CharacterPalette:
    def __init__(
        self,
        skin: int,
        hair: int,
        suit: int,
        suit_dark: int,
        trousers: int,
        boots: int,
        accent: int,
    ) -> None:
        self.skin = skin
        self.hair = hair
        self.suit = suit
        self.suit_dark = suit_dark
        self.trousers = trousers
        self.boots = boots
        self.accent = accent


# Orange coveralls against navy security uniforms: two silhouettes the player
# can tell apart at a glance even when the sprite is 16 pixels wide.
WORKER = CharacterPalette(
    skin=BONE, hair=RUST, suit=AMBER, suit_dark=AMBER_DARK,
    trousers=HULL_DARK, boots=INK, accent=WHITE,
)
# Officer uniforms deliberately avoid HULL_DARK: that is the deck colour, and a
# guard that blends into the floor is a guard the player never sees coming.
OFFICER = CharacterPalette(
    skin=BONE, hair=INK, suit=STEEL_DARK, suit_dark=INK,
    trousers=ABYSS, boots=INK, accent=AMBER,
)
TRADER = CharacterPalette(
    skin=BONE, hair=STEEL_DARK, suit=RUST, suit_dark=INK,
    trousers=STEEL_DARK, boots=INK, accent=AMBER,
)


def _rounded_head(s: Surface, left: int, top: int, width: int, colour: int) -> None:
    """A 15px-tall head block with the corners shaved off.

    Deliberately boxy rather than round: at this size an ellipse loses its
    corners to anti-alias-free rasterising and reads as a blob.
    """
    s.rect(left, top + 1, width, 13, colour)
    s.hline(left + 1, top, width - 2, colour)
    s.hline(left + 1, top + 14, width - 2, colour)


def _draw_head_facing(s: Surface, cx: int, top: int, pal: CharacterPalette) -> None:
    """Head seen from the front. No mouth — eyes alone carry it at this scale."""
    _rounded_head(s, cx - 6, top, 12, pal.skin)
    s.rect(cx - 6, top + 1, 12, 5, pal.hair)
    s.hline(cx - 5, top, 10, pal.hair)
    s.rect(cx - 6, top + 6, 2, 3, pal.hair)
    s.rect(cx + 4, top + 6, 2, 3, pal.hair)
    s.rect(cx - 4, top + 8, 2, 3, INK)
    s.rect(cx + 2, top + 8, 2, 3, INK)


def _draw_head_away(s: Surface, cx: int, top: int, pal: CharacterPalette) -> None:
    """Head seen from behind: all hair, with a sliver of neck below it."""
    _rounded_head(s, cx - 6, top, 12, pal.hair)
    s.rect(cx - 2, top + 13, 4, 2, pal.skin)


def _draw_head_profile(s: Surface, cx: int, top: int, pal: CharacterPalette) -> None:
    """Head in right-facing profile: one eye, hair swept back, hint of a nose."""
    _rounded_head(s, cx - 4, top, 11, pal.skin)
    s.rect(cx - 4, top + 1, 11, 5, pal.hair)
    s.hline(cx - 3, top, 9, pal.hair)
    s.rect(cx - 4, top + 6, 3, 5, pal.hair)
    s.rect(cx + 2, top + 8, 2, 3, INK)
    s.set(cx + 7, top + 8, pal.skin)
    s.set(cx + 7, top + 9, pal.skin)


def _draw_body_facing(
    s: Surface, cx: int, top: int, pal: CharacterPalette, swing: int, front: bool
) -> None:
    s.rect(cx - 6, top, 12, 13, pal.suit)
    s.hline(cx - 6, top, 12, pal.suit_dark)
    s.hline(cx - 6, top + 12, 12, pal.suit_dark)

    if front:
        s.vline(cx, top + 1, 11, pal.suit_dark)
        s.rect(cx - 5, top + 3, 3, 3, pal.accent)
    else:
        s.rect(cx - 4, top + 3, 8, 7, pal.suit_dark)

    # Arms swing opposite the legs, which is what makes a 4-frame cycle read as
    # walking rather than sliding.
    for side, offset in ((-1, -swing), (1, swing)):
        arm_x = cx - 8 if side < 0 else cx + 6
        arm_y = top + 2 + offset
        s.rect(arm_x, arm_y, 2, 9, pal.suit)
        s.rect(arm_x, arm_y + 9, 2, 2, pal.skin)


def _draw_body_profile(s: Surface, cx: int, top: int, pal: CharacterPalette, swing: int) -> None:
    """Right-facing torso: narrower, with a single visible arm."""
    s.rect(cx - 4, top, 10, 13, pal.suit)
    s.hline(cx - 4, top, 10, pal.suit_dark)
    s.hline(cx - 4, top + 12, 10, pal.suit_dark)
    s.vline(cx - 4, top, 13, pal.suit_dark)

    arm_y = top + 2 + swing
    s.rect(cx + 4, arm_y, 3, 9, pal.suit)
    s.rect(cx + 4, arm_y + 9, 3, 2, pal.skin)
    s.rect(cx + 3, top + 4, 2, 3, pal.accent)


def _draw_legs_facing(s: Surface, cx: int, top: int, pal: CharacterPalette, swing: int) -> None:
    for x_offset, length in ((-5, 9 + swing), (1, 9 - swing)):
        s.rect(cx + x_offset, top, 4, length, pal.trousers)
        s.rect(cx + x_offset, top + length, 4, 2, pal.boots)


def _draw_legs_profile(s: Surface, cx: int, top: int, pal: CharacterPalette, swing: int) -> None:
    """Legs stride fore and aft rather than side to side when in profile."""
    back_x = cx - 4 - max(swing, 0)
    front_x = cx - 1 + max(-swing, 0)
    for x, length in ((back_x, 9 - abs(swing)), (front_x, 9)):
        s.rect(x, top, 4, length, pal.trousers)
        s.rect(x, top + length, 5, 2, pal.boots)


def draw_character_frame(direction: str, frame: int, pal: CharacterPalette) -> Surface:
    body = Surface(ACTOR_W, ACTOR_H)
    cx = ACTOR_W // 2
    swing = (0, 2, 0, -2)[frame]
    bob = 1 if frame in (1, 3) else 0

    head_top = 6 + bob
    torso_top = 21 + bob
    legs_top = 34 + bob

    if direction in ("left", "right"):
        _draw_legs_profile(body, cx, legs_top, pal, swing)
        _draw_body_profile(body, cx, torso_top, pal, swing)
        _draw_head_profile(body, cx, head_top, pal)
    else:
        _draw_legs_facing(body, cx, legs_top, pal, swing)
        _draw_body_facing(body, cx, torso_top, pal, swing, front=direction == "down")
        if direction == "down":
            _draw_head_facing(body, cx, head_top, pal)
        else:
            _draw_head_away(body, cx, head_top, pal)

    body.outline(INK)
    if direction == "left":
        body = body.flipped_horizontally()

    s = Surface(ACTOR_W, ACTOR_H)
    # Contact shadow goes underneath, so the outline pass above never traces it.
    s.ellipse(cx, 45, 8, 3, HULL_SHADOW)
    s.blit(body, 0, 0)
    return s


def build_character_sheet(pal: CharacterPalette) -> Surface:
    """One row per direction, four frames each: 128x192."""
    sheet = Surface(ACTOR_W * 4, ACTOR_H * 4)
    for row, direction in enumerate(DIRECTIONS):
        for frame in range(4):
            sheet.blit(draw_character_frame(direction, frame, pal), frame * ACTOR_W, row * ACTOR_H)
    return sheet


# --------------------------------------------------------------------------
# UI icons
# --------------------------------------------------------------------------


def icon_oxygen(s: Surface) -> None:
    s.rect(5, 3, 6, 12, HULL)
    s.hline(5, 3, 6, HULL_LIGHT)
    s.rect(6, 1, 4, 2, STEEL)
    s.rect(5, 14, 6, 1, HULL_SHADOW)
    s.vline(6, 5, 8, HULL_HIGHLIGHT)


def icon_wrench(s: Surface) -> None:
    s.rect(4, 1, 8, 5, STEEL_LIGHT)
    s.rect(6, 1, 4, 3, TRANSPARENT)
    s.rect(6, 6, 4, 6, STEEL_LIGHT)
    s.vline(6, 6, 6, STEEL)
    s.rect(5, 12, 6, 3, STEEL_DARK)
    s.hline(5, 12, 6, STEEL)


def icon_torch(s: Surface) -> None:
    s.rect(5, 9, 6, 6, STEEL_DARK)
    s.rect(6, 10, 2, 4, STEEL)
    s.rect(9, 12, 4, 2, STEEL_DARK)
    s.rect(7, 5, 3, 5, STEEL)
    s.rect(7, 3, 3, 2, STEEL_LIGHT)
    s.ellipse(8, 2, 2, 3, ALARM)
    s.ellipse(8, 2, 1, 2, AMBER)
    s.set(8, 1, WHITE)


def icon_component(s: Surface) -> None:
    s.ellipse(8, 8, 6, 6, STEEL)
    s.ring(8, 8, 6, 6, STEEL_DARK)
    s.ellipse(8, 8, 2, 2, HULL_DARK)
    for dx, dy in ((0, -6), (0, 6), (-6, 0), (6, 0)):
        s.set(8 + dx, 8 + dy, STEEL_LIGHT)


def icon_papers(s: Surface) -> None:
    s.rect(3, 2, 10, 12, BONE)
    s.frame(3, 2, 10, 12, STEEL_DARK)
    for y in range(4, 12, 2):
        s.hline(5, y, 6, INK)
    s.rect(9, 10, 4, 3, ALARM)


def icon_keycard(s: Surface) -> None:
    s.rect(2, 5, 12, 7, STEEL)
    s.frame(2, 5, 12, 7, STEEL_DARK)
    s.rect(3, 6, 4, 3, AMBER)
    s.hline(3, 10, 10, HULL_DARK)


def icon_ration(s: Surface) -> None:
    s.rect(4, 3, 8, 10, STEEL)
    s.hline(4, 3, 8, STEEL_LIGHT)
    s.hline(4, 12, 8, STEEL_DARK)
    s.rect(5, 6, 6, 4, RUST)
    s.hline(5, 6, 6, AMBER)


def icon_credit(s: Surface) -> None:
    s.ellipse(8, 8, 6, 6, AMBER_DARK)
    s.ellipse(8, 8, 5, 5, AMBER)
    s.ring(8, 8, 5, 5, AMBER_DARK)
    s.vline(8, 4, 8, AMBER_DARK)
    s.hline(6, 6, 5, AMBER_DARK)
    s.hline(6, 10, 5, AMBER_DARK)


def icon_suspicion(s: Surface) -> None:
    s.ellipse(8, 8, 7, 4, BONE)
    s.ring(8, 8, 7, 4, STEEL_DARK)
    s.ellipse(8, 8, 3, 3, HULL_DARK)
    s.ellipse(8, 8, 1, 1, INK)
    s.set(6, 6, WHITE)


def icon_uniform(s: Surface) -> None:
    # Matches the officer palette exactly: this is a stolen security uniform.
    s.rect(4, 3, 8, 11, STEEL_DARK)
    s.rect(2, 3, 2, 5, STEEL_DARK)
    s.rect(12, 3, 2, 5, STEEL_DARK)
    s.rect(6, 2, 4, 3, BONE)
    s.rect(5, 7, 2, 2, AMBER)
    s.vline(8, 5, 8, INK)
    s.hline(4, 13, 8, INK)


def icon_alert(s: Surface) -> None:
    for y in range(3, 14):
        half = (y - 3) // 2 + 1
        s.hline(8 - half, y, half * 2, ALARM)
    s.vline(8, 6, 4, INK)
    s.set(8, 11, INK)


ICONS: tuple[tuple[str, Callable[[Surface], None]], ...] = (
    ("oxygen", icon_oxygen),
    ("wrench", icon_wrench),
    ("torch", icon_torch),
    ("component", icon_component),
    ("papers", icon_papers),
    ("keycard", icon_keycard),
    ("ration", icon_ration),
    ("credit", icon_credit),
    ("suspicion", icon_suspicion),
    ("uniform", icon_uniform),
    ("alert", icon_alert),
)


# --------------------------------------------------------------------------
# App icon
# --------------------------------------------------------------------------


def build_app_icon() -> Surface:
    """Drawn at 64x64 and scaled 16x, so the store icon stays honestly pixelated.

    A porthole with a worker behind it: readable at 60pt, and it states the
    setting without needing the title.
    """
    size = 64
    s = Surface(size, size)
    for y in range(size):
        band = y * 4 // size
        s.hline(0, y, size, (HULL_SHADOW, HULL_DARK, ABYSS, ABYSS)[band])

    rng = random.Random(0x5EA_1C0E)
    for _ in range(70):
        x, y = rng.randrange(size), rng.randrange(size)
        s.set(x, y, HULL_DARK if y > size // 2 else HULL)

    s.ellipse(32, 32, 25, 25, STEEL_DARK)
    s.ellipse(32, 32, 23, 23, STEEL)
    s.ring(32, 32, 23, 23, STEEL_LIGHT)
    s.ellipse(32, 32, 20, 20, ABYSS)
    s.ellipse(32, 36, 20, 16, HULL_SHADOW)

    for dx, dy in ((-16, -16), (16, -16), (-16, 16), (16, 16)):
        s.ellipse(32 + dx, 32 + dy, 2, 2, STEEL_LIGHT)

    worker = draw_character_frame("down", 0, WORKER)
    for y in range(ACTOR_H):
        for x in range(ACTOR_W):
            colour = worker.get(x, y)
            if colour in (TRANSPARENT, HULL_SHADOW):
                continue
            px, py = 32 - ACTOR_W // 2 + x, 20 + y
            nx = (px + 0.5 - 32) / 20.0
            ny = (py + 0.5 - 32) / 20.0
            if nx * nx + ny * ny <= 1.0:
                s.set(px, py, colour)

    for cx, cy, r in ((46, 22, 2), (50, 16, 1), (43, 14, 1)):
        s.ellipse(cx, cy, r, r, HULL_HIGHLIGHT)

    return s


# --------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------


def build_atlas(entries: tuple[tuple[str, Callable[[Surface], None]], ...]) -> Surface:
    rows = (len(entries) + ATLAS_COLUMNS - 1) // ATLAS_COLUMNS
    atlas = Surface(ATLAS_COLUMNS * TILE, rows * TILE)
    for index, (_name, draw) in enumerate(entries):
        tile = Surface(TILE, TILE)
        draw(tile)
        atlas.blit(tile, (index % ATLAS_COLUMNS) * TILE, (index // ATLAS_COLUMNS) * TILE)
    return atlas


def build_icon_atlas() -> Surface:
    columns = 8
    rows = (len(ICONS) + columns - 1) // columns
    atlas = Surface(columns * ICON, rows * ICON)
    for index, (_name, draw) in enumerate(ICONS):
        icon = Surface(ICON, ICON)
        draw(icon)
        atlas.blit(icon, (index % columns) * ICON, (index // columns) * ICON)
    return atlas


def _png_bytes(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    # Strip timestamps and other volatile chunks so reruns are byte-identical.
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def _write(path: Path, image: Image.Image, check_only: bool) -> bool:
    data = _png_bytes(image)
    if check_only:
        if not path.exists():
            print(f"MISSING  {path.relative_to(REPO_ROOT)}")
            return False
        if path.read_bytes() != data:
            print(f"STALE    {path.relative_to(REPO_ROOT)}")
            return False
        print(f"ok       {path.relative_to(REPO_ROOT)}")
        return True

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(f"wrote    {path.relative_to(REPO_ROOT)}  {image.width}x{image.height}")
    return True


# Godot 4.7 builds the iOS asset catalogue from one 1024px master, plus the
# dark and tinted variants iOS 18 asks for.
ICON_SIZE = 1024
LAUNCH_SCREEN_SIZE = (1536, 1536)


def _scale_icon(source: Image.Image, size: int) -> Image.Image:
    """Nearest-neighbour up to a whole multiple, then resample down.

    Scaling 64px straight to 29px with a smooth filter turns the porthole into
    mush; blowing it up first keeps the pixel edges recognisable.
    """
    multiple = max(1, -(-size // source.width))
    blown_up = source.resize(
        (source.width * multiple, source.height * multiple), Image.NEAREST
    )
    if blown_up.width == size:
        return blown_up
    return blown_up.resize((size, size), Image.LANCZOS)


def build_launch_screen() -> Image.Image:
    """Plain dark field with the porthole centred, matching the title screen."""
    width, height = LAUNCH_SCREEN_SIZE
    background = PALETTE[ABYSS]
    canvas = Image.new("RGB", (width, height), background)

    icon = build_app_icon().to_image().convert("RGB")
    target = min(width, height) // 3
    scaled = _scale_icon(icon, target)
    canvas.paste(scaled, ((width - target) // 2, (height - target) // 2))
    return canvas


def generate(check_only: bool = False) -> int:
    ok = True

    ok &= _write(
        OUT_ROOT / "tiles" / "terrain_atlas.png", build_atlas(TERRAIN_TILES).to_image(), check_only
    )
    ok &= _write(
        OUT_ROOT / "tiles" / "props_atlas.png", build_atlas(PROP_TILES).to_image(), check_only
    )

    for name, pal in (("player", WORKER), ("officer", OFFICER), ("trader", TRADER)):
        ok &= _write(
            OUT_ROOT / "actors" / f"{name}.png", build_character_sheet(pal).to_image(), check_only
        )

    ok &= _write(OUT_ROOT / "ui" / "icons.png", build_icon_atlas().to_image(), check_only)

    # App Store icons must be fully opaque and square, with no rounding applied:
    # iOS masks the corners itself and rejects an alpha channel.
    source = build_app_icon().to_image().convert("RGB")
    master = _scale_icon(source, ICON_SIZE)
    ok &= _write(OUT_ROOT / "icons" / "app_icon.png", master, check_only)
    ok &= _write(OUT_ROOT / "icons" / "app_icon_dark.png", _darkened(master), check_only)
    ok &= _write(OUT_ROOT / "icons" / "app_icon_tinted.png", _greyscale(master), check_only)
    ok &= _write(OUT_ROOT / "icons" / "launch_screen.png", build_launch_screen(), check_only)

    return 0 if ok else 1


def _darkened(image: Image.Image) -> Image.Image:
    """iOS 18 dark-mode variant: the same art with the lights turned down."""
    return Image.eval(image, lambda channel: int(channel * 0.55))


def _greyscale(image: Image.Image) -> Image.Image:
    """iOS 18 tinted variant, which the system recolours itself."""
    return image.convert("L").convert("RGB")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify committed PNGs match what this script produces, without writing",
    )
    args = parser.parse_args()
    return generate(check_only=args.check)


if __name__ == "__main__":
    raise SystemExit(main())
