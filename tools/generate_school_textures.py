"""Create original 256 px, repeatable school materials with authored wear.

Only Pillow is required. Fixed seeds make assets reproducible. Detail is
deliberately broad enough to survive the project's 960x540 PS2-style view.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "materials" / "school"
SIZE = 256


def clamp(value):
    return max(0, min(255, round(value)))


def noise(seed, cells):
    """Periodic smooth value noise, continuous across both tile edges."""
    rng = random.Random(seed)
    grid = [[rng.uniform(-1, 1) for _ in range(cells)] for _ in range(cells)]
    result = []
    for y in range(SIZE):
        fy = y * cells / SIZE
        iy = int(fy)
        ty = (fy - iy) ** 2 * (3 - 2 * (fy - iy))
        row = []
        for x in range(SIZE):
            fx = x * cells / SIZE
            ix = int(fx)
            tx = (fx - ix) ** 2 * (3 - 2 * (fx - ix))
            a = grid[iy][ix] * (1 - tx) + grid[iy][(ix + 1) % cells] * tx
            b = grid[(iy + 1) % cells][ix] * (1 - tx) + grid[(iy + 1) % cells][(ix + 1) % cells] * tx
            row.append(a * (1 - ty) + b * ty)
        result.append(row)
    return result


def base(color, seed, broad=13, fine=7):
    low, high = noise(seed, 5), noise(seed + 1, 21)
    rng = random.Random(seed + 2)
    image = Image.new("RGB", (SIZE, SIZE))
    px = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            value = low[y][x] * broad + high[y][x] * fine + rng.randrange(-3, 4)
            px[x, y] = tuple(clamp(channel + value) for channel in color)
    return image


def overlay(image, painter):
    # Draw marks in a 3x3 neighborhood so edge-crossing chips repeat.
    canvas = Image.new("RGBA", (SIZE * 3, SIZE * 3))
    for dy in (-SIZE, 0, SIZE):
        for dx in (-SIZE, 0, SIZE):
            painter(ImageDraw.Draw(canvas, "RGBA"), dx + SIZE, dy + SIZE)
    center = canvas.crop((SIZE, SIZE, 2 * SIZE, 2 * SIZE))
    return Image.alpha_composite(image.convert("RGBA"), center).convert("RGB")


def flecks(draw, ox, oy, rng, count, palette, maximum=3):
    for _ in range(count):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        rx, ry = rng.randrange(1, maximum + 1), rng.randrange(1, maximum + 1)
        draw.ellipse((ox+x-rx, oy+y-ry, ox+x+rx, oy+y+ry), fill=rng.choice(palette))


def plaster():
    image = base((177, 174, 165), 401, 16, 6)
    def marks(draw, ox, oy):
        rng = random.Random(410)
        for _ in range(48):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            rx, ry = rng.randrange(3, 17), rng.randrange(2, 14)
            draw.polygon([(ox+x-rx, oy+y), (ox+x-rx//2, oy+y-ry),
                          (ox+x+rx, oy+y-ry//2), (ox+x+rx//2, oy+y+ry)],
                         fill=rng.choice(((68,65,61,38), (83,79,69,52), (214,207,187,38))))
        flecks(draw, ox, oy, rng, 190,
               [(60,61,58,55), (85,83,75,37), (219,213,192,58)], 2)
    return overlay(image, marks)


def ceramic():
    image = base((144, 147, 143), 402, 12, 8)
    px = image.load()
    # Each room floor BoxMesh receives one complete tile: grout goes on edges.
    for y in range(SIZE):
        for x in range(SIZE):
            edge = min(x, y, SIZE-1-x, SIZE-1-y)
            if edge < 3:
                px[x, y] = (49, 54, 55)
            elif edge < 7:
                px[x, y] = tuple(clamp(c * .65) for c in px[x, y])
            elif edge < 11:
                px[x, y] = tuple(clamp(c * 1.09) for c in px[x, y])
    def marks(draw, ox, oy):
        rng = random.Random(420)
        for _ in range(24):
            x, y = rng.randrange(12, SIZE-12), rng.randrange(12, SIZE-12)
            rx, ry = rng.randrange(4, 19), rng.randrange(2, 13)
            draw.ellipse((ox+x-rx, oy+y-ry, ox+x+rx, oy+y+ry),
                         fill=rng.choice(((43,48,45,30), (84,80,69,45), (197,200,191,25))))
        for _ in range(19):
            x, y = rng.randrange(16, SIZE-16), rng.randrange(16, SIZE-16)
            draw.line((ox+x, oy+y, ox+x+rng.randrange(8,35), oy+y+rng.randrange(-3,4)),
                      fill=(48,54,54,rng.randrange(20,65)), width=1)
        for _ in range(26):
            side = rng.randrange(4)
            x = rng.randrange(SIZE) if side < 2 else (rng.randrange(9,25) if side == 2 else SIZE-rng.randrange(9,25))
            y = (rng.randrange(9,25) if side == 0 else SIZE-rng.randrange(9,25)) if side < 2 else rng.randrange(SIZE)
            draw.polygon([(ox+x,oy+y), (ox+x+4,oy+y-2), (ox+x+7,oy+y+3)],
                         fill=(59,64,62,80))
    return overlay(image, marks)


def concrete():
    image = base((127, 133, 136), 403, 17, 10)
    def marks(draw, ox, oy):
        rng = random.Random(430)
        flecks(draw, ox, oy, rng, 155, [(43,50,54,42), (180,184,179,37)])
        for _ in range(15):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            points = [(ox+x, oy+y)]
            for _ in range(rng.randrange(2,5)):
                x += rng.randrange(5,18)
                y += rng.randrange(-6,7)
                points.append((ox+x,oy+y))
            draw.line(points, fill=(38,45,48,52), width=1)
    return overlay(image, marks)


def damp():
    image = base((104, 116, 113), 404, 21, 11)
    def marks(draw, ox, oy):
        rng = random.Random(440)
        for _ in range(52):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            rx, ry = rng.randrange(4,29), rng.randrange(4,20)
            draw.ellipse((ox+x-rx, oy+y-ry, ox+x+rx, oy+y+ry),
                         fill=rng.choice(((25,35,36,28), (34,46,42,38), (132,126,104,28))))
        flecks(draw, ox, oy, rng, 170, [(15,24,25,60), (173,172,157,38)])
    return overlay(image, marks)


def wood():
    image = base((128, 99, 76), 405, 9, 4)
    px = image.load()
    rng = random.Random(450)
    bands = [rng.randrange(-12,13) for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            grain = bands[x] * .6 + math.sin((x+3*math.sin(y/39))*.19)*3
            if x < 3 or x > SIZE-4:
                grain -= 27
            elif x < 7 or x > SIZE-8:
                grain += 9
            r,g,b = px[x,y]
            px[x,y] = (clamp(r+grain), clamp(g+grain*.77), clamp(b+grain*.6))
    def marks(draw, ox, oy):
        rng = random.Random(451)
        for _ in range(50):
            x,y = rng.randrange(SIZE),rng.randrange(SIZE)
            draw.line((ox+x,oy+y,ox+x+rng.randrange(-2,3),oy+y+rng.randrange(13,77)),
                      fill=rng.choice(((46,34,30,35),(213,181,139,32))), width=rng.choice((1,1,2)))
        flecks(draw, ox, oy, rng, 40, [(39,33,30,62),(196,171,134,40)])
    return overlay(image, marks)


def painted_metal():
    # For dark stall doors and rails: aged blue paint over charcoal steel.
    image = base((93, 106, 111), 406, 8, 6)
    def marks(draw, ox, oy):
        rng = random.Random(460)
        for _ in range(65):
            x,y = rng.randrange(SIZE),rng.randrange(SIZE)
            length = rng.randrange(3,22)
            draw.line((ox+x,oy+y,ox+x+length,oy+y+rng.randrange(-2,3)),
                      fill=rng.choice(((25,34,37,55),(151,157,151,33),(111,72,54,43))),
                      width=rng.choice((1,1,2)))
        flecks(draw,ox,oy,rng,55,[(39,46,46,70),(124,76,56,48)],2)
    return overlay(image,marks)


def notice_felt():
    # Restrained woven green, not legible fake text; real notices remain geometry.
    image = base((79, 105, 94), 407, 10, 4)
    px = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            weave = (2 if x % 4 == 0 else 0) + (2 if y % 4 == 0 else 0)
            r,g,b = px[x,y]
            px[x,y] = (clamp(r-weave),clamp(g-weave),clamp(b-weave))
    def marks(draw,ox,oy):
        rng=random.Random(470)
        flecks(draw,ox,oy,rng,95,[(22,38,35,28),(150,156,136,23)],2)
        for _ in range(13):
            x,y=rng.randrange(SIZE),rng.randrange(SIZE)
            draw.ellipse((ox+x-1,oy+y-1,ox+x+1,oy+y+1),fill=(37,38,32,60))
    return overlay(image,marks)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, factory in (
        ("old_plaster.png", plaster),
        ("floor_ceramic.png", ceramic),
        ("ceiling_concrete.png", concrete),
        ("damp_base.png", damp),
        ("worn_wood.png", wood),
        ("painted_metal.png", painted_metal),
        ("notice_felt.png", notice_felt),
    ):
        factory().save(OUT / name, optimize=True)
    print("SCHOOL_TEXTURES_OK", OUT)


if __name__ == "__main__":
    main()
