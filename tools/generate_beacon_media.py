"""Generate theme-tinted art for the multi-target bearing display."""

import math
from pathlib import Path
import struct


MEDIA = Path(__file__).resolve().parents[1] / "Media"


def coverage(distance):
    return max(0.0, min(1.0, 0.5 - distance))


def write_tga(name, width, height, alpha_at):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                         width, height, 32, 0x28)
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            pixels.extend((255, 255, 255,
                           round(255 * max(0.0, min(1.0, alpha_at(x + .5, y + .5))))))
    (MEDIA / name).write_bytes(header + pixels)


def rounded_rect(x, y, width, height, radius):
    dx = abs(x - width / 2) - (width / 2 - radius)
    dy = abs(y - height / 2) - (height / 2 - radius)
    return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - radius


W, H = 512, 128


def surface(x, y):
    d = rounded_rect(x - 2, y - 2, W - 4, H - 4, 16)
    # Gentle edge falloff gives the dark instrument some depth at small scale.
    return coverage(d) * (0.88 + 0.10 * (1 - y / H))


def border(x, y):
    d = rounded_rect(x - 2, y - 2, W - 4, H - 4, 16)
    return max(0.0, coverage(d) - coverage(d + 2.0)) * (0.88 - 0.25 * y / H)


write_tga("beacon-surface.tga", W, H, surface)
write_tga("beacon-border.tga", W, H, border)


def rare(x, y):
    dx, dy = x - 32, y - 32
    radius = math.hypot(dx, dy)
    ring = coverage(abs(radius - 20) - 1.65)
    tick_north_south = coverage(abs(dx) - 1.35) * (17 <= abs(dy) <= 25)
    tick_east_west = coverage(abs(dy) - 1.35) * (17 <= abs(dx) <= 25)
    center = coverage(radius - 5.5)
    return max(ring, tick_north_south, tick_east_west, center)


write_tga("beacon-rare.tga", 64, 64, rare)


def launcher_shape(x, y):
    lobe = math.hypot(x - 122, y - 128) - 119
    rect = rounded_rect(x - 116, y - 26, 392, 204, 31)
    return min(lobe, rect)


def launcher_surface(x, y):
    d = launcher_shape(x, y)
    return coverage(d) * (0.94 - 0.13 * y / 256)


def launcher_border(x, y):
    d = launcher_shape(x, y)
    return max(0, coverage(d) - coverage(d + 4)) * (0.9 - 0.16 * y / 256)


write_tga("launcher-housing.tga", 512, 256, launcher_surface)
write_tga("launcher-outline.tga", 512, 256, launcher_border)
