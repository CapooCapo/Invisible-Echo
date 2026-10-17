"""Generate a subtle 2:1 equirectangular star-cover texture for Godot skies."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "sky" / "night_starfield_2k.png"
SIZE = (2048, 1024)
SEED = 4162026


def _star_position(rng: random.Random) -> tuple[int, int]:
    x = rng.randrange(SIZE[0])
    z = rng.uniform(-1.0, 1.0)
    latitude = math.asin(z)
    y = round((0.5 - latitude / math.pi) * SIZE[1]) % SIZE[1]
    return x, y


def _draw_wrapped_ellipse(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    radius: int,
    color: tuple[int, int, int],
) -> None:
    """Draw across the equirectangular left/right seam without clipping."""
    for offset_x in (-SIZE[0], 0, SIZE[0]):
        left = x - radius + offset_x
        right = x + radius + offset_x
        if right >= 0 and left < SIZE[0]:
            draw.ellipse((left, y - radius, right, y + radius), fill=color)


def main() -> None:
    rng = random.Random(SEED)
    image = Image.new("RGB", SIZE, (0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Sparse, cool stars keep the silhouette simple at gameplay resolution.
    for index in range(620):
        x, y = _star_position(rng)
        strength = rng.uniform(35, 84)
        if index >= 580:
            strength = rng.uniform(88, 135)
        radius = 1
        tint = rng.choice(((0.78, 0.87, 1.0), (0.66, 0.81, 1.0), (1.0, 0.91, 0.82)))
        color = tuple(round(min(255, strength * component)) for component in tint)
        _draw_wrapped_ellipse(draw, x, y, radius, color)

    # A few restrained brighter points provide scale without a large glow or
    # moon-like hotspot. Wrap horizontally for a seamless equirectangular map.
    for _index in range(5):
        x, y = _star_position(rng)
        strength = rng.randint(145, 175)
        color = (strength, round(strength * 0.93), round(strength * 0.80))
        draw.point((x, y), fill=color)
        draw.point(((x - 1) % SIZE[0], y), fill=tuple(round(c * 0.20) for c in color))
        draw.point(((x + 1) % SIZE[0], y), fill=tuple(round(c * 0.20) for c in color))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(f"Generated {OUTPUT} ({SIZE[0]}x{SIZE[1]}, seed={SEED})")


if __name__ == "__main__":
    main()
