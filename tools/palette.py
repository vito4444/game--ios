"""The fixed 16-colour palette and a small indexed-drawing surface.

Every sprite in the game is drawn through this module, which is what keeps the
art coherent: a sprite physically cannot use a colour outside the palette.
"""

from __future__ import annotations

from typing import Iterable, Sequence

from PIL import Image

TRANSPARENT = -1

# Index constants. Cold blues and teals build the hull, amber carries every
# "the rig wants your attention" signal, and ALARM is reserved for alarms and
# forbidden zones so the player learns to read one red as one meaning.
ABYSS = 0
HULL_SHADOW = 1
HULL_DARK = 2
HULL = 3
HULL_LIGHT = 4
HULL_HIGHLIGHT = 5
AMBER = 6
AMBER_DARK = 7
ALARM = 8
RUST = 9
STEEL_DARK = 10
STEEL = 11
STEEL_LIGHT = 12
BONE = 13
INK = 14
WHITE = 15

PALETTE: Sequence[tuple[int, int, int]] = (
    (0x0D, 0x1B, 0x2A),
    (0x13, 0x2A, 0x3A),
    (0x1B, 0x3A, 0x4B),
    (0x2E, 0x6F, 0x7E),
    (0x4A, 0xA3, 0xA2),
    (0x8F, 0xD6, 0xC9),
    (0xF2, 0xA6, 0x5A),
    (0xE0, 0x75, 0x2D),
    (0xD9, 0x4F, 0x3D),
    (0x7A, 0x3B, 0x2E),
    (0x3D, 0x3A, 0x4B),
    (0x6B, 0x68, 0x80),
    (0xA8, 0xA4, 0xB8),
    (0xE8, 0xE6, 0xDF),
    (0x2B, 0x2B, 0x2B),
    (0xF7, 0xF3, 0xE8),
)


class Surface:
    """A grid of palette indices with the drawing primitives the art needs.

    Out-of-bounds writes are dropped rather than raising, so shapes can be
    positioned by their natural centre and clipped at the tile edge.
    """

    def __init__(self, width: int, height: int, fill: int = TRANSPARENT) -> None:
        self.width = width
        self.height = height
        self._pixels = [fill] * (width * height)

    def set(self, x: int, y: int, colour: int) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self._pixels[y * self.width + x] = colour

    def get(self, x: int, y: int) -> int:
        if 0 <= x < self.width and 0 <= y < self.height:
            return self._pixels[y * self.width + x]
        return TRANSPARENT

    def fill(self, colour: int) -> None:
        self._pixels = [colour] * (self.width * self.height)

    def rect(self, x: int, y: int, width: int, height: int, colour: int) -> None:
        for yy in range(y, y + height):
            for xx in range(x, x + width):
                self.set(xx, yy, colour)

    def frame(self, x: int, y: int, width: int, height: int, colour: int) -> None:
        self.hline(x, y, width, colour)
        self.hline(x, y + height - 1, width, colour)
        self.vline(x, y, height, colour)
        self.vline(x + width - 1, y, height, colour)

    def hline(self, x: int, y: int, length: int, colour: int) -> None:
        for xx in range(x, x + length):
            self.set(xx, y, colour)

    def vline(self, x: int, y: int, length: int, colour: int) -> None:
        for yy in range(y, y + length):
            self.set(x, yy, colour)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, colour: int) -> None:
        for yy in range(int(cy - ry), int(cy + ry) + 1):
            for xx in range(int(cx - rx), int(cx + rx) + 1):
                nx = (xx + 0.5 - cx) / rx
                ny = (yy + 0.5 - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    self.set(xx, yy, colour)

    def ring(self, cx: float, cy: float, rx: float, ry: float, colour: int) -> None:
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx = (xx + 0.5 - cx) / rx
                ny = (yy + 0.5 - cy) / ry
                dist = nx * nx + ny * ny
                if 0.62 <= dist <= 1.0:
                    self.set(xx, yy, colour)

    def checker(
        self, x: int, y: int, width: int, height: int, colour: int, phase: int = 0
    ) -> None:
        """Two-colour dither, the cheapest way to fake a shade between palette entries."""
        for yy in range(y, y + height):
            for xx in range(x, x + width):
                if (xx + yy + phase) % 2 == 0:
                    self.set(xx, yy, colour)

    def scatter(
        self,
        x: int,
        y: int,
        width: int,
        height: int,
        colour: int,
        points: Iterable[tuple[int, int]],
    ) -> None:
        for px, py in points:
            if 0 <= px < width and 0 <= py < height:
                self.set(x + px, y + py, colour)

    def blit(self, source: "Surface", x: int, y: int) -> None:
        for yy in range(source.height):
            for xx in range(source.width):
                colour = source.get(xx, yy)
                if colour != TRANSPARENT:
                    self.set(x + xx, y + yy, colour)

    def outline(self, colour: int) -> None:
        """Trace a border around everything drawn so far.

        Sprites sit on dark hull tiles and lose their silhouette without it.
        """
        border: list[tuple[int, int]] = []
        for y in range(self.height):
            for x in range(self.width):
                if self.get(x, y) != TRANSPARENT:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    neighbour = self.get(x + dx, y + dy)
                    if neighbour != TRANSPARENT and neighbour != colour:
                        border.append((x, y))
                        break
        for x, y in border:
            self.set(x, y, colour)

    def flipped_horizontally(self) -> "Surface":
        out = Surface(self.width, self.height)
        for y in range(self.height):
            for x in range(self.width):
                out.set(self.width - 1 - x, y, self.get(x, y))
        return out

    def to_image(self) -> Image.Image:
        image = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 0))
        pixels = image.load()
        assert pixels is not None
        for y in range(self.height):
            for x in range(self.width):
                colour = self._pixels[y * self.width + x]
                if colour == TRANSPARENT:
                    continue
                red, green, blue = PALETTE[colour]
                pixels[x, y] = (red, green, blue, 255)
        return image
