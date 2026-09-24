"""Generate one theme-tinted atlas for the radar-only corner controls.

The four rows are normal, hover, on, and on-hover. Each 64px cell has a
transparent gutter so the game can filter the atlas without neighboring art
bleeding into a button. The addon tints the white art with its current accent.
"""

import math
import struct
from pathlib import Path


CELL = 64
WIDTH, HEIGHT = 1024, 256
ICONS = ("config", "target", "legend", "minus", "plus", "north",
         "trail", "eye", "help", "close")
STATES = (
    # Tile fill, tile edge, icon.
    (0.00, 0.00, 0.76),
    (0.09, 0.32, 1.00),
    (0.14, 0.52, 1.00),
    (0.20, 0.74, 1.00),
)


def coverage(distance):
    return max(0.0, min(1.0, 0.5 - distance))


def segment(x, y, x1, y1, x2, y2, radius=2.3):
    dx, dy = x2 - x1, y2 - y1
    length_squared = dx * dx + dy * dy
    t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / length_squared))
    return math.hypot(x - x1 - t * dx, y - y1 - t * dy) - radius


def disk(x, y, cx, cy, radius):
    return math.hypot(x - cx, y - cy) - radius


def icon_distance(icon, x, y):
    if icon == "config":
        return min(abs(math.hypot(x, y) - 8) - 1.9, disk(x, y, 0, 0, 3.5))
    if icon == "target":
        return min(abs(math.hypot(x, y) - 8) - 1.7,
                   disk(x, y, 0, 0, 2.5),
                   segment(x, y, -12, 0, -9, 0, 1.6),
                   segment(x, y, 9, 0, 12, 0, 1.6),
                   segment(x, y, 0, -12, 0, -9, 1.6),
                   segment(x, y, 0, 9, 0, 12, 1.6))
    if icon == "legend":
        return min(min(disk(x, y, -9, row, 2.5),
                       segment(x, y, -3, row, 9, row, 1.25))
                   for row in (-8, 0, 8))
    if icon == "minus":
        return segment(x, y, -9, 0, 9, 0, 2.4)
    if icon == "plus":
        return min(segment(x, y, -9, 0, 9, 0, 2.4),
                   segment(x, y, 0, -9, 0, 9, 2.4))
    if icon == "north":
        return min(segment(x, y, -8, 9, -8, -9, 1.9),
                   segment(x, y, -8, -9, 8, 9, 1.9),
                   segment(x, y, 8, 9, 8, -9, 1.9))
    if icon == "trail":
        return min(segment(x, y, -11, 0, -7, 0, 2),
                   segment(x, y, -2, 0, 2, 0, 2),
                   segment(x, y, 7, 0, 11, 0, 2))
    if icon == "eye":
        return min(segment(x, y, -11, 0, 0, -6, 1.7),
                   segment(x, y, 0, -6, 11, 0, 1.7),
                   segment(x, y, -11, 0, 0, 6, 1.7),
                   segment(x, y, 0, 6, 11, 0, 1.7),
                   disk(x, y, 0, 0, 3))
    if icon == "help":
        return min(segment(x, y, -7, -5, -3, -9, 1.8),
                   segment(x, y, -3, -9, 4, -9, 1.8),
                   segment(x, y, 4, -9, 8, -5, 1.8),
                   segment(x, y, 8, -5, 6, 0, 1.8),
                   segment(x, y, 6, 0, 0, 4, 1.8),
                   segment(x, y, 0, 4, 0, 6, 1.8),
                   disk(x, y, 0, 11, 2))
    return min(segment(x, y, -8, -8, 8, 8, 2),
               segment(x, y, -8, 8, 8, -8, 2))


tile_fill, tile_edge = [], []
glyphs = {icon: [] for icon in ICONS}
for py in range(CELL):
    for px in range(CELL):
        x, y = px + 0.5 - CELL / 2, py + 0.5 - CELL / 2
        radius = 12
        dx, dy = abs(x) - (28 - radius), abs(y) - (28 - radius)
        distance = math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - radius
        outer = coverage(distance)
        inner = coverage(distance + 1.5)
        tile_fill.append(outer)
        tile_edge.append(max(0, outer - inner))
        for icon in ICONS:
            glyphs[icon].append(coverage(icon_distance(icon, x, y)))


pixels = bytearray(WIDTH * HEIGHT * 4)
for state, (fill_alpha, edge_alpha, glyph_alpha) in enumerate(STATES):
    for column, icon in enumerate(ICONS):
        for index in range(CELL * CELL):
            px, py = index % CELL, index // CELL
            alpha = max(tile_fill[index] * fill_alpha,
                        tile_edge[index] * edge_alpha,
                        glyphs[icon][index] * glyph_alpha)
            target = ((state * CELL + py) * WIDTH + column * CELL + px) * 4
            pixels[target:target + 4] = (255, 255, 255, round(255 * alpha))

header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                     WIDTH, HEIGHT, 32, 0x28)
destination = Path(__file__).resolve().parents[1] / "Media" / "radar-corner-controls.tga"
destination.write_bytes(header + pixels)
print(f"Generated {destination.name}: {len(ICONS)} icons, {len(STATES)} states")
