"""Generate matching theme-tinted radar face and continuous rounded outline."""

import math
from pathlib import Path
import struct


SIZE = 256
CORNER_RATIO = 0.04
STROKE = SIZE / 182  # One UI unit at the Classic face size; scales with the face.
corner = SIZE * CORNER_RATIO
inner = SIZE / 2 - corner
pixels = bytearray()
border_pixels = bytearray()
for y in range(SIZE):
    for x in range(SIZE):
        dx = abs(x + 0.5 - SIZE / 2) - inner
        dy = abs(y + 0.5 - SIZE / 2) - inner
        distance = math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - corner
        outer = max(0, min(1, 0.5 - distance))
        interior = max(0, min(1, 0.5 - distance - STROKE))
        pixels.extend((255, 255, 255, round(255 * outer)))
        border_pixels.extend((255, 255, 255, round(255 * (outer - interior))))

# Uncompressed 32-bit BGRA TGA: top-left origin, eight alpha bits.
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
media = Path(__file__).resolve().parents[1] / "Media"
for name, data in (("radar-rounded-square.tga", pixels), ("radar-rounded-border.tga", border_pixels)):
    (media / name).write_bytes(header + data)
    print(f"Generated {name}: {SIZE}x{SIZE}, {CORNER_RATIO:.0%} corner radius")
