"""Generate the theme-tinted radar face, with transparent, softly rounded corners."""

import math
from pathlib import Path
import struct


SIZE = 256
CORNER_RATIO = 0.04  # Keep in sync with SQUARE_CORNER_RATIO in the radar renderer.
corner = SIZE * CORNER_RATIO
inner = SIZE / 2 - corner
pixels = bytearray()
for y in range(SIZE):
    for x in range(SIZE):
        dx = abs(x + 0.5 - SIZE / 2) - inner
        dy = abs(y + 0.5 - SIZE / 2) - inner
        distance = math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - corner
        alpha = round(255 * max(0, min(1, 0.5 - distance)))
        pixels.extend((255, 255, 255, alpha))

# Uncompressed 32-bit BGRA TGA: top-left origin, eight alpha bits.
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
target = Path(__file__).resolve().parents[1] / "Media" / "radar-rounded-square.tga"
target.write_bytes(header + pixels)
print(f"Generated {target.name}: {SIZE}x{SIZE}, {CORNER_RATIO:.0%} corner radius")
