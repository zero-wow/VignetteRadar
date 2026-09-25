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
         "trail", "eye", "help", "close", "route")
STATES = (
    # Circular hover wash, edge, icon, active underline. Active art never
    # acquires a separate square tile: it belongs to the same icon family.
    (0.00, 0.00, 0.76, 0.00),
    (0.06, 0.20, 1.00, 0.00),
    (0.00, 0.00, 1.00, 0.92),
    (0.08, 0.26, 1.00, 1.00),
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
        return min(segment(x, y, -11, 7, -8, 6, 1.8),
                   segment(x, y, -5, 5, -2, 3, 1.8),
                   segment(x, y, 1, 1, 4, -1, 1.8),
                   segment(x, y, 7, -4, 10, -6, 1.8))
    if icon == "route":
        return min(abs(math.hypot(x + 10, y - 7) - 3) - 1.9,
                   segment(x, y, -6, 7, -2, 7, 2.1),
                   segment(x, y, -2, 7, -2, -7, 2.1),
                   segment(x, y, -2, -7, 9, -7, 2.1),
                   segment(x, y, 9, -7, 5, -10, 2.1),
                   segment(x, y, 9, -7, 5, -4, 2.1))
    if icon == "eye":
        return min(segment(x, y, -11, 0, -6, -4, 1.7),
                   segment(x, y, -6, -4, 0, -6, 1.7),
                   segment(x, y, 0, -6, 6, -4, 1.7),
                   segment(x, y, 6, -4, 11, 0, 1.7),
                   segment(x, y, -11, 0, -6, 4, 1.7),
                   segment(x, y, -6, 4, 0, 6, 1.7),
                   segment(x, y, 0, 6, 6, 4, 1.7),
                   segment(x, y, 6, 4, 11, 0, 1.7),
                   disk(x, y, 0, 0, 3.3))
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


hover_fill, hover_edge, active_mark = [], [], []
glyphs = {icon: [] for icon in ICONS}
for py in range(CELL):
    for px in range(CELL):
        x, y = px + 0.5 - CELL / 2, py + 0.5 - CELL / 2
        distance = disk(x, y, 0, 0, 25)
        outer = coverage(distance)
        inner = coverage(distance + 1.5)
        hover_fill.append(outer)
        hover_edge.append(max(0, outer - inner))
        active_mark.append(coverage(segment(x, y, -4, 15, 4, 15, 1.3)))
        for icon in ICONS:
            glyphs[icon].append(coverage(icon_distance(icon, x, y)))


pixels = bytearray(WIDTH * HEIGHT * 4)
for state, (fill_alpha, edge_alpha, glyph_alpha, active_alpha) in enumerate(STATES):
    for column, icon in enumerate(ICONS):
        for index in range(CELL * CELL):
            px, py = index % CELL, index // CELL
            alpha = max(hover_fill[index] * fill_alpha,
                        hover_edge[index] * edge_alpha,
                        glyphs[icon][index] * glyph_alpha,
                        active_mark[index] * active_alpha)
            target = ((state * CELL + py) * WIDTH + column * CELL + px) * 4
            pixels[target:target + 4] = (255, 255, 255, round(255 * alpha))

header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                     WIDTH, HEIGHT, 32, 0x28)
destination = Path(__file__).resolve().parents[1] / "Media" / "radar-corner-controls.tga"
destination.write_bytes(header + pixels)
print(f"Generated {destination.name}: {len(ICONS)} icons, {len(STATES)} states")
