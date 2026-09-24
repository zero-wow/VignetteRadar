"""Build the tiny, uncompressed TGA masks used by quest diamonds and areas."""

from pathlib import Path

MEDIA = Path(__file__).resolve().parents[1] / "Media"
COLORS = (
    (94, 219, 199), (255, 179, 87), (181, 150, 255), (255, 120, 133),
    (110, 199, 255), (186, 219, 94), (245, 153, 212), (255, 145, 82),
)


def write_tga(path, width, height, pixel):
    header = bytearray(18)
    header[2] = 2  # uncompressed true-color
    header[12:14] = width.to_bytes(2, "little")
    header[14:16] = height.to_bytes(2, "little")
    header[16] = 32
    header[17] = 0x28  # 8 alpha bits, top-left origin
    data = bytearray(header)
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixel(x, y)
            data.extend((blue, green, red, alpha))
    path.write_bytes(data)


def diamond(x, y):
    samples = 0
    for sy in range(4):
        for sx in range(4):
            xx = x + (sx + .5) / 4 - 16
            yy = y + (sy + .5) / 4 - 16
            samples += abs(xx) + abs(yy) <= 13
    return 255, 255, 255, round(samples * 255 / 16)


MEDIA.mkdir(exist_ok=True)
write_tga(MEDIA / "quest-diamond.tga", 32, 32, diamond)
for index, color in enumerate(COLORS, 1):
    write_tga(MEDIA / f"quest-area-{index:02d}.tga", 8, 8,
              lambda x, y, color=color: (*color, 255))
