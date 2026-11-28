"""
The game's 3D assets, built from code with mesh.py.
Run:  python3 tools/meshgen/build.py   (writes meshes/<Slot>.glb and meshes/obj/)

Conventions (match the built-in part models so a mesh drops straight in):
  buildings  door faces -Z, base at y = 0, centred
  longship   bow (dragon head) at -Z
  tools      held at the handle; the shaft runs along +Y
  deer       faces -Z
Sizes are in studs, close to the built-in models. The game rescales anyway.
"""

import math
import random

import numpy as np

from mesh import RX, RY, RZ, M, S, T, Mesh, blob, box, cylinder, hull, lathe, look_along, mix, shade, slab_between, strip_between  # noqa: F401

# ----------------------------------------------------------------------------- palette

WOOD = (122, 86, 54)
DARK = (72, 50, 34)
WEATHER = (128, 114, 96)
TAR = (58, 42, 30)
THATCH = (172, 138, 76)
TURF = (86, 110, 54)
MOSS = (74, 98, 48)
STONE = (116, 114, 108)
IRON = (66, 68, 72)
STEEL = (176, 180, 186)
LEATHER = (96, 62, 38)
RED = (150, 40, 36)
CREAM = (224, 210, 178)
GOLD = (206, 164, 82)
BLUE = (52, 76, 112)
HULL = (96, 68, 46)


# ----------------------------------------------------------------------------- helpers


def V(*a):
    return np.array(a, float)


def cyl_between(p, q, r, rgb, seg=8, r2=None, rng=None, vary=0.0, noise=0.0):
    p, q = V(*p), V(*q)
    d = q - p
    h = float(np.linalg.norm(d))
    return cylinder(r, h, seg, rgb, r_top=r2, rng=rng, vary=vary, noise=noise), M(T(*p), look_along(d))


def add_cyl(m, p, q, r, rgb, seg=8, r2=None, vary=0.0, noise=0.0):
    tris, mat = cyl_between(p, q, r, rgb, seg, r2, m.rng, vary, noise)
    m.add(tris, mat)


def add_box(m, centre, size, rgb, rot=None, vary=0.0, bevel=0.0):
    mat = T(*centre) if rot is None else M(T(*centre), rot)
    m.add(box(*size, rgb, m.rng, vary, bevel), mat)


def add_beam(m, p, q, w, rgb, vary=0.0):
    """A square beam from p to q."""
    p, q = V(*p), V(*q)
    d = q - p
    h = float(np.linalg.norm(d))
    m.add(box(w, h, w, rgb, m.rng, vary), M(T(*((p + q) / 2)), look_along(d)))


def recolour(m, fn, start=0):
    """fn(rgb, normal, centre) -> rgb, for triangles from index `start` on."""
    out = m.tris[:start]
    for a, b, c, rgb in m.tris[start:]:
        n = np.cross(b - a, c - a)
        ln = np.linalg.norm(n)
        n = n / ln if ln > 1e-12 else V(0, 1, 0)
        out.append((a, b, c, fn(rgb, n, (a + b + c) / 3)))
    m.tris = out


def disc(m, centre, normal, r, rgb, boss=None, rim=None, seg=14, paint=None):
    """A round shield: face, iron rim, boss. `paint` = second colour for halves."""
    face = lathe([(r, 0), (r, 0.12), (0.0, 0.16)], seg, rgb)
    if paint:
        recol = []
        for a, b, c, col in face:
            mid = (a + b + c) / 3
            recol.append((a, b, c, paint if (math.atan2(mid[2], mid[0]) % math.pi) < math.pi / 2 else col))
        face = recol
    mat = M(T(*centre), look_along(normal))
    m.add(face, mat)
    if rim:
        m.add(lathe([(r - 0.02, -0.03), (r + 0.07, -0.03), (r + 0.07, 0.18), (r - 0.1, 0.19)], seg, rim, caps=False), mat)
    if boss:
        m.add(lathe([(r * 0.24, 0.1), (r * 0.2, 0.3), (0.0, 0.4)], 8, boss), mat)


# ----------------------------------------------------------------------------- halls


def hall(L=32, D=15.5, wall_h=4.6, ridge_h=12.5, roof="thatch", seed=1, dragons=True, buttress=True, porch=False):
    """A Norse longhouse: bowed stave walls, a sweeping curved roof, stone
    footing, slanted outer posts, crossed gable boards with dragon heads."""
    m = Mesh(seed)
    rng = m.rng
    hx, hz = L / 2 - 1.4, D / 2 - 1.6  # wall line (the roof overhangs it)

    def wz(x):  # bowed plan: widest at the middle
        return hz * (1 - 0.1 * (x / hx) ** 2)

    def ridge(x):  # the ridge dips toward the ends, like an upturned boat
        return ridge_h - 1.3 * (x / (hx + 1.5)) ** 2

    base = 0.55
    # stone footing
    for side in (-1, 1):
        x = -hx
        while x <= hx:
            r = rng.uniform(0.45, 0.7)
            m.add(blob(r, shade(STONE, 0.15, rng), rng, 0, 0.3, 0.1, (1.2, 0.8, 1)), T(x, r * 0.6, side * (wz(x) + 0.1)))
            x += r * 1.6
        z = -wz(hx)
        while z <= wz(hx):
            r = rng.uniform(0.45, 0.7)
            m.add(blob(r, shade(STONE, 0.15, rng), rng, 0, 0.3, 0.1, (1, 0.8, 1.2)), T(side * (hx + 0.1), r * 0.6, z))
            z += r * 1.6
    # sill beams
    for side in (-1, 1):
        steps = 12
        for i in range(steps):
            x0, x1 = -hx + 2 * hx * i / steps, -hx + 2 * hx * (i + 1) / steps
            add_beam(m, (x0, base, side * wz(x0)), (x1, base, side * wz(x1)), 0.55, DARK)
    # long walls: vertical staves
    n = int(L / 0.85)
    door_w = 2.6
    for side in (-1, 1):
        for i in range(n):
            x = -hx + (i + 0.5) * (2 * hx / n)
            if side == -1 and abs(x) < door_w / 2 + 0.25:
                continue
            z = side * wz(x)
            slope = -side * 0.2 * hz * 2 * x / hx ** 2
            yaw = math.atan(slope)
            h = wall_h + rng.uniform(-0.1, 0.1)
            col = shade(WOOD if i % 3 else WEATHER, 0.1, rng)
            add_box(m, (x, base + h / 2, z), (2 * hx / n + 0.04, h, 0.36), col, RY(-yaw))
        # wall plate
        steps = 12
        for i in range(steps):
            x0, x1 = -hx + 2 * hx * i / steps, -hx + 2 * hx * (i + 1) / steps
            add_beam(m, (x0, base + wall_h, side * wz(x0)), (x1, base + wall_h, side * wz(x1)), 0.5, DARK)

    eave_y = base + wall_h - 0.9
    over = 1.7  # eave overhang past the wall

    def roof_point(x, v, s):
        """v = 0 at the ridge, 1 at the eave; s = side."""
        w = wz(min(abs(x), hx)) + over
        y = ridge(x) + (eave_y - ridge(x)) * v + 0.55 * math.sin(math.pi * v)  # slightly bellied
        return V(x, y, s * w * v ** 0.95)

    # gable end walls: staves up to the roof line
    for e in (-1, 1):
        x = e * hx
        k = int(2 * wz(hx) / 0.85)
        for j in range(k):
            z = -wz(hx) + (j + 0.5) * (2 * wz(hx) / k)
            v = abs(z) / (wz(hx) + over)
            top = ridge(x) + (eave_y - ridge(x)) * v + 0.55 * math.sin(math.pi * v) - 0.3
            col = shade(WOOD if j % 3 else WEATHER, 0.1, rng)
            add_box(m, (x, base + (top - base) / 2, z), (0.36, top - base, 2 * wz(hx) / k + 0.04), col)
        add_cyl(m, (x, 0, -wz(hx)), (x, base + wall_h + 0.3, -wz(hx)), 0.42, DARK, 7)
        add_cyl(m, (x, 0, wz(hx)), (x, base + wall_h + 0.3, wz(hx)), 0.42, DARK, 7)

    # the roof, course by course
    courses = 7
    nx = 18
    rcol = {"thatch": THATCH, "shingle": (92, 70, 52), "turf": TURF}[roof]
    for s in (-1, 1):
        for c in range(courses):
            v0, v1 = c / courses, (c + 1) / courses + 0.035
            xs = [(-hx - over) + (2 * (hx + over)) * i / nx for i in range(nx + 1)]
            a = [roof_point(x, v0, s) for x in xs]
            b = [roof_point(x, min(v1, 1.03), s) - V(0, 0.18, 0) for x in xs]
            col = shade(rcol, 0.07, rng)
            m.add(slab_between(a, b, 0.42 if roof == "thatch" else 0.3, col, rng, 0.06))
        # moss creeping over the lower thatch
        if roof in ("thatch", "turf"):
            for _ in range(int(L / 3)):
                x = rng.uniform(-hx, hx)
                v = rng.uniform(0.45, 0.95)
                p = roof_point(x, v, s) + V(0, 0.32, 0)
                m.add(blob(rng.uniform(0.6, 1.2), shade(MOSS, 0.12, rng), rng, 0, 0.3, 0.1, (1.6, 0.25, 1.2)), T(*p))
    # gable ends of the roof: a closing board so it reads solid from the side
    for e in (-1, 1):
        x = e * (hx + over)
        for s in (-1, 1):
            pts = [roof_point(x, i / 10, s) for i in range(11)]
            inner = [p - V(e * 0.05, 0.42, 0) for p in pts]
            m.add(slab_between(pts, inner, 0.2, DARK))
    # ridge log
    seg = 14
    for i in range(seg):
        x0, x1 = (-hx - over) + (2 * (hx + over)) * i / seg, (-hx - over) + (2 * (hx + over)) * (i + 1) / seg
        add_cyl(m, (x0, ridge(x0) + 0.35, 0), (x1, ridge(x1) + 0.35, 0), 0.38, DARK, 6)
    # smoke hole
    add_box(m, (0, ridge(0) + 0.7, 0), (2.2, 0.7, 1.8), TAR)
    add_box(m, (0, ridge(0) + 1.2, 0), (2.6, 0.18, 2.3), (80, 60, 44))

    # crossed barge boards with dragon heads on each gable
    if dragons:
        for e in (-1, 1):
            x = e * (hx + over + 0.15)
            for s in (-1, 1):
                pts = [roof_point(x, 1 - i / 10, s) + V(0, 0.35, 0) for i in range(11)]
                # carry on past the ridge and curl up into a head
                top = pts[-1]
                pts += [top + V(0, 0.9, -s * 0.9), top + V(0, 2.0, -s * 1.3)]
                inner = [p - V(0, 0.55, 0) for p in pts]
                m.add(slab_between(pts, inner, 0.25, RED if roof == "shingle" else DARK, rng, 0.05, up=(e, 0, 0)))
                h = pts[-1]
                head = [h + V(0, 0, 0), h + V(0, 0.35, -s * 0.9), h + V(0, -0.15, -s * 1.1), h + V(0.18, 0.2, -s * 0.3), h + V(-0.18, 0.2, -s * 0.3), h + V(0.15, -0.3, -s * 0.2), h + V(-0.15, -0.3, -s * 0.2)]
                m.add(hull(head, GOLD if roof == "shingle" else WEATHER))

    # slanted outer posts propping the walls
    if buttress:
        k = max(3, int(L / 5))
        for side in (-1, 1):
            for i in range(k):
                x = -hx + 1.2 + (2 * hx - 2.4) * i / (k - 1)
                if side == -1 and abs(x) < door_w:
                    continue
                z = side * wz(x)
                add_cyl(m, (x, 0, z + side * 1.5), (x, base + wall_h - 0.2, z + side * 0.25), 0.26, shade(DARK, 0.1, rng), 6)

    # the door: frame, plank door, iron straps, threshold stone
    dz = -wz(0) - 0.05
    add_box(m, (0, base + 2.2, dz + 0.05), (door_w, 4.4, 0.25), TAR)
    for x in (-door_w / 2 - 0.25, door_w / 2 + 0.25):
        add_box(m, (x, base + 2.5, dz), (0.5, 5.0, 0.55), DARK)
    add_box(m, (0, base + 5.0, dz - 0.05), (door_w + 1.4, 0.55, 0.6), DARK)
    for y in (1.2, 3.4):
        add_box(m, (0.1, base + y, dz - 0.12), (door_w - 0.4, 0.18, 0.06), IRON)
    add_box(m, (0, 0.2, dz - 0.9), (door_w + 0.8, 0.4, 1.3), STONE, bevel=0.12)
    if porch:
        for x in (-door_w / 2 - 0.9, door_w / 2 + 0.9):
            add_cyl(m, (x, 0, dz - 2.6), (x, base + 5.4, dz - 2.6), 0.3, DARK, 7)
        for s in (-1, 1):
            a = [V(x, base + 7.3, dz - 0.4) for x in (0, 0)]
            add_box(m, (s * 1.25, base + 6.4, dz - 1.6), (2.9, 0.25, 3.6), (92, 70, 52), RZ(s * -0.6))

    # shields hung along the front wall
    cols = [(RED, CREAM), (BLUE, CREAM), (GOLD, TAR), (CREAM, RED)]
    xs = [x for x in np.linspace(-hx + 2.2, hx - 2.2, max(2, int(L / 6))) if abs(x) > door_w + 0.8]
    for i, x in enumerate(xs):
        a, b = cols[i % len(cols)]
        disc(m, (x, base + wall_h - 1.3, -wz(x) - 0.3), (0, 0, -1), 0.95, a, IRON, IRON, paint=b)
    return m


def cottage():
    """An A-frame with a turf roof sweeping to the ground, door in the gable (-Z)."""
    m = Mesh(7)
    rng = m.rng
    hx, hz = 6.9, 6.6  # roof foot (x) and half-length (z)
    ridge = 11.0
    foot = 0.7

    def roof_pt(z, v, s):  # v 0 ridge .. 1 foot
        y = ridge + (foot - ridge) * v + 0.25 * math.sin(math.pi * v)
        return V(s * hx * v, y, z)

    # stone footing along the roof feet
    for s in (-1, 1):
        z = -hz
        while z <= hz:
            r = rng.uniform(0.45, 0.65)
            m.add(blob(r, shade(STONE, 0.15, rng), rng, 0, 0.3, 0.1, (1.1, 0.8, 1.3)), T(s * (hx - 0.4), r * 0.55, z))
            z += r * 1.6
    # roof: turf on boards
    nz = 10
    zs = [-hz - 0.6 + (2 * hz + 1.2) * i / nz for i in range(nz + 1)]
    for s in (-1, 1):
        boards = [roof_pt(z, 0, s) for z in zs]
        eave = [roof_pt(z, 1, s) for z in zs]
        m.add(slab_between(boards, eave, 0.25, DARK))
        for c in range(5):
            v0, v1 = c / 5, (c + 1) / 5 + 0.03
            a = [roof_pt(z, v0, s) + V(0, 0.45, 0) for z in zs]
            b = [roof_pt(z, v1, s) + V(0, 0.35, 0) for z in zs]
            m.add(slab_between(a, b, 0.45, shade(TURF, 0.08, rng), rng, 0.1))
        for _ in range(9):
            z = rng.uniform(-hz, hz)
            p = roof_pt(z, rng.uniform(0.15, 0.9), s) + V(0, 0.75, 0)
            m.add(blob(rng.uniform(0.4, 0.8), shade((96, 124, 58), 0.15, rng), rng, 0, 0.35, 0.1, (1, 0.5, 1)), T(*p))
        # a few wildflowers
        for _ in range(6):
            z = rng.uniform(-hz, hz)
            p = roof_pt(z, rng.uniform(0.2, 0.8), s) + V(0, 0.85, 0)
            add_box(m, p, (0.25, 0.25, 0.25), rng.choice([(230, 210, 90), (220, 220, 230), (170, 90, 140)]))
    # ridge pole
    add_cyl(m, (0, ridge + 0.6, -hz - 0.8), (0, ridge + 0.6, hz + 0.8), 0.35, DARK, 6)
    # gable walls: staves following the A
    for e, door in ((-1, True), (1, False)):
        z = e * (hz - 0.6)
        k = 14
        for j in range(k):
            x = -hx + 0.4 + (j + 0.5) * ((2 * hx - 0.8) / k)
            v = abs(x) / hx
            top = ridge + (foot - ridge) * v + 0.25 * math.sin(math.pi * v) - 0.2
            if door and abs(x) < 1.2:
                continue
            add_box(m, (x, top / 2, z), ((2 * hx - 0.8) / k + 0.03, top, 0.3), shade(WOOD if j % 3 else WEATHER, 0.1, rng))
        if door:
            add_box(m, (0, 2.2, z + 0.05), (2.4, 4.4, 0.2), TAR)
            add_box(m, (0, 2.1, z - 0.1), (2.0, 4.2, 0.2), shade(DARK, 0.05, rng))
            for y in (1.1, 3.2):
                add_box(m, (0, y, z - 0.22), (1.7, 0.15, 0.05), IRON)
            add_box(m, (0, 4.6, z - 0.15), (3.4, 0.45, 0.5), DARK)
            add_box(m, (0, 0.2, z - 0.9), (2.8, 0.4, 1.2), STONE, bevel=0.1)
            # a little window above the door
            add_box(m, (0, 6.6, z - 0.1), (1.2, 0.9, 0.2), (40, 30, 24))
            add_box(m, (0, 6.6, z - 0.2), (1.5, 0.15, 0.1), DARK)
        # crossed gable boards
        zz = e * (hz + 0.9)
        for s in (-1, 1):
            pts = [V(s * hx * (1 - i / 10), ridge + (foot - ridge) * (1 - i / 10) + 0.25 * math.sin(math.pi * (1 - i / 10)) + 0.4, zz) for i in range(11)]
            pts += [pts[-1] + V(-s * 0.8, 0.8, 0), pts[-1] + V(-s * 1.1, 1.7, 0)]
            m.add(slab_between(pts, [p - V(0, 0.45, 0) for p in pts], 0.2, DARK, up=(0, 0, e)))
    # woodpile against the side and a chopping block
    for i in range(4):
        add_cyl(m, (-hx - 0.6, 0.35 + i * 0.0, -3 + i * 0.75), (-hx - 0.6, 0.35, -3 + i * 0.75 + 0.01), 0.35, WOOD, 6)
    for i in range(5):
        add_cyl(m, (-hx - 1.6, 0.35, -3.4 + i * 0.68), (-hx + 0.4, 0.35, -3.4 + i * 0.68), 0.32, shade(WOOD, 0.12, rng), 6)
    for i in range(4):
        add_cyl(m, (-hx - 1.5, 0.95, -3.1 + i * 0.68), (-hx + 0.3, 0.95, -3.1 + i * 0.68), 0.32, shade(WOOD, 0.12, rng), 6)
    add_cyl(m, (2.6, 0, -hz - 2.2), (2.6, 1.0, -hz - 2.2), 0.6, WEATHER, 9)
    return m


def watchtower():
    m = Mesh(11)
    rng = m.rng
    h = 14
    hw = 5.6
    legs = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    for sx, sz in legs:
        add_cyl(m, (sx * (hw + 0.6), 0, sz * (hw + 0.6)), (sx * hw, h + 4.2, sz * hw), 0.55, shade(DARK, 0.08, rng), 8, 0.45, noise=0.05)
        m.add(blob(1.0, STONE, rng, 0, 0.3, 0.1, (1.2, 0.6, 1.2)), T(sx * (hw + 0.6), 0.3, sz * (hw + 0.6)))
    # X braces on every face, two storeys
    for y0, y1 in ((1.2, 7.2), (7.2, 13.2)):
        def at(sx, sz, y):
            k = y / (h + 4.2)
            return (sx * (hw + 0.6 - 0.6 * k), y, sz * (hw + 0.6 - 0.6 * k))

        for (a, b) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
            add_cyl(m, at(*a, y0), at(*b, y1), 0.2, WOOD, 5)
            add_cyl(m, at(*b, y0), at(*a, y1), 0.2, WOOD, 5)
            add_cyl(m, at(*a, y0), at(*b, y0), 0.24, DARK, 5)
    # deck of planks
    k = 13
    for i in range(k):
        x = -7.5 + (i + 0.5) * (15 / k)
        add_box(m, (x, h, 0), (15 / k - 0.06, 0.35, 15), shade(WOOD, 0.1, rng))
    for sz in (-1, 1):
        add_box(m, (0, h - 0.4, sz * 7.2), (15.2, 0.5, 0.5), DARK)
    # railing: posts, rails and a shield on each side
    for side in (-1, 1):
        for i in range(7):
            t = -7.2 + i * 2.4
            add_box(m, (t, h + 1.0, side * 7.3), (0.3, 1.9, 0.3), DARK)
            add_box(m, (side * 7.3, h + 1.0, t), (0.3, 1.9, 0.3), DARK)
        add_box(m, (0, h + 1.9, side * 7.3), (14.9, 0.3, 0.35), WOOD)
        add_box(m, (side * 7.3, h + 1.9, 0), (0.35, 0.3, 14.9), WOOD)
        add_box(m, (0, h + 0.9, side * 7.3), (14.9, 0.2, 0.25), WOOD)
        add_box(m, (side * 7.3, h + 0.9, 0), (0.25, 0.2, 14.9), WOOD)
    disc(m, (3, h + 1.1, -7.6), (0, 0, -1), 1.0, RED, IRON, IRON, paint=CREAM)
    disc(m, (7.6, h + 1.1, -2), (1, 0, 0), 1.0, BLUE, IRON, IRON, paint=CREAM)
    # roof: four-sided shingle cap with a finial
    peak = h + 7.6
    eave = h + 4.0
    pts = [V(0, peak, 0)]
    corners = [V(-8.2, eave, -8.2), V(8.2, eave, -8.2), V(8.2, eave, 8.2), V(-8.2, eave, 8.2)]
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        for r in range(4):
            t0, t1 = r / 4, (r + 1) / 4 + 0.05
            p0 = [pts[0] + (a - pts[0]) * t0, pts[0] + (b - pts[0]) * t0]
            p1 = [pts[0] + (a - pts[0]) * t1 - V(0, 0.12, 0), pts[0] + (b - pts[0]) * t1 - V(0, 0.12, 0)]
            m.add(slab_between(p0, p1, 0.3, shade((92, 70, 52), 0.08, rng), rng, 0.05))
    add_cyl(m, (0, peak - 0.3, 0), (0, peak + 1.6, 0), 0.25, DARK, 6)
    m.add(hull([V(0, peak + 1.6, 0), V(0, peak + 2.2, -0.9), V(0.15, peak + 1.9, -0.2), V(-0.15, peak + 1.9, -0.2), V(0, peak + 1.4, -0.1)], GOLD))
    # ladder up the front
    for x in (-0.9, 0.9):
        add_cyl(m, (x, 0, -hw - 1.6), (x, h + 0.2, -hw - 0.7), 0.16, WOOD, 5)
    for y in np.arange(1, h - 0.5, 1.3):
        z = -hw - 1.6 + 0.9 * (y / h)
        add_cyl(m, (-0.9, y, z), (0.9, y, z), 0.11, DARK, 5)
    # a horn hanging from a post
    m.add(lathe([(0.05, 0), (0.12, 0.5), (0.2, 0.9), (0.32, 1.2), (0.0, 1.21)], 8, CREAM), M(T(6.6, h + 2.6, -7.6), RZ(1.9)))
    return m


def palisade():
    m = Mesh(13)
    rng = m.rng
    n = 5
    w = 8
    for i in range(n):
        x = -w / 2 + (i + 0.5) * (w / n)
        h = 8 + ((i * 37) % 7) / 6 + rng.uniform(-0.2, 0.2)
        r = 0.78
        col = shade(WOOD if i % 2 else WEATHER, 0.06, rng)
        prof = [(r * 1.02, 0), (r, h * 0.6), (r * 0.97, h - 1.2), (r * 0.45, h - 0.5), (0.0, h + 0.4)]
        tris = lathe(prof, 9, col, rng, 0.08, 0.06, phase=rng.uniform(0, 1))
        # pale freshly cut point
        tris = [(a, b, c, (178, 148, 104) if (a[1] + b[1] + c[1]) / 3 > h - 1.25 else cc) for a, b, c, cc in tris]
        m.add(tris, M(T(x, 0, 0), RZ(rng.uniform(-0.03, 0.03))))
    for y in (3, 6):
        add_box(m, (0, y, 0.85), (w, 0.5, 0.4), DARK, vary=0.05)
        for i in range(n):
            x = -w / 2 + (i + 0.5) * (w / n)
            add_cyl(m, (x - 0.25, y, 0.9), (x + 0.25, y, 0.9), 0.32, (150, 130, 90), 6)  # rope lashing
    return m


def storehouse():
    """A stabbur: a storehouse on stout posts with mushroom stones, door at -Z."""
    m = Mesh(17)
    rng = m.rng
    hx, hz = 6.2, 9.6
    for x in (-hx + 0.8, 0, hx - 0.8):
        for z in (-hz + 0.8, 0, hz - 0.8):
            add_cyl(m, (x, 0, z), (x, 1.8, z), 0.5, DARK, 8)
            m.add(lathe([(0.3, 1.8), (1.0, 2.0), (1.1, 2.3), (0.0, 2.35)], 9, STONE), T(x, 0, z))
    add_box(m, (0, 2.6, 0), (2 * hx + 0.4, 0.6, 2 * hz + 0.4), DARK)
    # log walls with notched corners
    for i in range(8):
        y = 3.2 + i * 0.75
        for s in (-1, 1):
            add_cyl(m, (-hx - 0.5, y, s * hz), (hx + 0.5, y, s * hz), 0.4, shade(WOOD, 0.1, rng), 7)
            add_cyl(m, (s * hx, y + 0.37, -hz - 0.5), (s * hx, y + 0.37, hz + 0.5), 0.4, shade(WOOD, 0.1, rng), 7)
    wall_top = 3.2 + 8 * 0.75
    # gable fill and roof (ridge along Z)
    ridge = wall_top + 4.6
    for e in (-1, 1):
        z = e * hz
        k = 12
        for j in range(k):
            x = -hx + (j + 0.5) * (2 * hx / k)
            top = ridge - (ridge - wall_top) * abs(x) / hx
            add_box(m, (x, (wall_top + top) / 2, z), (2 * hx / k + 0.03, top - wall_top, 0.3), shade(WEATHER, 0.08, rng))
    zs = [-hz - 1.4 + (2 * hz + 2.8) * i / 10 for i in range(11)]
    for s in (-1, 1):
        for c in range(5):
            v0, v1 = c / 5, (c + 1) / 5 + 0.04
            a = [V(s * (hx + 1.6) * v0, ridge + (wall_top - 0.8 - ridge) * v0 + 0.3, z) for z in zs]
            b = [V(s * (hx + 1.6) * v1, ridge + (wall_top - 0.8 - ridge) * v1 + 0.15, z) for z in zs]
            m.add(slab_between(a, b, 0.3, shade((92, 70, 52), 0.07, rng), rng, 0.06))
    add_cyl(m, (0, ridge + 0.45, -hz - 1.5), (0, ridge + 0.45, hz + 1.5), 0.3, DARK, 6)
    # door, steps up to it
    dz = -hz - 0.45
    add_box(m, (0, 5.4, dz), (2.4, 4.0, 0.25), TAR)
    add_box(m, (0, 5.4, dz - 0.15), (2.0, 3.8, 0.2), DARK)
    for y in (4.4, 6.4):
        add_box(m, (0, y, dz - 0.3), (1.7, 0.15, 0.05), IRON)
    for i in range(4):
        add_box(m, (0, 0.35 + i * 0.65, dz - 3.2 + i * 0.75), (2.6, 0.3, 0.8), shade(WOOD, 0.08, rng))
    for x in (-1.4, 1.4):
        add_beam(m, (x, 0, dz - 3.7), (x, 3.0, dz - 0.6), 0.3, DARK)
    # sacks and a barrel by the steps
    for p in ((2.4, 0.6, dz - 1.2), (3.3, 0.55, dz - 1.6)):
        m.add(blob(0.65, (168, 150, 112), rng, 1, 0.12, 0.05, (1, 1.2, 1)), T(*p))
    return m


def fishery():
    """A net shed by the water, a rack of drying fish, and a boat pulled up beside it."""
    m = Mesh(41)
    shed = hall(L=9.5, D=7.5, wall_h=3.4, ridge_h=8.0, roof="thatch", seed=41, dragons=False, buttress=False)
    m.add(shed.tris, T(-3.0, 0, 3.0))
    rack = prop_fishrack()
    m.add(rack.tris, M(T(3.6, 0, -4.2), RY(math.pi / 2)))
    boat = prop_boat_upturned()
    m.add(boat.tris, M(T(4.6, 0, 3.6), RY(0.12)))
    # a net hung over a pole
    add_cyl(m, (-6.5, 2.8, -2.2), (0.5, 2.8, -2.2), 0.12, DARK, 6)
    add_box(m, (-3.0, 1.9, -2.25), (6.6, 1.8, 0.06), (96, 88, 70))
    return m


def brewhouse():
    """A smoky little brew hall, a copper vat on a fire, barrels and beehive skeps."""
    m = Mesh(43)
    shed = hall(L=10.5, D=8.0, wall_h=3.6, ridge_h=8.6, roof="thatch", seed=43, dragons=False, buttress=False)
    m.add(shed.tris, T(-1.6, 0, 2.6))
    # the vat: a round copper kettle on stones over the fire
    for k in range(6):
        a = k / 6 * math.tau
        m.add(blob(0.5, STONE, m.rng, 1, 0.15, 0.05, (1, 0.7, 1)), T(4.4 + math.cos(a) * 1.3, 0.3, -4.4 + math.sin(a) * 1.3))
    m.add(lathe([(0.0, 0.7), (1.1, 0.8), (1.5, 1.4), (1.6, 2.4), (1.45, 2.9), (1.55, 3.0), (0.0, 3.0)], 14, (176, 110, 64)), T(4.4, 0, -4.4))
    barrels = prop_barrels()
    m.add(barrels.tris, M(T(-5.2, 0, -4.4), RY(0.4)))
    # straw beehive skeps on a bench
    add_box(m, (-5.8, 0.8, 7.2), (3.6, 0.25, 1.0), WOOD)
    for x in (-6.9, -5.8, -4.7):
        m.add(lathe([(0.6, 0.0), (0.62, 0.4), (0.5, 0.8), (0.28, 1.05), (0.0, 1.12)], 10, THATCH), T(x, 0.92, 7.2))
    return m


# ----------------------------------------------------------------------------- nature


def spruce(seed=3, height=26):
    m = Mesh(seed)
    rng = m.rng
    add_cyl(m, (0, 0, 0), (0, height * 0.97, 0), 0.75, (80, 58, 42), 8, 0.08, noise=0.06)
    # root flare
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
        add_cyl(m, (0, 0.9, 0), (math.cos(a) * 1.5, 0.0, math.sin(a) * 1.5), 0.35, (74, 54, 40), 5, 0.12)
    tiers = 11
    for t in range(tiers):
        k = t / (tiers - 1)
        y = height * (0.16 + 0.8 * k)
        reach = (1 - k) ** 0.95 * height * 0.24 + 0.7
        nb = max(5, int(9 - 4 * k))
        for b in range(nb):
            a = b / nb * math.tau + t * 0.7 + rng.uniform(-0.25, 0.25)
            d = V(math.cos(a), 0, math.sin(a))
            side = V(-d[2], 0, d[0])
            droop = reach * 0.45
            root = V(0, y + 0.5, 0)
            tip = root + d * reach - V(0, droop, 0)
            mid = root + d * reach * 0.55 - V(0, droop * 0.25, 0)
            wdt = reach * 0.42
            pts = [root + V(0, 0.4, 0), root - V(0, 0.9, 0), tip, tip - V(0, 0.35, 0), mid + side * wdt, mid - side * wdt, mid + side * wdt * 0.8 - V(0, 0.7, 0), mid - side * wdt * 0.8 - V(0, 0.7, 0)]
            base = mix((30, 58, 40), (56, 88, 54), k * 0.6 + rng.uniform(0, 0.25))
            tris = hull(pts, base, rng, 0.08)
            # sunlit tops, darker undersides
            m.add([(p, q, r, mix(c, (0, 0, 0), 0.25) if np.cross(q - p, r - p)[1] < 0 else c) for p, q, r, c in tris])
    m.add(hull([V(0, height + 1.6, 0), V(0.5, height - 0.8, 0), V(-0.5, height - 0.8, 0), V(0, height - 0.8, 0.5), V(0, height - 0.8, -0.5)], (50, 84, 52)))
    return m


def pine(seed=5, height=24):
    """A Scots pine: tall bare trunk, orange upper bark, flat-topped canopy clumps."""
    m = Mesh(seed)
    rng = m.rng
    lean = V(rng.uniform(-0.6, 0.6), 0, rng.uniform(-0.6, 0.6))
    pts = [V(0, 0, 0)]
    for i in range(1, 7):
        k = i / 6
        pts.append(V(0, height * 0.78 * k, 0) + lean * k ** 2 + V(rng.uniform(-0.2, 0.2), 0, rng.uniform(-0.2, 0.2)))
    for i in range(6):
        r0 = 0.85 * (1 - i / 7) + 0.18
        r1 = 0.85 * (1 - (i + 1) / 7) + 0.18
        col = mix((86, 62, 46), (168, 98, 58), i / 5)
        add_cyl(m, pts[i], pts[i + 1], r0, col, 8, r1, noise=0.05)
    for i in range(5):
        a = i / 5 * math.tau
        add_cyl(m, (0, 0.9, 0), (math.cos(a) * 1.4, 0, math.sin(a) * 1.4), 0.35, (74, 54, 40), 5, 0.1)
    top = pts[-1]
    clumps = 9
    for c in range(clumps):
        a = c / clumps * math.tau * 1.618 * 3
        y = height * (0.6 + 0.35 * rng.random())
        r = (1 - (y / height - 0.6) / 0.4) * height * 0.13 + 1.4
        tip = V(math.cos(a) * r, y, math.sin(a) * r) + lean
        start = top - V(0, height * 0.78 - y + 1.5, 0) * 0.5
        add_cyl(m, start, tip, 0.2, (110, 72, 48), 5, 0.1)
        size = rng.uniform(2.0, 3.0)
        m.add(blob(size, mix((40, 70, 44), (64, 96, 56), rng.random()), rng, 1, 0.28, 0.1, (1.2, 0.5, 1.2)), T(*(tip + V(0, 0.4, 0))))
    m.add(blob(3.0, (52, 84, 50), rng, 1, 0.25, 0.1, (1.3, 0.55, 1.3)), T(*(top + V(0, 1.0, 0))))
    recolour(m, lambda rgb, n, c: mix(rgb, (0, 0, 0), 0.22) if n[1] < -0.3 and c[1] > height * 0.5 else rgb)
    return m


def birch(seed=9, height=20):
    m = Mesh(seed)
    rng = m.rng
    bend = V(rng.uniform(-0.8, 0.8), 0, rng.uniform(-0.8, 0.8))
    pts = [V(0, 0, 0)]
    for i in range(1, 6):
        k = i / 5
        pts.append(V(0, height * 0.75 * k, 0) + bend * math.sin(k * 2.2))
    for i in range(5):
        r0 = 0.55 * (1 - i / 6) + 0.12
        r1 = 0.55 * (1 - (i + 1) / 6) + 0.12
        add_cyl(m, pts[i], pts[i + 1], r0, (224, 220, 208), 8, r1, noise=0.04)
        # dark lenticels and cracks
        for _ in range(4):
            t = rng.random()
            p = pts[i] + (pts[i + 1] - pts[i]) * t
            a = rng.uniform(0, math.tau)
            rr = r0 + (r1 - r0) * t
            add_box(m, p + V(math.cos(a) * rr, 0, math.sin(a) * rr), (0.5, 0.12, 0.5), (40, 38, 36), RY(-a))
    # the base is dark and rough
    add_cyl(m, (0, 0, 0), (0, 1.6, 0), 0.72, (70, 66, 60), 8, 0.6, noise=0.1)
    top = pts[-1]
    for c in range(9):
        a = c * 2.4
        y = height * rng.uniform(0.5, 0.92)
        r = rng.uniform(1.5, 3.6)
        start = pts[min(4, int(y / height * 6))]
        tip = V(math.cos(a) * r, y + 1, math.sin(a) * r) + bend
        add_cyl(m, start, tip, 0.15, (200, 196, 186), 5, 0.06)
        m.add(blob(rng.uniform(1.8, 2.6), mix((110, 148, 58), (150, 178, 76), rng.random()), rng, 1, 0.3, 0.1, (1, 0.8, 1)), T(*tip))
    m.add(blob(2.4, (128, 162, 64), rng, 1, 0.3, 0.1, (1, 0.9, 1)), T(*(top + V(0, 1.5, 0))))
    return m


def rock(seed=21):
    m = Mesh(seed)
    rng = m.rng
    m.add(blob(3.0, STONE, rng, 2, 0.16, 0.06, (1.25, 0.72, 1.0)), T(0, 1.4, 0))
    m.add(blob(1.9, (106, 108, 104), rng, 2, 0.18, 0.06, (1.1, 0.8, 1.0)), T(2.4, 0.9, 1.0))
    m.add(blob(1.3, (124, 120, 112), rng, 1, 0.2, 0.06, (1, 0.7, 1)), T(-2.6, 0.5, -0.9))
    # flatten the bottom onto the ground
    m.tris = [tuple(np.array([p[0], max(p[1], -0.15), p[2]]) for p in (a, b, c)) + (col,) for a, b, c, col in m.tris]
    # moss and lichen on top faces, darker bands underneath
    def tint(rgb, n, c):
        if n[1] > 0.75:
            return mix(rgb, (88, 112, 58), 0.65 + 0.2 * random.random())
        if n[1] > 0.45 and random.random() < 0.35:
            return mix(rgb, (196, 186, 120), 0.4)  # lichen
        if n[1] < -0.2:
            return mix(rgb, (0, 0, 0), 0.25)
        return rgb

    random.seed(seed)
    recolour(m, tint)
    return m


def bush(seed=31):
    m = Mesh(seed)
    rng = m.rng
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 1.2)
        s = rng.uniform(0.9, 1.4)
        m.add(blob(s, mix((52, 86, 44), (84, 116, 54), rng.random()), rng, 1, 0.3, 0.12, (1, 0.8, 1)), T(math.cos(a) * r, s * 0.75, math.sin(a) * r))
    for _ in range(10):
        a = rng.uniform(0, math.tau)
        add_box(m, (math.cos(a) * 1.5, rng.uniform(0.8, 1.8), math.sin(a) * 1.5), (0.22, 0.22, 0.22), (176, 32, 40))
    return m


# ----------------------------------------------------------------------------- longship


def hull_sections(L, beam, depth, sheer_rise, strakes=7, stations=22):
    """Point grid [station][strake] for one side of a clinker hull (x >= 0)."""
    grid = []
    for i in range(stations + 1):
        t = i / stations
        e = abs(2 * t - 1)
        b = beam / 2 * max(0.0, 1 - e ** 2) ** 0.85
        top = 1.0 + sheer_rise * e ** 3
        bottom = -depth + (depth + 0.6) * e ** 4
        z = -L / 2 + L * t
        row = []
        for j in range(strakes + 1):
            s = j / strakes
            x = b * math.sin(s * math.pi / 2) ** 0.8
            y = bottom + (top - bottom) * (1 - math.cos(s * math.pi / 2)) ** 0.9
            row.append(V(x, y, z))
        grid.append(row)
    return grid


def add_hull(m, L, beam, depth, sheer_rise, colours=(HULL, (84, 58, 40)), inner=(70, 50, 36)):
    grid = hull_sections(L, beam, depth, sheer_rise)
    st = len(grid[0]) - 1
    for side in (1, -1):
        for j in range(st):
            col = colours[j % 2]
            a = [V(side * p[0], p[1], p[2]) for p in (row[j] for row in grid)]
            b = [V(side * p[0], p[1], p[2]) for p in (row[j + 1] for row in grid)]
            # clinker: each plank's lower edge stands proud of the one below
            b_out = [p + V(side * 0.07, -0.05, 0) for p in b]
            for i in range(len(a) - 1):
                c = shade(col, 0.05, m.rng)
                q = (a[i], a[i + 1], b_out[i + 1], b_out[i])
                n = np.cross(q[1] - q[0], q[2] - q[0])
                if np.dot(n, V(side, 0, 0)) < 0:
                    q = (q[0], q[3], q[2], q[1])
                m.tri(q[0], q[1], q[2], c)
                m.tri(q[0], q[2], q[3], c)
                # inside face
                m.tri(q[0], q[2], q[1], inner)
                m.tri(q[0], q[3], q[2], inner)
    return grid


def longship(L=44):
    m = Mesh(41)
    rng = m.rng
    beam = L * 0.2
    sheer = 2.6
    grid = add_hull(m, L, beam, 1.5, sheer)
    # gunwale rails
    for side in (1, -1):
        tops = [V(side * row[-1][0], row[-1][1] + 0.12, row[-1][2]) for row in grid]
        for i in range(len(tops) - 1):
            add_cyl(m, tops[i], tops[i + 1], 0.17, DARK, 5)
    # keel and stems curling up at bow and stern
    for e in (-1, 1):
        z0 = e * L / 2
        curve = []
        for k in range(10):
            a = k / 9 * math.pi * 0.95
            curve.append(V(0, 0.9 + sheer + math.sin(a) * 4.6 - 1.4, z0 + e * (math.sin(a * 0.5) * 1.6) - e * (1 - math.cos(a)) * 0.9))
        curve.insert(0, V(0, -0.6, z0 - e * 1.2))
        for i in range(len(curve) - 1):
            add_beam(m, curve[i], curve[i + 1], 0.45, DARK)
        tip = curve[-1]
        if e == -1:
            # dragon head looking forward (-Z)
            neck = tip
            hs = 1.6
            head = [neck + hs * V(0, 0.2, 0), neck + hs * V(0.45, 0.8, -0.3), neck + hs * V(-0.45, 0.8, -0.3), neck + hs * V(0.35, 1.3, -1.4), neck + hs * V(-0.35, 1.3, -1.4), neck + hs * V(0.25, 0.7, -2.2), neck + hs * V(-0.25, 0.7, -2.2), neck + hs * V(0, 1.1, -2.4), neck + hs * V(0, 1.6, -0.6)]
            m.add(hull(head, (104, 40, 30), rng, 0.05))
            jaw = [neck + hs * V(0.3, 0.5, -0.8), neck + hs * V(-0.3, 0.5, -0.8), neck + hs * V(0.2, 0.2, -2.0), neck + hs * V(-0.2, 0.2, -2.0), neck + hs * V(0, 0.0, -1.2)]
            m.add(hull(jaw, (90, 34, 26)))
            for s in (-1, 1):
                add_box(m, neck + hs * V(s * 0.42, 1.25, -1.2), (0.15, 0.25, 0.3), (240, 200, 90))
                add_cyl(m, neck + hs * V(s * 0.3, 1.5, -0.6), neck + hs * V(s * 0.5, 2.6, 0.2), 0.14, CREAM, 5, 0.03)
            # teeth
            for k in range(4):
                add_box(m, neck + hs * V(0, 0.55, -1.0 - k * 0.3), (0.5, 0.18, 0.08), CREAM)
        else:
            # stern curls into a spiral
            add_cyl(m, tip, tip + V(0, -0.5, -0.6), 0.25, DARK, 6)
            add_cyl(m, tip + V(0, -0.5, -0.6), tip + V(0, -1.0, -0.2), 0.2, DARK, 6)
    # deck boards
    k = 18
    for i in range(k):
        t = 0.12 + 0.76 * (i + 0.5) / k
        row = grid[int(t * (len(grid) - 1))]
        w = row[3][0] * 2
        add_box(m, (0, row[3][1] + 0.05, -L / 2 + L * t), (w, 0.18, L * 0.76 / k - 0.05), shade(WOOD, 0.08, rng))
    # rowing benches
    for i in range(7):
        t = 0.22 + 0.56 * i / 6
        row = grid[int(t * (len(grid) - 1))]
        add_box(m, (0, row[5][1], -L / 2 + L * t), (row[5][0] * 2, 0.3, 0.7), DARK)
    # shields along both gunwales
    cols = [(RED, CREAM), (GOLD, TAR), (BLUE, CREAM), (CREAM, RED), (TAR, GOLD)]
    for side in (1, -1):
        for i in range(10):
            t = 0.2 + 0.6 * i / 9
            row = grid[int(round(t * (len(grid) - 1)))]
            p = row[-1]
            a, b = cols[(i + (side > 0)) % len(cols)]
            disc(m, (side * (p[0] + 0.25), p[1] - 0.35, p[2]), (side, 0.15, 0), 0.85, a, IRON, IRON, seg=12, paint=b)
    # mast, yard and a striped sail billowing forward
    mast_h = 15.5
    add_cyl(m, (0, -0.8, 0), (0, mast_h, 0), 0.38, DARK, 8, 0.26)
    yard = mast_h - 1.6
    add_cyl(m, (-7.6, yard, -0.3), (7.6, yard, -0.3), 0.22, DARK, 6, 0.22)
    nx, ny = 12, 8
    sail = [[None] * (nx + 1) for _ in range(ny + 1)]
    for j in range(ny + 1):
        v = j / ny
        for i in range(nx + 1):
            u = i / nx
            w = 7.2 + 0.5 * v
            x = -w + 2 * w * u
            y = yard - 0.2 - v * 9.0
            z = -0.45 - 1.6 * math.sin(math.pi * u) * math.sin(math.pi * (0.15 + 0.85 * v)) ** 0.8
            sail[j][i] = V(x, y, z)
    for j in range(ny):
        for i in range(nx):
            stripe = RED if (i // 2) % 2 == 0 else CREAM
            c = shade(stripe, 0.03, rng)
            a, b, cc, d = sail[j][i], sail[j][i + 1], sail[j + 1][i + 1], sail[j + 1][i]
            m.tri(a, b, cc, c)
            m.tri(a, cc, d, c)
            m.tri(a, cc, b, c)
            m.tri(a, d, cc, c)
    # stays to bow and stern and sheets to the sides
    add_cyl(m, (0, mast_h, 0), (0, 2.4 + sheer, -L / 2 + 1.5), 0.06, (150, 130, 96), 4)
    add_cyl(m, (0, mast_h, 0), (0, 2.4 + sheer, L / 2 - 1.5), 0.06, (150, 130, 96), 4)
    for s in (-1, 1):
        add_cyl(m, sail[-1][0 if s < 0 else -1], (s * beam * 0.42, 1.2, 3.5), 0.05, (150, 130, 96), 4)
        add_cyl(m, (0, mast_h - 0.5, 0), (s * beam * 0.45, 1.3, 1.0), 0.05, (150, 130, 96), 4)
    # oars resting out through the side
    for side in (1, -1):
        for i in range(6):
            t = 0.25 + 0.5 * i / 5
            row = grid[int(round(t * (len(grid) - 1)))]
            p = row[-1]
            add_cyl(m, (side * (p[0] - 1.2), p[1] + 0.2, p[2]), (side * (p[0] + 5.5), -1.2, p[2] + 0.6), 0.09, WEATHER, 5)
            add_box(m, (side * (p[0] + 5.6), -1.25, p[2] + 0.62), (1.4, 0.06, 0.45), WEATHER, RZ(-side * 0.25))
    return m


def small_boat():
    m = Mesh(43)
    add_hull(m, 9, 3.2, 0.9, 0.8)
    return m


# ----------------------------------------------------------------------------- deer


def deer(seed=51):
    m = Mesh(seed)
    rng = m.rng
    coat = (142, 98, 60)
    m.add(blob(1.0, coat, rng, 2, 0.05, 0.03, (0.85, 0.9, 1.9)), T(0, 3.1, 0.1))
    m.add(blob(1.0, coat, rng, 1, 0.05, 0.03, (0.8, 0.85, 0.9)), T(0, 3.25, -1.2))  # chest
    m.add(blob(1.0, coat, rng, 1, 0.05, 0.03, (0.8, 0.85, 0.8)), T(0, 3.2, 1.4))  # haunch
    # neck and head
    add_cyl(m, (0, 3.4, -1.5), (0, 5.0, -2.3), 0.5, coat, 8, 0.32)
    head = [V(0, 5.3, -2.2), V(0.33, 5.1, -2.3), V(-0.33, 5.1, -2.3), V(0.3, 4.7, -2.4), V(-0.3, 4.7, -2.4), V(0.14, 4.85, -3.45), V(-0.14, 4.85, -3.45), V(0.1, 4.55, -3.35), V(-0.1, 4.55, -3.35), V(0, 5.25, -2.7)]
    m.add(hull(head, coat, rng, 0.04))
    add_box(m, (0, 4.75, -3.48), (0.22, 0.18, 0.08), (30, 24, 22))  # nose
    for s in (-1, 1):
        add_box(m, (s * 0.25, 5.0, -2.75), (0.08, 0.12, 0.14), (20, 16, 14))  # eyes
        m.add(hull([V(s * 0.25, 5.25, -2.25), V(s * 0.7, 5.6, -2.15), V(s * 0.8, 5.5, -2.0), V(s * 0.3, 5.15, -2.1)], (128, 90, 58)))
        # antlers: a main beam with tines
        base = V(s * 0.18, 5.3, -2.35)
        p1 = base + V(s * 0.5, 0.9, 0.1)
        p2 = p1 + V(s * 0.4, 0.9, 0.3)
        p3 = p2 + V(s * 0.1, 0.7, 0.2)
        for a, b in ((base, p1), (p1, p2), (p2, p3)):
            add_cyl(m, a, b, 0.07, (222, 206, 178), 5, 0.06)
        for a in (p1, p2):
            add_cyl(m, a, a + V(0, 0.6, -0.4), 0.05, (222, 206, 178), 4, 0.02)
        add_cyl(m, p3, p3 + V(-s * 0.2, 0.4, -0.1), 0.05, (222, 206, 178), 4, 0.02)
    # legs with knees and hooves
    for x in (-0.45, 0.45):
        for z, back in ((-1.25, False), (1.45, True)):
            top = V(x, 2.9, z)
            knee = V(x, 1.4, z + (0.25 if back else -0.05))
            hoof = V(x, 0.15, z + (0.05 if back else 0.0))
            add_cyl(m, top, knee, 0.26 if back else 0.2, coat, 6, 0.13)
            add_cyl(m, knee, hoof, 0.12, (116, 82, 54), 6, 0.1)
            add_box(m, hoof - V(0, 0.08, 0.04), (0.22, 0.2, 0.3), (40, 32, 28))
    # tail and white rump
    m.add(blob(0.25, CREAM, rng, 0, 0.1, 0.02, (1, 1.6, 0.8)), T(0, 3.4, 2.75))
    recolour(m, lambda rgb, n, c: mix(rgb, (214, 196, 170), 0.6) if rgb == coat and n[1] < -0.55 else rgb)
    return m


# ----------------------------------------------------------------------------- tools (handle space)


def axe():
    m = Mesh(61)
    add_cyl(m, (0, -1.8, 0), (0, 1.95, 0), 0.13, (138, 100, 64), 8, 0.12)
    for y in np.arange(-1.7, -0.7, 0.22):
        add_cyl(m, (0, y, 0), (0, y + 0.16, 0), 0.155, LEATHER, 8)
    add_cyl(m, (0, -1.85, 0), (0, -1.65, 0), 0.17, IRON, 8)
    # bearded head: eye and neck, then a thin flaring blade
    t = 0.11
    neck = [V(x, y, z) for x in (-t, t) for (y, z) in ((1.15, 0.28), (1.75, 0.28), (1.12, -0.5), (1.68, -0.5))]
    m.add(hull(neck, IRON))
    blade = [V(x * f, y, z) for x in (-t, t) for (y, z, f) in ((1.12, -0.5, 0.8), (1.68, -0.5, 0.8), (2.0, -1.3, 0.3), (0.62, -1.2, 0.3), (1.1, -0.85, 0.6))]
    m.add(hull(blade, (98, 100, 104)))
    edge = [V(x, y, z) for x in (-0.035, 0.035) for (y, z) in ((2.02, -1.3), (0.6, -1.21), (2.05, -1.42), (0.5, -1.3))]
    m.add(hull(edge, STEEL))
    return m


def pickaxe():
    m = Mesh(62)
    add_cyl(m, (0, -1.8, 0), (0, 1.9, 0), 0.13, (138, 100, 64), 8, 0.12)
    for y in np.arange(-1.7, -0.8, 0.22):
        add_cyl(m, (0, y, 0), (0, y + 0.16, 0), 0.155, LEATHER, 8)
    add_box(m, (0, 1.6, 0), (0.34, 0.5, 0.5), IRON)
    for s in (-1, 1):
        pts = []
        for k in range(6):
            u = k / 5
            z = s * (0.25 + 1.3 * u)
            y = 1.62 - 0.5 * u ** 2
            pts.append((z, y, 0.17 * (1 - u) + 0.03, 0.2 * (1 - u) + 0.03))
        for (z0, y0, w0, h0), (z1, y1, w1, h1) in zip(pts, pts[1:]):
            m.add(hull([V(x, y0 + dy, z0) for x in (-w0, w0) for dy in (-h0, h0)] + [V(x, y1 + dy, z1) for x in (-w1, w1) for dy in (-h1, h1)], (98, 100, 104)))
        add_box(m, (0, pts[-1][1] - 0.02, s * 1.58), (0.08, 0.08, 0.1), STEEL)
    return m


def bow():
    m = Mesh(63)
    pts = []
    for k in range(13):
        u = -1 + 2 * k / 12
        y = 2.5 * u
        z = 0.75 * u ** 2
        pts.append(V(0, y, z))
    for a, b, k in zip(pts, pts[1:], range(12)):
        r = 0.16 - 0.08 * abs((k + 0.5) / 6 - 1)
        add_cyl(m, a, b, r, (110, 72, 44), 6, r)
    add_cyl(m, (0, -0.5, 0.02), (0, 0.5, 0.02), 0.19, LEATHER, 8)
    add_cyl(m, pts[0], pts[-1], 0.03, CREAM, 4)
    for p in (pts[0], pts[-1]):
        m.add(blob(0.1, (210, 200, 180), m.rng, 0, 0.1, 0.0), T(*p))
    return m


def sword():
    m = Mesh(64)
    # lobed pommel
    m.add(hull([V(x, y, z) for x in (-0.16, 0.16) for (y, z) in ((-0.62, -0.32), (-0.62, 0.32), (-0.95, 0), (-0.8, -0.24), (-0.8, 0.24))], (150, 120, 70)))
    add_cyl(m, (0, -0.62, 0), (0, 0.6, 0), 0.13, LEATHER, 8, 0.12)
    for y in np.arange(-0.5, 0.55, 0.2):
        add_cyl(m, (0, y, 0), (0, y + 0.05, 0), 0.14, (160, 130, 80), 8)
    # crossguard
    m.add(hull([V(x, y, z) for x in (-0.13, 0.13) for y in (0.6, 0.82) for z in (-0.8, 0.8)] + [V(0, 0.72, s * 0.9) for s in (-1, 1)], (150, 120, 70)))
    # blade with a diamond section and a darker fuller
    blade = []
    for (y, w) in ((0.82, 0.24), (3.7, 0.2), (4.35, 0.05)):
        blade += [V(0, y, w), V(0, y, -w), V(0.05, y, 0), V(-0.05, y, 0)]
    blade.append(V(0, 4.6, 0))
    m.add(hull(blade, STEEL))
    for s in (-1, 1):
        add_box(m, (s * 0.04, 2.3, 0), (0.02, 2.8, 0.08), (120, 126, 134))
    return m


def torch():
    m = Mesh(65)
    add_cyl(m, (0, -1.5, 0), (0, 1.35, 0), 0.15, (110, 76, 48), 7, 0.18)
    m.add(blob(0.36, (58, 44, 34), m.rng, 1, 0.15, 0.08, (1, 1.4, 1)), T(0, 1.45, 0))
    for y in (1.1, 1.3, 1.5):
        add_cyl(m, (0, y, 0), (0, y + 0.08, 0), 0.38, (150, 120, 86), 8)
    return m


# ----------------------------------------------------------------------------- props


def barrel_tris(rng, h=1.9, r=0.75, wood=(118, 82, 50)):
    prof = [(r * 0.86, 0), (r * 0.97, h * 0.25), (r, h * 0.5), (r * 0.97, h * 0.75), (r * 0.86, h)]
    tris = lathe(prof, 12, wood, rng, 0.08)
    hoops = []
    for y in (0.15, h * 0.32, h * 0.68, h - 0.15):
        k = 1 - abs(y / h - 0.5) * 0.28
        hoops += lathe([(r * k + 0.04, y - 0.06), (r * k + 0.04, y + 0.06)], 12, IRON)
    lid = [(a, b, c, (96, 66, 40)) for a, b, c, col in tris if abs(a[1] - h) < 1e-6 and abs(b[1] - h) < 1e-6 and abs(c[1] - h) < 1e-6]
    return tris + hoops + lid


def prop_barrels():
    m = Mesh(71)
    m.add(barrel_tris(m.rng), T(0, 0, 0))
    m.add(barrel_tris(m.rng), T(1.6, 0, 0.4))
    m.add(barrel_tris(m.rng), M(T(0.7, 0.75, -1.6), RZ(math.pi / 2), T(0, -0.95, 0)))
    add_box(m, (-1.8, 0.9, -0.6), (1.8, 1.8, 1.8), (128, 92, 58), RY(0.3), bevel=0.08)
    for y in (0.3, 1.5):
        add_box(m, (-1.8, y, -0.6), (1.86, 0.18, 1.86), DARK, RY(0.3))
    return m


def prop_cart():
    m = Mesh(72)
    rng = m.rng
    tilt = RX(math.radians(-6))
    for i in range(6):
        add_box(m, (0, 0, 0), (3.2, 0.3, 0.8), shade(WOOD, 0.1, rng), M(T(0, 2, -2.1 + i * 0.84), tilt))
    for x in (-1.6, 1.6):
        add_box(m, (0, 0, 0), (0.22, 0.9, 5.0), WEATHER, M(T(x, 2.55, 0), tilt))
        # spoked wheel
        c = V(x * 1.12, 1.5, 0.8)
        seg = 12
        for k in range(seg):
            a0, a1 = k / seg * math.tau, (k + 1) / seg * math.tau
            p0 = c + V(0, math.cos(a0) * 1.4, math.sin(a0) * 1.4)
            p1 = c + V(0, math.cos(a1) * 1.4, math.sin(a1) * 1.4)
            add_beam(m, p0, p1, 0.28, DARK)
        for k in range(6):
            a = k / 6 * math.tau
            add_cyl(m, c, c + V(0, math.cos(a) * 1.35, math.sin(a) * 1.35), 0.07, WOOD, 4)
        add_cyl(m, c - V(0.25, 0, 0), c + V(0.25, 0, 0), 0.28, IRON, 8)
    add_cyl(m, (-1.9, 1.5, 0.8), (1.9, 1.5, 0.8), 0.12, DARK, 6)
    for x in (-0.6, 0.6):
        add_cyl(m, (x, 1.75, -2.3), (x, 0.6, -6.4), 0.12, WOOD, 6)
    m.add(blob(1.6, THATCH, rng, 1, 0.25, 0.08, (0.9, 0.5, 1.2)), M(T(0, 2.9, 0.3), tilt))
    return m


def prop_haystack():
    m = Mesh(73)
    rng = m.rng
    prof = [(2.9, 0), (3.1, 1.0), (2.9, 2.4), (2.3, 3.8), (1.4, 5.0), (0.5, 5.8), (0.0, 6.1)]
    tris = lathe(prof, 14, THATCH, rng, 0.1, 0.07)
    m.add(tris)
    for y in (1.6, 3.2):
        k = 1 - y / 7
        m.add(lathe([(3.15 * k + 0.15, y), (3.1 * k + 0.15, y + 0.2)], 14, (150, 116, 62)))
    add_cyl(m, (0, 5.5, 0), (0, 7.0, 0), 0.15, WEATHER, 5)
    add_cyl(m, (2.6, 0, 1.6), (3.3, 4.0, 1.0), 0.07, WOOD, 4)
    for dz in (-0.12, 0, 0.12):
        add_cyl(m, (3.3, 4.0, 1.0 + dz), (3.4, 4.6, 0.9 + dz), 0.03, IRON, 3)
    return m


def prop_fishrack():
    m = Mesh(74)
    rng = m.rng
    for x in (-3, 3):
        add_cyl(m, (x, 0, -1.4), (x, 4.6, 0), 0.17, WEATHER, 5)
        add_cyl(m, (x, 0, 1.4), (x, 4.6, 0), 0.17, WEATHER, 5)
    add_cyl(m, (-3.5, 4.3, 0), (3.5, 4.3, 0), 0.14, DARK, 6)
    for i in range(10):
        x = -2.7 + i * 0.6
        for s in (-1, 1):
            ln = 1.6 + rng.uniform(-0.3, 0.3)
            top = 4.25
            pts = [V(x + dx, top - 0.05, s * 0.06) for dx in (-0.06, 0.06)] + [V(x, top - ln * 0.4, s * 0.16), V(x + 0.18, top - ln * 0.4, s * 0.08), V(x - 0.18, top - ln * 0.4, s * 0.08), V(x, top - ln, s * 0.08), V(x + 0.2, top - ln - 0.25, s * 0.06), V(x - 0.2, top - ln - 0.25, s * 0.06)]
            m.add(hull(pts, shade((190, 176, 150), 0.1, rng)))
    return m


def prop_woodpile():
    m = Mesh(75)
    rng = m.rng
    for row in range(3):
        for i in range(5 - row):
            z = (i - (4 - row) / 2) * 1.02
            y = 0.5 + row * 0.86
            ln = 5 + rng.uniform(-0.3, 0.3)
            dx = rng.uniform(-0.2, 0.2)
            tris, mat = cyl_between((dx - ln / 2, y, z), (dx + ln / 2, y, z), 0.5, shade(WOOD, 0.12, rng), 8)
            # pale end grain
            tris = [(a, b, c, (196, 160, 112) if abs(a[1] - b[1]) < 1e-6 and abs(b[1] - c[1]) < 1e-6 else col) for a, b, c, col in tris]
            m.add(tris, mat)
    for x in (-2.7, 2.7):
        for z in (-2.7, 2.7):
            add_cyl(m, (x, 0, z), (x, 3.3, z), 0.14, WEATHER, 5)
    add_box(m, (0, 3.45, 0), (6.4, 0.22, 6.4), (92, 70, 52), RZ(math.radians(8)))
    return m


def prop_banner():
    m = Mesh(76)
    add_cyl(m, (0, 0, 0), (0, 11, 0), 0.25, DARK, 7, 0.18)
    m.add(hull([V(0, 11.0, 0), V(0, 11.9, -0.3), V(0.1, 11.4, 0), V(-0.1, 11.4, 0)], GOLD))
    add_cyl(m, (-1.6, 10.4, 0), (1.6, 10.4, 0), 0.13, DARK, 6)
    nx, ny = 6, 8
    grid = []
    for j in range(ny + 1):
        v = j / ny
        row = []
        for i in range(nx + 1):
            u = i / nx
            x = -1.4 + 2.8 * u
            row.append(V(x, 10.2 - v * 5.0, 0.18 * math.sin(u * math.pi * 2 + v * 2) * v))
        grid.append(row)
    for j in range(ny):
        m.add(strip_between(grid[j], grid[j + 1], RED, m.rng, 0.03))
    for i in range(3):
        x = -1.4 + 0.93 * i
        tip = V(x + 0.47, 4.4, 0.1)
        m.add(strip_between([V(x, 5.2, 0.1), V(x + 0.93, 5.2, 0.1)], [tip, tip], RED))
    # a raven emblem in gold
    em = [V(0, 8.6, -0.06), V(-0.9, 8.2, -0.06), V(0.9, 8.2, -0.06), V(0, 7.3, -0.06), V(0.3, 8.9, -0.06), V(-0.3, 8.9, -0.06)]
    m.add(strip_between([em[1], em[5], em[4]], [em[3], em[0], em[2]], GOLD))
    return m


def prop_boat_upturned():
    m = Mesh(77)
    for z in (-2, 2):
        add_box(m, (0, 0.7, z), (3.4, 0.3, 0.4), WEATHER)
        for x in (-1.4, 1.4):
            add_beam(m, (x, 0, z - 0.4), (x * 0.8, 0.6, z), 0.22, WEATHER)
            add_beam(m, (x, 0, z + 0.4), (x * 0.8, 0.6, z), 0.22, WEATHER)
    boat = Mesh(78)
    add_hull(boat, 9, 3.4, 0.9, 0.8)
    m.add(boat.tris, M(T(0, 1.95, 0), RZ(math.pi)))
    return m


# ----------------------------------------------------------------------------- work buildings


def log_pile(m, centre, along_x=True, rows=3, length=5.0):
    rng = m.rng
    cx, cy, cz = centre
    for row in range(rows):
        for i in range(rows + 1 - row):
            off = (i - (rows - row) / 2) * 1.0
            y = cy + 0.5 + row * 0.85
            if along_x:
                p, q = (cx - length / 2, y, cz + off), (cx + length / 2, y, cz + off)
            else:
                p, q = (cx + off, y, cz - length / 2), (cx + off, y, cz + length / 2)
            tris, mat = cyl_between(p, q, 0.48, shade(WOOD, 0.12, rng), 8)
            tris = [(a, b, c, (196, 160, 112) if abs(np.dot(np.cross(b - a, c - a), V(0, 1, 0))) < 1e-6 and abs(a[1] - b[1]) + abs(b[1] - c[1]) < 1e-6 or False else col) for a, b, c, col in tris]
            m.add(tris, mat)


def wattle_fence(m, a, b, h=1.6):
    """Woven hazel fence from a to b (ground points)."""
    a, b = V(*a), V(*b)
    d = b - a
    ln = float(np.linalg.norm(d))
    n = max(2, int(ln / 2.2))
    for i in range(n + 1):
        p = a + d * (i / n)
        add_cyl(m, p, p + V(0, h + 0.3, 0), 0.12, WEATHER, 5)
    for k in range(4):
        y = 0.35 + k * (h - 0.3) / 3
        add_beam(m, a + V(0, y, 0), b + V(0, y, 0), 0.16, shade((140, 112, 76), 0.08, m.rng))


def small_hall(L, D, roof, seed):
    return hall(L=L, D=D, wall_h=3.4, ridge_h=8.0, roof=roof, seed=seed, dragons=False, buttress=False)


def farm():
    """Fenced field: furrows of dark soil (the crop rows stay the game's own,
    so they still change colour with the seasons), a field shed and a scarecrow."""
    m = Mesh(91)
    rng = m.rng
    w = 23
    add_box(m, (0, 0.08, 0), (w, 0.16, w), (92, 70, 50))
    for i in range(9):
        z = -w / 2 + 2.0 + i * (w - 4) / 8
        add_box(m, (0, 0.24, z), (w - 3, 0.18, 0.5), (74, 56, 40))
    h = w / 2
    wattle_fence(m, (-h, 0, -h), (-3, 0, -h))
    wattle_fence(m, (3, 0, -h), (h, 0, -h))
    wattle_fence(m, (h, 0, -h), (h, 0, h))
    wattle_fence(m, (h, 0, h), (-h, 0, h))
    wattle_fence(m, (-h, 0, h), (-h, 0, -h))
    # gate posts
    for x in (-3, 3):
        add_cyl(m, (x, 0, -h), (x, 2.6, -h), 0.22, DARK, 6)
    # scarecrow in a tunic and hat
    sx, sz = w / 4, w / 4 - 1
    add_cyl(m, (sx, 0, sz), (sx, 5.2, sz), 0.15, WOOD, 5)
    add_cyl(m, (sx - 1.6, 4.0, sz), (sx + 1.6, 4.0, sz), 0.12, WOOD, 5)
    m.add(hull([V(sx + x, y, sz + z) for x in (-0.7, 0.7) for y in (2.6, 4.2) for z in (-0.3, 0.3)] + [V(sx, 2.3, sz)], (120, 60, 50)))
    m.add(blob(0.55, THATCH, rng, 1, 0.15, 0.05), T(sx, 4.8, sz))
    m.add(lathe([(0.9, 0), (0.9, 0.08), (0.45, 0.2), (0.4, 0.6), (0.0, 0.62)], 10, (96, 70, 44)), T(sx, 5.0, sz))
    # a small field shed in the back corner with sacks and a cart wheel
    shed = small_hall(6.5, 5.0, "thatch", 92)
    m.add(shed.tris, M(T(-h + 4.2, 0, h - 3.4), RY(math.pi)))
    for p in ((-h + 7.6, 0.6, h - 1.5), (-h + 8.4, 0.55, h - 2.3)):
        m.add(blob(0.6, (168, 150, 112), rng, 1, 0.12, 0.05, (1, 1.2, 1)), T(*p))
    return m


def woodcutter():
    m = Mesh(93)
    rng = m.rng
    m.add(small_hall(9, 7, "shingle", 94).tris, T(-2, 0, 2.5))
    log_pile(m, (3, 0, -4.5))
    # chopping stump with an axe stuck in it
    add_cyl(m, (5, 0, 3), (5, 1.4, 3), 1.0, WEATHER, 10)
    m.add(lathe([(0.95, 1.4), (0.0, 1.41)], 10, (190, 152, 104)), T(0, 0, 0)) if False else None
    add_box(m, (5, 1.42, 3), (1.6, 0.04, 1.6), (190, 152, 104))
    add_cyl(m, (5, 1.4, 3), (5.9, 3.2, 3), 0.1, (138, 100, 64), 6)
    add_box(m, (5.15, 1.55, 3), (0.6, 0.5, 0.08), IRON, RZ(0.45))
    # sawhorse with a log
    for x in (-5.5, -3.5):
        add_beam(m, (x, 0, -3.2), (x, 1.6, -2.6), 0.18, DARK)
        add_beam(m, (x, 0, -2.0), (x, 1.6, -2.6), 0.18, DARK)
    add_cyl(m, (-6.5, 1.8, -2.6), (-2.5, 1.8, -2.6), 0.4, shade(WOOD, 0.1, rng), 8)
    # wood chips
    for _ in range(14):
        add_box(m, (5 + rng.uniform(-2, 2), 0.05, 3 + rng.uniform(-2, 2)), (0.3, 0.06, 0.15), (200, 170, 120), RY(rng.uniform(0, 3)))
    return m


def quarry():
    m = Mesh(95)
    rng = m.rng
    add_box(m, (0, 0.15, 0), (15, 0.3, 15), (110, 108, 104))
    # a rock face at the back, cut into steps
    for i, (x, z, r) in enumerate(((-3, 4.5, 3.2), (2.5, 5, 2.8), (5.5, 2.5, 2.0), (-5.5, 1, 2.2))):
        m.add(blob(r, shade(STONE, 0.1, rng), rng, 2, 0.12, 0.06, (1.1, 0.9, 0.8)), T(x, r * 0.7, z))
    for (x, y, z, sx, sy, sz) in ((-3, 0.8, -3, 3.2, 1.6, 2.2), (0.6, 0.5, -1.5, 2.2, 1.0, 1.4), (3.5, 0.7, -4, 2.6, 1.4, 1.8), (3.4, 2.1, -4, 1.6, 1.2, 1.4)):
        add_box(m, (x, y, z), (sx, sy, sz), shade((150, 146, 138), 0.06, rng), RY(rng.uniform(-0.2, 0.2)), bevel=0.08)
    # wedges, mallet and a sledge for hauling blocks
    for k in range(4):
        add_box(m, (-1.5 + k * 0.4, 1.7, -3), (0.12, 0.3, 0.3), IRON)
    add_box(m, (-6, 0.45, -5), (3.4, 0.3, 2.2), WEATHER)
    for x in (-7.6, -4.4):
        add_box(m, (x, 0.2, -5), (0.25, 0.4, 2.4), DARK)
    # lifting crane
    add_cyl(m, (5.5, 0, -5.5), (5.5, 8.2, -5.5), 0.35, DARK, 7)
    add_beam(m, (5.5, 7.8, -6.4), (5.5, 7.8, 1.2), 0.4, DARK)
    add_beam(m, (5.5, 3.5, -5.5), (5.5, 7.6, -3.2), 0.25, DARK)
    add_cyl(m, (5.5, 7.6, 0.6), (5.5, 4.0, 0.6), 0.05, (150, 130, 96), 4)
    add_box(m, (5.5, 3.4, 0.6), (1.2, 1.0, 1.2), (150, 146, 138), bevel=0.06)
    return m


def runestone(m, at, h, turn, seed=0):
    x, z = at
    rng = random.Random(seed)
    prof = [(1.2, 0), (1.25, h * 0.4), (1.1, h * 0.8), (0.6, h), (0.0, h + 0.1)]
    tris = lathe(prof, 8, (122, 122, 116), rng, 0.06, 0.08)
    m.add(tris, M(T(x, 0, z), RY(turn), np.diag([1, 1, 0.38, 1])))
    # a red-painted serpent band of runes winding up the face
    for k in range(9):
        t = k / 8
        y = 0.6 + t * (h - 1.6)
        xx = math.sin(t * math.pi * 1.5) * 0.7
        add_box(m, (0, 0, 0), (0.28, 0.28, 0.08), (168, 44, 38), M(T(x, 0, z), RY(turn), T(xx, y, -0.47)))


def lorehall():
    m = Mesh(97)
    m.add(hall(L=20, D=9.5, wall_h=4.0, ridge_h=10.0, roof="turf", seed=98, dragons=True, buttress=False).tris, T(0, 0, 2))
    runestone(m, (-6, -6), 5, 0.2, 1)
    runestone(m, (6, -6), 4.2, -0.25, 2)
    # carved story pole by the door
    add_cyl(m, (0, 0, -6.6), (0, 7.2, -6.6), 0.35, WEATHER, 8)
    for k in range(4):
        add_box(m, (0, 2 + k * 1.4, -6.95), (0.5, 0.9, 0.1), [(168, 44, 38), GOLD, BLUE, CREAM][k])
    m.add(hull([V(0, 7.2, -6.6), V(0.4, 7.8, -6.6), V(-0.4, 7.8, -6.6), V(0, 8.0, -7.3), V(0, 7.6, -6.1)], (168, 44, 38)))
    return m


def smithy():
    """An open forge shed. The glowing coals, fire and smoke come from the game,
    sitting on this forge at (-3, 3.1, 2.5)."""
    m = Mesh(99)
    rng = m.rng
    k = 8
    for i in range(k):
        for j in range(k):
            add_box(m, (-7 + (i + 0.5) * 14 / k, 0.15, -7 + (j + 0.5) * 14 / k), (14 / k - 0.1, 0.3, 14 / k - 0.1), shade((88, 82, 74), 0.1, rng))
    for x in (-6.5, 6.5):
        for z in (-6.5, 6.5):
            add_cyl(m, (x, 0, z), (x, 7.2, z), 0.4, DARK, 8)
    for z in (-6.5, 6.5):
        add_beam(m, (-6.8, 7.1, z), (6.8, 7.1, z), 0.45, DARK)
    # shingle roof, ridge along X, with a smoke louvre over the forge
    for s_ in (-1, 1):
        for c in range(4):
            v0, v1 = c / 4, (c + 1) / 4 + 0.05
            pts = lambda v: [V(x, 10.4 - 3.6 * v, s_ * 8.4 * v) for x in (-8, -4, 0, 4, 8)]  # noqa: E731
            a = pts(v0)
            b = [p - V(0, 0.12, 0) for p in pts(v1)]
            m.add(slab_between(a, b, 0.3, shade((92, 70, 52), 0.07, rng), rng, 0.05))
    add_box(m, (-3, 10.9, 0), (2.6, 0.9, 2.2), TAR)
    add_box(m, (-3, 11.5, 0), (3.2, 0.2, 2.8), (92, 70, 52))
    # back wall of wattle and a tool rack
    wattle_fence(m, (-6.5, 0, 6.5), (6.5, 0, 6.5), 3.5)
    for i, x in enumerate((1.5, 2.3, 3.1, 3.9)):
        add_cyl(m, (x, 2.0, 6.2), (x + 0.2, 4.2, 6.2), 0.07, (138, 100, 64), 5)
        add_box(m, (x + 0.2, 4.2, 6.1), (0.5, 0.3, 0.12), IRON)
    # the forge: a stone hearth with a hood, and bellows
    for i in range(3):
        for j in range(3):
            add_box(m, (-3 + (i - 1) * 1.35, 0.5 + j * 1.0, 2.5), (1.3, 0.95, 3.5), shade(STONE, 0.12, rng), bevel=0.08)
    add_box(m, (-3, 3.0, 2.5), (3.3, 0.15, 2.6), (40, 34, 30))
    m.add(hull([V(-4.6, 4.6, 1.0), V(-1.4, 4.6, 1.0), V(-4.6, 4.6, 4.2), V(-1.4, 4.6, 4.2), V(-3.5, 6.5, 2.1), V(-2.5, 6.5, 2.1), V(-3.5, 6.5, 2.9), V(-2.5, 6.5, 2.9)], shade(STONE, 0.05, rng)))
    add_box(m, (-3, 8.3, 2.5), (1.0, 3.6, 0.8), STONE)
    m.add(hull([V(-5.2, 1.6, 4.4), V(-5.2, 2.6, 4.4), V(-5.2, 1.6, 2.6), V(-5.2, 2.6, 2.6), V(-6.6, 2.1, 3.5)], LEATHER))
    # anvil on a stump
    add_cyl(m, (3, 0, 0), (3, 1.8, 0), 0.9, WEATHER, 10)
    m.add(hull([V(x, y, z) for x in (2.0, 4.0) for y in (1.8, 2.7) for z in (-0.45, 0.45)] + [V(4.8, 2.6, 0), V(4.8, 2.7, 0)], IRON))
    add_cyl(m, (3.4, 2.75, 0.3), (3.2, 2.75, 1.1), 0.08, (138, 100, 64), 5)
    add_box(m, (3.42, 2.8, 0.25), (0.4, 0.25, 0.25), IRON)
    # quenching barrel
    m.add(barrel_tris(rng, 2.0, 0.9), T(4, 0, 4.5))
    add_box(m, (4, 1.95, 4.5), (1.5, 0.05, 1.5), (60, 84, 100))
    return m


def shrine():
    """A small hof (temple) with stacked shingle roofs and dragon finials, the
    carved idol in front, and two iron stands for the game's fire bowls."""
    m = Mesh(101)
    rng = m.rng
    add_box(m, (0, 0.15, 0), (15, 0.3, 15), (110, 100, 86))
    # stone steps and plinth
    add_box(m, (0, 0.55, 3), (9.4, 0.5, 8.4), STONE, bevel=0.1)
    # stave walls of the temple
    hx, hz = 3.8, 3.4
    cz = 3.0
    for side in (-1, 1):
        for i in range(10):
            x = -hx + (i + 0.5) * (2 * hx / 10)
            add_box(m, (x, 3.3, cz + side * hz), (2 * hx / 10 + 0.03, 5.0, 0.3), shade(DARK, 0.08, rng))
        for j in range(9):
            z = cz - hz + (j + 0.5) * (2 * hz / 9)
            if side == -1 and abs(z - cz) < 0.9:
                continue
            add_box(m, (side * hx, 3.3, z), (0.3, 5.0, 2 * hz / 9 + 0.03), shade(DARK, 0.08, rng))
    # door in the front
    add_box(m, (0, 2.6, cz - hz - 0.05), (1.8, 3.6, 0.2), (40, 30, 24))
    m.add(hull([V(-1.1, 4.4, cz - hz - 0.2), V(1.1, 4.4, cz - hz - 0.2), V(0, 5.4, cz - hz - 0.2), V(-1.1, 4.4, cz - hz - 0.4), V(1.1, 4.4, cz - hz - 0.4), V(0, 5.4, cz - hz - 0.4)], (168, 44, 38)))

    def pyramid_roof(y0, half, h, col):
        peak = V(0, y0 + h, cz)
        corners = [V(-half, y0, cz - half), V(half, y0, cz - half), V(half, y0, cz + half), V(-half, y0, cz + half)]
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            for r in range(3):
                t0, t1 = r / 3, (r + 1) / 3 + 0.05
                p0 = [peak + (a - peak) * t0, peak + (b - peak) * t0]
                p1 = [peak + (a - peak) * t1 - V(0, 0.1, 0), peak + (b - peak) * t1 - V(0, 0.1, 0)]
                m.add(slab_between(p0, p1, 0.25, shade(col, 0.06, rng), rng, 0.04))
        return corners, peak

    corners, _ = pyramid_roof(5.6, 5.4, 2.4, (70, 52, 38))
    add_box(m, (0, 8.0, cz), (4.2, 1.4, 4.2), shade(DARK, 0.05, rng))
    corners2, peak = pyramid_roof(8.6, 3.2, 2.8, (70, 52, 38))
    add_cyl(m, (0, 11.2, cz), (0, 12.6, cz), 0.15, DARK, 6)
    m.add(blob(0.3, GOLD, rng, 1, 0.0, 0.02), T(0, 12.7, cz))
    # dragon heads curling out from the lower roof corners
    for c in corners:
        d = c - V(0, c[1], cz)
        d[1] = 0
        d /= np.linalg.norm(d)
        base = c + V(0, 0.3, 0)
        tip = base + d * 1.3 + V(0, 1.0, 0)
        add_cyl(m, base, tip, 0.18, DARK, 5, 0.12)
        m.add(hull([tip, tip + d * 0.8 + V(0, 0.1, 0), tip + V(0, 0.4, 0), tip + d * 0.2 + V(0.15, 0.2, 0), tip + d * 0.2 + V(-0.15, 0.2, 0)], GOLD))
    # the carved idol in front: a tall post with a bearded face and a helm
    add_cyl(m, (0, 0, -2.4), (0, 6.2, -2.4), 0.5, (96, 70, 48), 8)
    m.add(hull([V(x, y, -2.4 + z) for x in (-0.55, 0.55) for y in (5.4, 7.0) for z in (-0.55, 0.45)] + [V(0, 6.2, -3.15)], (110, 80, 54)))
    add_box(m, (0, 5.6, -2.98), (0.7, 0.9, 0.2), (80, 60, 40))
    for x in (-0.22, 0.22):
        add_box(m, (x, 6.5, -2.97), (0.18, 0.12, 0.05), (200, 160, 80))
    m.add(lathe([(0.62, 7.0), (0.5, 7.4), (0.0, 7.7)], 10, IRON), T(0, 0, -2.4))
    # iron stands for the fire bowls
    for x in (-2.6, 2.6):
        for k in range(3):
            a = k / 3 * math.tau
            add_cyl(m, (x + math.cos(a) * 0.5, 0, -2.6 + math.sin(a) * 0.5), (x, 2.0, -2.6), 0.07, IRON, 4)
    return m


def shipyard():
    m = Mesh(103)
    rng = m.rng
    add_box(m, (-3, 0.3, 0), (10, 0.6, 30), WEATHER)
    for i in range(12):
        add_box(m, (-3, 0.62, -14 + i * 2.5), (10.2, 0.08, 0.3), DARK)
    # a hull taking shape: keel, ribs and the first strakes
    add_box(m, (-3, 1.0, 0), (0.8, 0.8, 24), WOOD)
    for i in range(9):
        z = -11 + i * 2.75
        w = 3.5 + math.sin((i + 0.5) / 9 * math.pi) * 3
        for s_ in (-1, 1):
            pts = [V(-3 + s_ * (0.3 + w / 2 * math.sin(k / 6 * math.pi / 2)), 1.2 + 3.6 * (1 - math.cos(k / 6 * math.pi / 2)), z) for k in range(7)]
            for a, b in zip(pts, pts[1:]):
                add_beam(m, a, b, 0.28, WOOD)
    grid = hull_sections(24, 8, 1.0, 1.4, strakes=6, stations=14)
    for side in (1, -1):
        for j in range(3):
            a = [V(-3 + side * row[j][0], row[j][1] + 2.2, row[j][2]) for row in grid]
            b = [V(-3 + side * row[j + 1][0], row[j + 1][1] + 2.2, row[j + 1][2]) for row in grid]
            m.add(strip_between(a, b, (96, 68, 46) if j % 2 else (84, 58, 40), rng, 0.04))
    # prow post rising at the -Z end
    for k in range(6):
        a = k / 5 * 1.2
        p0 = V(-3, 1.4 + math.sin(a) * 5, -12.5 - math.sin(a * 0.5) * 1.6)
        a1 = (k + 1) / 5 * 1.2
        p1 = V(-3, 1.4 + math.sin(a1) * 5, -12.5 - math.sin(a1 * 0.5) * 1.6)
        if k < 5:
            add_beam(m, p0, p1, 0.5, DARK)
    # trestles, timber stacks and a lifting frame
    log_pile(m, (8, 0, 6), along_x=False)
    log_pile(m, (8, 0, -6), along_x=False)
    for x in (9, -11):
        add_cyl(m, (x, 0, -14), (x, 10, -14), 0.4, DARK, 8)
    add_beam(m, (-11.4, 10, -14), (9.4, 10, -14), 0.55, DARK)
    add_cyl(m, (-3, 9.8, -14), (-3, 5.0, -14), 0.05, (150, 130, 96), 4)
    for x in (4.5, 5.6):
        add_box(m, (x, 0.9, 12), (0.9, 1.8, 3.0), shade(WEATHER, 0.1, rng))
    for _ in range(18):
        add_box(m, (rng.uniform(-8, 6), 0.68, rng.uniform(-12, 12)), (0.4, 0.06, 0.2), (200, 170, 120), RY(rng.uniform(0, 3)))
    return m


def hunting_lodge():
    m = Mesh(105)
    rng = m.rng
    m.add(small_hall(9, 7, "thatch", 106).tris, T(-1.5, 0, 2.5))
    # antlers over the door
    for s_ in (-1, 1):
        base = V(-1.5 + s_ * 0.3, 5.4, -1.3)
        p1 = base + V(s_ * 0.6, 0.8, 0)
        p2 = p1 + V(s_ * 0.3, 0.8, 0)
        add_cyl(m, base, p1, 0.08, (222, 206, 178), 5)
        add_cyl(m, p1, p2, 0.07, (222, 206, 178), 5)
        add_cyl(m, p1, p1 + V(0, 0.6, -0.3), 0.05, (222, 206, 178), 4)
    # hide drying frame with stretched hides
    for x in (2, 6.5):
        add_cyl(m, (x, 0, -5), (x, 5, -5), 0.18, WEATHER, 6)
    add_cyl(m, (1.6, 4.8, -5), (6.9, 4.8, -5), 0.14, DARK, 6)
    for i in range(2):
        cx = 2.9 + i * 2.4
        pts = [V(cx - 0.9, 4.6, -5), V(cx + 0.9, 4.6, -5), V(cx + 1.0, 3.2, -5), V(cx + 0.6, 1.8, -5), V(cx - 0.6, 1.8, -5), V(cx - 1.0, 3.2, -5)]
        for k in range(1, len(pts) - 1):
            m.tri(pts[0], pts[k], pts[k + 1], (160, 116, 80))
            m.tri(pts[0], pts[k + 1], pts[k], (140, 100, 68))
    # a game rack with a deer hanging and a chopping block
    add_cyl(m, (5.5, 1, 3.5), (5.5, 1.8, 3.5), 0.7, WEATHER, 8)
    for x in (-6, -4):
        add_cyl(m, (x, 0, -4.5), (x, 3.6, -4.5), 0.14, WEATHER, 5)
    add_cyl(m, (-6.3, 3.5, -4.5), (-3.7, 3.5, -4.5), 0.1, DARK, 5)
    m.add(blob(1.0, (142, 98, 60), rng, 1, 0.08, 0.04, (0.45, 1.0, 0.4)), T(-5, 2.3, -4.5))
    # quiver and bows leaning by the wall
    add_cyl(m, (2.4, 0, -1.0), (2.6, 3.4, -1.0), 0.06, (110, 72, 44), 5)
    add_cyl(m, (3.0, 0, -1.0), (3.1, 1.4, -1.0), 0.22, LEATHER, 7)
    return m


# ----------------------------------------------------------------------------- shield (not a slot, a handy extra)


def shield():
    m = Mesh(80)
    disc(m, (0, 0, 0), (0, 0, -1), 1.6, RED, IRON, IRON, seg=20, paint=CREAM)
    return m


# Slot name -> builder. Each becomes meshes/<Slot>.glb
ASSETS = {
    "Longhouse": lambda: hall(),
    "GreatHall": lambda: hall(L=40, D=23.5, wall_h=6.0, ridge_h=17.5, roof="shingle", seed=2, porch=True),
    "Cottage": cottage,
    "Storehouse": storehouse,
    "Watchtower": watchtower,
    "Farm": farm,
    "Woodcutter": woodcutter,
    "Quarry": quarry,
    "LoreHall": lorehall,
    "Smithy": smithy,
    "Shrine": shrine,
    "Shipyard": shipyard,
    "HuntingLodge": hunting_lodge,
    "Fishery": fishery,
    "Brewhouse": brewhouse,
    "Palisade": palisade,
    "Tree_Pine": pine,
    "Tree_Spruce": spruce,
    "Tree_Birch": birch,
    "Rock": rock,
    "Bush": bush,
    "Longship": longship,
    "Deer": deer,
    "Axe": axe,
    "Pickaxe": pickaxe,
    "Bow": bow,
    "Sword": sword,
    "Torch": torch,
    "Prop_Barrels": prop_barrels,
    "Prop_Cart": prop_cart,
    "Prop_Haystack": prop_haystack,
    "Prop_FishRack": prop_fishrack,
    "Prop_Woodpile": prop_woodpile,
    "Prop_Banner": prop_banner,
    "Prop_BoatUpturned": prop_boat_upturned,
    "Shield": shield,
}

# The ones the game swaps in (Shield is only an extra for your own builds).
SLOTS = [name for name in ASSETS if name != "Shield"]
