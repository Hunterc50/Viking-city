"""
Makes the game's own tileable textures (512 x 512 PNG), written to textures/.

Each texture is a near-neutral "detail" image: the game tints it with the
colour of the part it sits on, so one wood texture serves pale birch and dark
tarred oak alike. A matching normal map (<Name>_Normal.png) is made too, for
SurfaceAppearance if you ever use one.

    python tools/textures/generate.py

Everything here is drawn from noise and simple shapes: no outside images.
"""
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "textures")
rng = np.random.default_rng(1234)


def noise(cells, seed, octaves=4, persistence=0.5):
    """Tileable fractal value noise in [0, 1]."""
    r = np.random.default_rng(seed)
    total = np.zeros((N, N))
    amp, norm = 1.0, 0.0
    c = cells
    for _ in range(octaves):
        grid = r.random((c, c))
        y = np.linspace(0, c, N, endpoint=False)
        x = np.linspace(0, c, N, endpoint=False)
        X, Y = np.meshgrid(x, y)
        x0 = np.floor(X).astype(int) % c
        y0 = np.floor(Y).astype(int) % c
        x1, y1 = (x0 + 1) % c, (y0 + 1) % c
        fx, fy = X - np.floor(X), Y - np.floor(Y)
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        a = grid[y0, x0] * (1 - fx) + grid[y0, x1] * fx
        b = grid[y1, x0] * (1 - fx) + grid[y1, x1] * fx
        total += (a * (1 - fy) + b * fy) * amp
        norm += amp
        amp *= persistence
        c *= 2
    return total / norm


def coords():
    y = np.arange(N) / N
    x = np.arange(N) / N
    return np.meshgrid(x, y)


def tint(height, base, var=0.12):
    """Height in [0,1] -> RGB image around `base` (0..1 floats)."""
    h = np.clip(height, 0, 1)[..., None]
    base = np.array(base)
    img = base * (1 - var + 2 * var * h)
    return np.clip(img, 0, 1)


def normal_map(height, strength=3.0):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5)


def save(name, rgb, height):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    Image.fromarray((normal_map(height) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_Normal.png"))
    print("wrote", name)


def planks():
    X, Y = coords()
    rows = 4
    row = np.floor(Y * rows)
    # each plank row is shifted and has its own tone
    shift = (row * 0.37) % 1
    tone = 0.85 + 0.15 * ((row * 7919) % 5) / 4
    grain = noise(4, 1, 3)
    streaks = np.sin((Y * rows * 18 + noise(2, 2, 2) * 6 + grain * 3) * np.pi * 2) * 0.5 + 0.5
    fine = noise(64, 3, 2)
    h = 0.55 * streaks + 0.25 * grain + 0.2 * fine
    # gaps between planks and butt joints
    fy = (Y * rows) % 1
    gap = np.minimum(fy, 1 - fy) < 0.02
    fx = (X + shift) % 0.5
    joint = np.minimum(fx, 0.5 - fx) < 0.004
    h = h * tone
    h[gap | joint] = 0.05
    # nail heads
    for r in range(rows):
        for jx in (0.0, 0.5):
            for oy in (0.3, 0.7):
                cx = (jx - (r * 0.37) % 1 + 0.015) % 1
                cy = (r + oy) / rows
                d = np.hypot(((X - cx + 0.5) % 1) - 0.5, ((Y - cy + 0.5) % 1) - 0.5)
                h[d < 0.006] = 0.15
    save("Planks", tint(h, (0.80, 0.70, 0.58), 0.3), h)


def bark():
    X, Y = coords()
    ridges = noise(8, 11, 4)
    v = np.abs(np.sin((X * 14 + ridges * 2.5) * np.pi))
    cracks = noise(4, 12, 5)
    h = 0.6 * v + 0.4 * cracks
    h = np.where(v < 0.12, h * 0.3, h)
    save("Bark", tint(h, (0.70, 0.62, 0.54), 0.35), h)


def stone():
    # irregular dry-stone wall: jittered Voronoi cells
    X, Y = coords()
    pts = rng.random((60, 2))
    d1 = np.full((N, N), 9.0)
    d2 = np.full((N, N), 9.0)
    idx = np.zeros((N, N), int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(X - px); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(Y - py); dy = np.minimum(dy, 1 - dy)
        d = np.hypot(dx * 1.0, dy * 1.6)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    edge = d2 - d1
    rough = noise(16, 21, 5)
    tone = 0.75 + 0.25 * (idx * 2654435761 % 97) / 96
    h = np.clip(edge * 18, 0, 1) ** 0.5 * (0.7 + 0.3 * rough) * tone
    h = np.where(edge < 0.012, 0.08 + 0.1 * rough, h)
    save("Stone", tint(h, (0.74, 0.73, 0.71), 0.35), h)


def thatch():
    X, Y = coords()
    h = np.zeros((N, N))
    r = np.random.default_rng(31)
    # thousands of short straws, all running down the roof
    for _ in range(2600):
        x0, y0 = r.random(), r.random()
        length = r.uniform(0.06, 0.16)
        width = r.uniform(0.002, 0.004)
        lean = r.uniform(-0.05, 0.05)
        shade = r.uniform(0.5, 1.0)
        dy = (Y - y0) % 1
        dx = ((X - x0 - lean * dy + 0.5) % 1) - 0.5
        mask = (dy < length) & (np.abs(dx) < width)
        h = np.where(mask, np.maximum(h, shade * (1 - dy / length * 0.5)), h)
    h = h * 0.85 + noise(8, 32, 3) * 0.15
    # bundled courses
    h *= 0.8 + 0.2 * (np.sin(Y * 6 * np.pi * 2) * 0.5 + 0.5)
    save("Thatch", tint(h, (0.86, 0.76, 0.52), 0.4), h)


def fur():
    X, Y = coords()
    flow = noise(4, 41, 3)
    h = np.zeros((N, N))
    r = np.random.default_rng(42)
    for _ in range(3500):
        x0, y0 = r.random(), r.random()
        length = r.uniform(0.02, 0.05)
        ang = 1.4 + (flow[int(y0 * N) % N, int(x0 * N) % N] - 0.5) * 1.6
        dxs, dys = np.cos(ang), np.sin(ang)
        rx = ((X - x0 + 0.5) % 1) - 0.5
        ry = ((Y - y0 + 0.5) % 1) - 0.5
        along = rx * dxs + ry * dys
        across = -rx * dys + ry * dxs
        mask = (along > 0) & (along < length) & (np.abs(across) < 0.0025)
        h = np.where(mask, np.maximum(h, r.uniform(0.5, 1) * (1 - along / length)), h)
    h = 0.35 + 0.65 * np.maximum(h, noise(32, 43, 3) * 0.6)
    save("Fur", tint(h, (0.72, 0.66, 0.58), 0.35), h)


def iron():
    X, Y = coords()
    brushed = noise(2, 51, 2)[:, :1].repeat(N, 1) * 0.0
    streak = noise(1, 52, 1)
    scratch = np.abs(np.sin((X * 3 + noise(64, 53, 2) * 0.3) * np.pi * 60)) > 0.995
    pits = noise(48, 54, 3)
    rust = np.clip((noise(6, 55, 5) - 0.62) * 4, 0, 1)
    h = 0.6 + 0.2 * streak + 0.15 * pits + brushed
    h = np.where(scratch, h + 0.15, h)
    rgb = tint(h, (0.62, 0.63, 0.65), 0.25)
    rgb = rgb * (1 - rust[..., None] * 0.7) + np.array([0.45, 0.27, 0.15]) * rust[..., None] * 0.7
    save("Iron", rgb, h - rust * 0.2)


def mail():
    X, Y = coords()
    rings = 16
    h = np.zeros((N, N))
    for row in range(rings * 2):
        off = 0.5 if row % 2 else 0.0
        cy = row / (rings * 2)
        for col in range(rings):
            cx = (col + off) / rings
            dx = ((X - cx + 0.5) % 1) - 0.5
            dy = ((Y - cy + 0.5) % 1) - 0.5
            d = np.hypot(dx, dy * 1.0) * rings
            ring = np.clip(1 - np.abs(d - 0.42) / 0.09, 0, 1)
            h = np.maximum(h, ring)
    h = h * (0.8 + 0.2 * noise(16, 61, 2))
    rgb = tint(h, (0.66, 0.66, 0.68), 0.5)
    rgb[h < 0.05] = 0.08
    save("Mail", rgb, h)


def cloth():
    X, Y = coords()
    threads = 96
    warp = np.sin(X * threads * np.pi * 2) * 0.5 + 0.5
    weft = np.sin(Y * threads * np.pi * 2) * 0.5 + 0.5
    over = (np.floor(X * threads) + np.floor(Y * threads)) % 2
    h = np.where(over == 0, warp, weft) * 0.6 + 0.4
    h *= 0.85 + 0.15 * noise(6, 71, 4)
    slub = np.clip((noise(3, 72, 3) - 0.5) * 2, -1, 1) * 0.06
    save("Cloth", tint(h + slub, (0.86, 0.82, 0.74), 0.25), h)


def leather():
    X, Y = coords()
    cells = noise(48, 81, 2)
    creases = np.abs(noise(6, 82, 5) - 0.5) < 0.02
    h = 0.6 + 0.25 * cells + 0.15 * noise(4, 83, 3)
    h = np.where(creases, h * 0.6, h)
    save("Leather", tint(h, (0.62, 0.46, 0.34), 0.3), h)


if __name__ == "__main__":
    for make in (planks, bark, stone, thatch, fur, iron, mail, cloth, leather):
        make()
