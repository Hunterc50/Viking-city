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



def trader_stall():
    """Ottar's market stall: a striped awning on carved posts, a plank counter
    facing the customers (-Z), goods and a little sign. About 9 x 6 studs."""
    m = Mesh(47)
    rng = m.rng
    # posts (front pair shorter, so the awning slopes toward the customers)
    for x, z, h in ((-4.2, -2.6, 6.6), (4.2, -2.6, 6.6), (-4.2, 2.6, 7.8), (4.2, 2.6, 7.8)):
        add_cyl(m, (x, 0, z), (x, h, z), 0.32, shade(WOOD, 0.08, rng), 8)
        add_cyl(m, (x, h - 0.15, z), (x, h + 0.35, z), 0.42, DARK, 8)
    # striped awning, in slats from front to back
    stripes = 8
    for i in range(stripes):
        x0 = -4.8 + i * (9.6 / stripes)
        a = [V(x0, 6.7, -3.4), V(x0, 7.95, 3.0)]
        b = [V(x0 + 9.6 / stripes + 0.02, 6.7, -3.4), V(x0 + 9.6 / stripes + 0.02, 7.95, 3.0)]
        m.add(slab_between(a, b, 0.12, RED if i % 2 == 0 else CREAM, rng, 0.02))
    # scalloped valance along the front edge
    for i in range(stripes):
        x = -4.8 + (i + 0.5) * (9.6 / stripes)
        add_box(m, (x, 6.25, -3.42), (9.6 / stripes - 0.05, 0.8, 0.06), RED if i % 2 == 0 else CREAM)
    # counter: planks on a frame, front at -Z
    add_box(m, (0, 1.5, -2.2), (8.6, 2.8, 1.6), shade(WOOD, 0.06, rng), bevel=0.05)
    for k in range(5):
        add_box(m, (-3.4 + k * 1.7, 1.5, -3.02), (1.6, 2.7, 0.08), shade((104, 74, 48), 0.1, rng))
    add_box(m, (0, 3.0, -2.2), (9.0, 0.22, 2.0), DARK)
    # goods: a crate, furs, silver dish, a sack, fish
    add_box(m, (-3.0, 3.8, -2.1), (1.5, 1.3, 1.3), (150, 110, 70), RY(0.2), bevel=0.06)
    m.add(blob(0.9, (140, 96, 60), rng, 1, 0.08, 0.05, (1.4, 0.35, 0.9)), T(-0.6, 3.3, -2.2))
    m.add(lathe([(0.0, 0.0), (0.7, 0.05), (0.8, 0.25), (0.0, 0.2)], 12, STEEL), T(1.6, 3.12, -2.3))
    m.add(blob(0.6, (168, 150, 112), rng, 1, 0.12, 0.05, (1, 1.2, 1)), T(3.2, 3.7, -2.0))
    # a back shelf with jars and bolts of cloth
    add_box(m, (0, 3.6, 2.4), (8.0, 0.2, 1.0), DARK)
    for i, rgb in enumerate((BLUE, RED, (120, 130, 70), CREAM)):
        add_cyl(m, (-3.0 + i * 2.0, 4.0, 2.0), (-3.0 + i * 2.0, 4.0, 2.8), 0.35, rgb, 8)
    for x in (-3.6, -2.2, 2.4, 3.6):
        m.add(lathe([(0.3, 0), (0.42, 0.3), (0.3, 0.7), (0.18, 0.85), (0.0, 0.9)], 10, (156, 112, 70)), T(x, 3.7, 2.4))
    # hanging sign
    add_box(m, (3.0, 5.3, -3.0), (1.6, 0.9, 0.12), (196, 160, 80))
    add_cyl(m, (2.5, 5.75, -3.0), (2.5, 6.6, -3.0), 0.04, IRON, 4)
    add_cyl(m, (3.5, 5.75, -3.0), (3.5, 6.6, -3.0), 0.04, IRON, 4)
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


def boar(seed=57):
    """A wild boar, facing -Z: a heavy bristled body high at the shoulders,
    a long snout with tusks, short legs, small ears and a tufted tail."""
    m = Mesh(seed)
    rng = m.rng
    coat = (74, 60, 50)
    m.add(blob(1.0, coat, rng, 2, 0.08, 0.04, (0.95, 1.05, 1.75)), T(0, 2.0, 0.2))
    m.add(blob(1.0, coat, rng, 1, 0.08, 0.04, (1.0, 1.15, 0.95)), T(0, 2.25, -0.9))  # shoulders
    m.add(blob(1.0, coat, rng, 1, 0.08, 0.04, (0.9, 0.95, 0.9)), T(0, 1.95, 1.2))  # rump
    # the bristly ridge down the back
    for k in range(9):
        z = -1.5 + k * 0.38
        add_box(m, (0, 3.2 - abs(z + 0.6) * 0.18, z), (0.18, 0.4, 0.3), (46, 38, 32), RX(-0.3))
    # head: a wedge running down to the snout
    head = [V(0.55, 2.6, -1.6), V(-0.55, 2.6, -1.6), V(0.6, 1.6, -1.7), V(-0.6, 1.6, -1.7), V(0.25, 1.75, -3.1), V(-0.25, 1.75, -3.1), V(0.22, 1.3, -3.05), V(-0.22, 1.3, -3.05), V(0, 2.45, -2.4)]
    m.add(hull(head, (66, 54, 46), rng, 0.04))
    add_cyl(m, (0, 1.52, -3.05), (0, 1.52, -3.25), 0.26, (120, 92, 84), 8)  # snout disc
    for s in (-1, 1):
        add_box(m, (s * 0.09, 1.55, -3.27), (0.07, 0.1, 0.03), (30, 22, 20))
        add_box(m, (s * 0.35, 2.15, -2.3), (0.08, 0.1, 0.12), (16, 12, 10))  # eyes
        m.add(hull([V(s * 0.35, 2.55, -1.8), V(s * 0.75, 2.95, -1.6), V(s * 0.6, 2.6, -1.45), V(s * 0.4, 2.7, -1.6)], (58, 46, 40)))  # ears
        # curved tusks
        t0 = V(s * 0.25, 1.45, -2.8)
        t1 = t0 + V(s * 0.15, 0.18, -0.15)
        t2 = t1 + V(s * 0.05, 0.28, 0.05)
        add_cyl(m, t0, t1, 0.07, (230, 220, 196), 5, 0.06)
        add_cyl(m, t1, t2, 0.06, (230, 220, 196), 5, 0.015)
    # short, stout legs and trotters
    for x in (-0.45, 0.45):
        for z in (-1.0, 1.3):
            add_cyl(m, (x, 1.6, z), (x, 0.55, z + 0.05), 0.24, coat, 6, 0.15)
            add_cyl(m, (x, 0.55, z + 0.05), (x, 0.12, z + 0.05), 0.14, (60, 50, 42), 6, 0.12)
            add_box(m, (x, 0.08, z), (0.24, 0.16, 0.3), (32, 26, 22))
    # tail with a tuft
    add_cyl(m, (0, 2.3, 1.95), (0, 1.7, 2.25), 0.05, coat, 4)
    m.add(blob(0.12, (40, 32, 28), rng, 0, 0.2, 0.02, (1, 1.6, 1)), T(0, 1.62, 2.28))
    # paler belly
    recolour(m, lambda rgb, n, c: mix(rgb, (120, 104, 90), 0.45) if rgb == coat and n[1] < -0.55 else rgb)
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


# ----------------------------------------------------------------------------- forge, brewery, waterfront


def plank_wall(m, a, b, y0, y1, rgb, along=0.7, thick=0.3, skip=None):
    """Upright planks from ground point a to b, y0..y1. `skip(t)` leaves a gap."""
    a, b = V(*a), V(*b)
    d = b - a
    ln = float(np.linalg.norm(d))
    n = max(1, int(ln / along))
    for i in range(n):
        t = (i + 0.5) / n
        if skip and skip(t):
            continue
        p = a + d * t
        h = y1 - y0 + m.rng.uniform(-0.1, 0.1)
        rot = look_along(V(0, 1, 0))
        yaw = math.atan2(d[0], d[2])
        m.add(box(ln / n + 0.03, h, thick, shade(rgb, 0.08, m.rng), m.rng, 0.03), M(T(p[0], y0 + h / 2, p[2]), RY(yaw + math.pi / 2)))
        del rot


def gable_roof(m, x0, x1, half, eave_y, ridge_y, rgb, courses=5, thick=0.3, sag=0.25):
    """Shingle courses on both sides of a ridge along X, eaves at z = +-half."""
    rng = m.rng
    xs = [x0 + (x1 - x0) * i / 6 for i in range(7)]
    for s_ in (-1, 1):
        for c in range(courses):
            v0, v1 = c / courses, (c + 1) / courses + 0.05

            def at(v, x):
                # a slight sag in the middle of each run, like old boards
                mid = 1 - ((x - (x0 + x1) / 2) / ((x1 - x0) / 2)) ** 2
                return V(x, ridge_y + (eave_y - ridge_y) * v - sag * mid * math.sin(v * math.pi), s_ * half * v)

            a = [at(v0, x) for x in xs]
            b = [at(v1, x) - V(0, 0.1, 0) for x in xs]
            m.add(slab_between(a, b, thick, shade(rgb, 0.08, rng), rng, 0.05))
    add_cyl(m, (x0 - 0.3, ridge_y + 0.3, 0), (x1 + 0.3, ridge_y + 0.3, 0), 0.28, DARK, 6)


def smithy():
    """The smithy: a proper timber forge-house. Stone footing and tarred stave
    walls on three sides, a wide open front bay under a tall front eave, a
    steep shingle roof with carved gable boards, and a great stone chimney
    rising through it from the forge. Inside, the forge's mouth glows; out
    front stand the anvil, quench trough, grindstone and a weapon rack, with
    a hanging hammer sign. The game adds its own coals, fire and smoke on the
    forge at (-3, 3.1, 2.5)."""
    m = Mesh(99)
    rng = m.rng
    EMBER, HOT = (255, 150, 50), (255, 96, 28)
    # cobbled yard and floor
    for i in range(10):
        for j in range(10):
            x, z = -7.6 + (i + 0.5) * 1.52, -7.8 + (j + 0.5) * 1.56
            add_box(m, (x + rng.uniform(-0.06, 0.06), 0.12, z + rng.uniform(-0.06, 0.06)), (1.4, 0.24 + rng.uniform(0, 0.08), 1.44), shade((96, 90, 82), 0.12, rng), RY(rng.uniform(-0.1, 0.1)), bevel=0.06)
    # stone footing course under the three walls
    hx, front, back = 6.4, -3.2, 6.4
    for z in np.arange(front, back + 0.1, 1.05):
        for x in (-hx, hx):
            m.add(blob(0.62, shade(STONE, 0.14, rng), rng, 0, 0.28, 0.1, (0.9, 0.95, 1.1)), T(x, 0.6, z))
    for x in np.arange(-hx, hx + 0.1, 1.05):
        m.add(blob(0.62, shade(STONE, 0.14, rng), rng, 0, 0.28, 0.1, (1.1, 0.95, 0.9)), T(x, 0.6, back))
    # stave walls, tarred dark, from the footing to the eaves
    wall_top = 5.0
    plank_wall(m, (-hx, 0, back + 0.05), (hx, 0, back + 0.05), 1.0, wall_top, (70, 52, 38), along=0.62, thick=0.34)
    for x in (-hx, hx):
        plank_wall(m, (x, 0, front), (x, 0, back), 1.0, wall_top, (70, 52, 38), along=0.62, thick=0.34)
    # a small shuttered window in the right wall
    add_box(m, (hx + 0.2, 3.2, 2.0), (0.12, 1.2, 1.6), DARK)
    add_box(m, (hx + 0.3, 3.2, 1.0), (0.1, 1.2, 0.75), WEATHER, RY(0.6))
    # corner posts and the open front bay: three stout posts, a heavy lintel
    for x, z in ((-hx, back), (hx, back), (-hx, front), (hx, front)):
        add_cyl(m, (x, 0.2, z), (x, wall_top + 0.2, z), 0.42, shade(DARK, 0.06, rng), 8)
    front_eave = 7.0
    for x in (-hx, 0.0, hx):
        add_cyl(m, (x, 0.2, -6.8), (x, front_eave, -6.8), 0.42, shade(DARK, 0.06, rng), 8)
        add_beam(m, (x, front_eave - 1.6, -6.8), (x, front_eave - 0.1, -5.4), 0.22, DARK)
    add_beam(m, (-hx - 0.6, front_eave, -6.8), (hx + 0.6, front_eave, -6.8), 0.55, DARK)
    for x in (-hx, hx):  # side walls run on out to the front posts as low rails
        add_beam(m, (x, 1.2, front), (x, 1.2, -6.8), 0.25, DARK)
        add_beam(m, (x, wall_top, front), (x, front_eave, -6.8), 0.4, DARK)
    add_beam(m, (-hx - 0.4, wall_top, back), (hx + 0.4, wall_top, back), 0.5, DARK)
    # carved knot band along the lintel
    for k in range(13):
        add_box(m, (-hx + 0.4 + k * 1.0, front_eave, -7.1), (0.5, 0.3, 0.05), (150, 40, 36) if k % 2 else GOLD)
    # steep shingle roof: ridge along X, a tall front slope over the open bay
    ridge, ridge_z = 11.4, 0.6
    xs = [-8.3 + 16.6 * i / 6 for i in range(7)]
    for eave_y, eave_z, n in ((front_eave - 0.3, -8.55, 6), (wall_top - 0.4, 8.55, 5)):
        for c in range(n):
            v0, v1 = c / n, (c + 1) / n + 0.05
            a = [V(x, ridge + (eave_y - ridge) * v0, ridge_z + (eave_z - ridge_z) * v0) for x in xs]
            b = [V(x, ridge + (eave_y - ridge) * v1 - 0.1, ridge_z + (eave_z - ridge_z) * v1) for x in xs]
            m.add(slab_between(a, b, 0.32, shade((86, 64, 48), 0.08, rng), rng, 0.05))
    add_cyl(m, (-8.5, ridge + 0.32, ridge_z), (8.5, ridge + 0.32, ridge_z), 0.3, DARK, 6)
    # gable ends: plank infill and crossed bargeboards with carved heads
    for x in (-hx - 0.05, hx + 0.05):
        for k in range(12):
            z = -6.8 + (k + 0.5) * (back + 6.8) / 12
            if z < ridge_z:
                top = ridge - (ridge - front_eave) * (ridge_z - z) / (ridge_z + 6.8)
                bot = front_eave if z < front else wall_top
            else:
                top = ridge - (ridge - wall_top) * (z - ridge_z) / (back - ridge_z)
                bot = wall_top
            if top > bot + 0.1 and z >= front:
                add_box(m, (x, (bot + top) / 2, z), (0.25, top - bot, (back + 6.8) / 12 + 0.03), shade((96, 74, 54), 0.08, rng))
        s_ = 1 if x > 0 else -1
        ex = s_ * 8.4  # bargeboards along the roof's own edge
        for sz, ey, ez in ((-1, front_eave - 0.3, -8.55), (1, wall_top - 0.4, 8.55)):
            add_beam(m, (ex, ey + 0.25, ez), (ex, ridge + 0.6, ridge_z - sz * 0.5), 0.3, DARK)
        tip = V(ex, ridge + 1.3, ridge_z)
        add_cyl(m, V(ex, ridge + 0.4, ridge_z), tip, 0.2, DARK, 6, 0.14)
        m.add(hull([tip, tip + V(0, 0.2, -0.9), tip + V(0, 0.6, -0.2), tip + V(0.15, 0.3, -0.3), tip + V(-0.15, 0.3, -0.3)], (150, 40, 36)))
    # the forge: a big rough-stone hearth against the back-left, its glowing mouth to the front
    fx, fz = -3.0, 2.5
    for i in range(4):
        for j in range(3):
            for side in (-1, 1):
                add_box(m, (fx + side * (1.55 + 0.25 * (i % 2)), 0.55 + j * 0.85, fz - 1.2 + i * 0.95), (0.9, 0.82, 0.95), shade(STONE, 0.14, rng), RY(rng.uniform(-0.05, 0.05)), bevel=0.1)
    for i in range(4):
        add_box(m, (fx - 1.5 + i * 1.0, 0.55 + 1 * 0.85, fz + 1.6), (0.95, 2.5, 0.9), shade(STONE, 0.14, rng), bevel=0.1)
    add_box(m, (fx, 0.6, fz), (2.4, 1.0, 2.6), shade(STONE, 0.1, rng), bevel=0.08)
    add_box(m, (fx, 2.85, fz), (4.6, 0.3, 3.9), shade((100, 96, 90), 0.05, rng), bevel=0.08)
    add_box(m, (fx, 2.95, fz), (3.0, 0.12, 2.4), (48, 36, 30))
    # the glowing mouth of the firebox under the hearth, and embers spilling out
    add_box(m, (fx, 1.6, fz - 1.3), (1.8, 1.1, 0.1), HOT)
    add_box(m, (fx, 1.6, fz - 1.25), (2.2, 1.4, 0.06), (40, 34, 30))
    for k in range(6):
        m.add(blob(0.18, EMBER if k % 2 else HOT, rng, 0, 0.3, 0.05), T(fx + rng.uniform(-0.8, 0.8), 1.15, fz - 1.1 + rng.uniform(-0.1, 0.1)))
    # the hood and the great chimney up through the roof
    m.add(hull([V(fx - 2.3, 5.2, fz - 1.9), V(fx + 2.3, 5.2, fz - 1.9), V(fx - 2.3, 5.2, fz + 1.9), V(fx + 2.3, 5.2, fz + 1.9), V(fx - 1.0, 7.4, fz - 0.8), V(fx + 1.0, 7.4, fz - 0.8), V(fx - 1.0, 7.4, fz + 0.8), V(fx + 1.0, 7.4, fz + 0.8)], shade(STONE, 0.05, rng)))
    for x in (fx - 1.95, fx + 1.95):
        add_box(m, (x, 4.05, fz - 1.5), (0.7, 2.3, 0.7), shade(STONE, 0.1, rng), bevel=0.08)
    y = 7.4
    while y < 13.2:
        w = 2.1 - (y - 7.4) * 0.06
        add_box(m, (fx + rng.uniform(-0.05, 0.05), y + 0.3, fz), (w, 0.62, w * 0.9), shade(STONE, 0.12, rng), RY(rng.uniform(-0.06, 0.06)), bevel=0.06)
        y += 0.6
    add_box(m, (fx, 13.35, fz), (2.0, 0.22, 1.8), shade((96, 92, 86), 0.04, rng))
    for x in (fx - 0.75, fx + 0.75):
        add_box(m, (x, 13.75, fz), (0.3, 0.6, 1.4), STONE)
    add_box(m, (fx, 14.15, fz), (2.0, 0.2, 1.7), (80, 76, 72))
    # bellows beside the forge with a pump pole
    m.add(hull([V(fx + 2.3, 1.4, fz - 0.6), V(fx + 2.3, 2.6, fz - 0.6), V(fx + 2.3, 1.4, fz + 1.4), V(fx + 2.3, 2.6, fz + 1.4), V(fx + 3.7, 2.0, fz + 0.4)], LEATHER))
    add_box(m, (fx + 3.0, 2.68, fz + 0.4), (1.5, 0.12, 2.1), WOOD)
    add_cyl(m, (fx + 3.6, 2.75, fz + 0.4), (fx + 4.2, 5.6, fz + 0.4), 0.08, WOOD, 5)
    add_cyl(m, (fx + 4.2, 5.6, fz + 0.4), (fx + 4.2, wall_top + 2.2, fz + 0.4), 0.03, (176, 150, 104), 3)
    # tools hung on the back wall
    add_beam(m, (0.6, 4.0, back - 0.3), (5.6, 4.0, back - 0.3), 0.2, DARK)
    for i, x in enumerate((1.2, 2.0, 2.8, 3.6, 4.4, 5.1)):
        add_cyl(m, (x, 3.95, back - 0.35), (x + 0.15, 2.2, back - 0.4), 0.06, (138, 100, 64), 4)
        if i % 2 == 0:
            add_box(m, (x + 0.15, 2.2, back - 0.42), (0.55, 0.3, 0.28), IRON)
        else:
            add_cyl(m, (x - 0.12, 2.2, back - 0.42), (x + 0.32, 2.2, back - 0.42), 0.06, IRON, 4)
    # anvil on a great stump, under the front of the roof
    ax, az = 3.0, 0.0
    add_cyl(m, (ax, 0.2, az), (ax, 1.9, az), 0.95, WEATHER, 11, 0.88, vary=0.05, noise=0.05)
    m.add(lathe([(0.0, 1.88), (0.9, 1.88), (0.9, 1.92), (0.0, 1.92)], 11, (190, 156, 110)), T(ax, 0, az))
    for k in range(5):
        a = k / 5 * math.tau
        add_cyl(m, (ax + math.cos(a) * 0.8, 0.2, az + math.sin(a) * 0.8), (ax + math.cos(a) * 1.3, 0.25, az + math.sin(a) * 1.3), 0.2, WEATHER, 5, 0.05)
    m.add(hull([V(x, y, z) for x in (ax - 0.9, ax + 0.9) for y in (1.92, 2.15) for z in (-0.55, 0.55)], IRON))
    m.add(hull([V(x, y, z) for x in (ax - 0.6, ax + 0.6) for y in (2.15, 2.55) for z in (-0.3, 0.3)], IRON))
    m.add(hull([V(x, y, z) for x in (ax - 1.0, ax + 0.9) for y in (2.55, 2.95) for z in (-0.48, 0.48)] + [V(ax + 2.0, 2.85, 0), V(ax + 2.0, 2.95, 0)], (74, 76, 80)))
    add_box(m, (ax - 0.3, 3.0, 0.0), (0.9, 0.08, 0.3), EMBER)  # a hot bar on the anvil
    add_cyl(m, (ax + 0.4, 3.05, 0.25), (ax + 0.1, 3.05, 1.3), 0.07, (138, 100, 64), 5)
    add_box(m, (ax + 0.45, 3.12, 0.2), (0.48, 0.3, 0.3), IRON)
    # quench trough of planks, full of dark water
    add_box(m, (5.2, 0.75, -3.6), (1.4, 1.1, 3.0), shade(WOOD, 0.06, rng), bevel=0.05)
    add_box(m, (5.2, 1.25, -3.6), (1.1, 0.05, 2.7), (52, 72, 88))
    for z in (-4.8, -2.4):
        add_box(m, (5.2, 0.75, z), (1.5, 1.15, 0.12), IRON)
    # grindstone on a trestle, out in the yard
    for z in (-6.0, -5.2):
        add_beam(m, (-4.8, 0.2, z), (-4.8, 1.7, z), 0.22, DARK)
    m.add(lathe([(0.0, -0.2), (1.0, -0.2), (1.06, 0.0), (1.0, 0.2), (0.0, 0.2)], 14, (150, 142, 128)), M(T(-4.8, 1.75, -5.6), RX(math.pi / 2)))
    add_cyl(m, (-4.8, 1.75, -6.4), (-4.8, 1.75, -4.6), 0.08, IRON, 5)
    add_cyl(m, (-4.8, 1.75, -4.6), (-4.8, 1.0, -4.3), 0.06, WOOD, 4)
    # a rack of new-made weapons by the open front
    for x in (-2.6, -0.6):
        add_beam(m, (x, 0.2, -7.6), (x, 2.4, -7.6), 0.18, DARK)
    add_beam(m, (-2.8, 2.2, -7.6), (-0.4, 2.2, -7.6), 0.16, DARK)
    for k, x in enumerate((-2.3, -1.7, -1.1)):
        add_cyl(m, (x, 0.25, -7.45), (x + 0.05, 1.2, -7.5), 0.05, (138, 100, 64), 4)
        add_box(m, (x + 0.06, 2.2, -7.5), (0.12, 2.0, 0.24) if k != 1 else (0.1, 0.9, 0.7), STEEL)
    # iron bars, a heap of charcoal and charcoal sacks along the left
    for k in range(6):
        add_box(m, (-5.4, 0.4 + (k // 3) * 0.2, -1.6 + (k % 3) * 0.3), (0.18, 0.18, 2.4), (86, 80, 78))
    m.add(blob(1.1, (38, 36, 36), rng, 1, 0.2, 0.08, (1.1, 0.55, 1.0)), T(-5.0, 0.7, 5.0))
    for p in ((-5.4, -4.2), (-5.9, -3.3)):
        m.add(blob(0.55, (120, 104, 84), rng, 1, 0.1, 0.05, (1, 1.25, 1)), T(p[0], 0.75, p[1]))
    # a hanging sign: an anvil cut out on a board, under an iron bracket
    add_beam(m, (hx, 6.0, -6.8), (hx + 1.6, 6.0, -6.8), 0.12, IRON)
    add_box(m, (hx + 1.1, 5.1, -6.8), (1.2, 1.0, 0.12), (196, 160, 80))
    add_box(m, (hx + 1.1, 5.1, -6.88), (0.7, 0.35, 0.05), (40, 36, 34))
    add_box(m, (hx + 1.1, 4.85, -6.88), (0.3, 0.3, 0.05), (40, 36, 34))
    return m



def brewhouse():
    """The brewhouse: a turf-roofed log hall with a smoke hole, a lean-to open
    brew shed in front with a big copper vat on a stone fire, mead barrels on a
    rack, drying herbs, beehive skeps on a bench and a little iron fire basket
    (the game's fire sits in it, at (4.6, 1.8, -2))."""
    m = Mesh(43)
    rng = m.rng
    # the hall: horizontal logs, notched corners, a turf roof (ridge along X)
    cx, cz, hx, hz = -1.6, 2.4, 4.6, 3.2
    for i in range(6):
        y = 0.45 + i * 0.62
        for s_ in (-1, 1):
            z = cz + s_ * hz
            if s_ == -1:
                for x0, x1 in ((cx - hx - 0.5, cx - 0.9), (cx + 0.9, cx + hx + 0.5)):
                    add_cyl(m, (x0, y, z), (x1, y, z), 0.33, shade(WOOD, 0.1, rng), 7)
                if i >= 4:
                    add_cyl(m, (cx - 0.9, y, z), (cx + 0.9, y, z), 0.33, shade(WOOD, 0.1, rng), 7)
            else:
                add_cyl(m, (cx - hx - 0.5, y, z), (cx + hx + 0.5, y, z), 0.33, shade(WOOD, 0.1, rng), 7)
            add_cyl(m, (cx + s_ * hx, y + 0.31, cz - hz - 0.5), (cx + s_ * hx, y + 0.31, cz + hz + 0.5), 0.33, shade(WOOD, 0.1, rng), 7)
    wall_top = 0.45 + 6 * 0.62
    add_box(m, (cx, 1.6, cz - hz - 0.15), (1.7, 2.7, 0.2), TAR)  # door
    for y in (0.9, 2.3):
        add_box(m, (cx, y, cz - hz - 0.28), (1.4, 0.12, 0.05), IRON)
    ridge = wall_top + 3.4
    for e in (-1, 1):
        x = cx + e * hx
        for k in range(9):
            z = cz - hz + (k + 0.5) * (2 * hz / 9)
            top = ridge - (ridge - wall_top) * abs(z - cz) / hz
            if top > wall_top + 0.1:
                add_box(m, (x, (wall_top + top) / 2, z), (0.25, top - wall_top, 2 * hz / 9 + 0.03), shade(WEATHER, 0.08, rng))
    # birch-bark and turf roof: thick lumpy slabs, grass on top
    xs = [cx - hx - 1.2 + (2 * hx + 2.4) * i / 6 for i in range(7)]
    for s_ in (-1, 1):
        for c in range(3):
            v0, v1 = c / 3, (c + 1) / 3 + 0.04
            a = [V(x, ridge + 0.35 + (wall_top - 0.6 - ridge) * v0, cz + s_ * (hz + 1.3) * v0) for x in xs]
            b = [V(x, ridge + 0.35 + (wall_top - 0.6 - ridge) * v1, cz + s_ * (hz + 1.3) * v1) for x in xs]
            m.add(slab_between(a, b, 0.55, shade(TURF, 0.1, rng), rng, 0.08))
        for x in xs[1:-1]:
            m.add(blob(0.55, shade(MOSS, 0.1, rng), rng, 0, 0.3, 0.1, (1.3, 0.5, 1)), T(x + rng.uniform(-0.4, 0.4), ridge - 1.2 + rng.uniform(-0.3, 0.3), cz + s_ * 2.0))
    for s_ in (-1, 1):  # bark edge under the turf
        add_beam(m, (cx - hx - 1.2, wall_top - 0.7, cz + s_ * (hz + 1.3)), (cx + hx + 1.2, wall_top - 0.7, cz + s_ * (hz + 1.3)), 0.25, (196, 184, 160))
    # smoke hole with a little roof over it
    add_box(m, (cx + 1.5, ridge + 0.9, cz), (1.2, 0.8, 1.2), DARK)
    add_box(m, (cx + 1.5, ridge + 1.4, cz), (1.8, 0.15, 1.8), (92, 70, 52))
    # the lean-to brew shed in front of the hall's right end
    for x, z, h in ((2.2, -5.6, 4.0), (5.9, -5.6, 4.0), (2.2, -1.4, 5.0), (5.9, -1.4, 5.0)):
        add_cyl(m, (x, 0, z), (x, h, z), 0.24, shade(DARK, 0.06, rng), 7)
    for i in range(5):
        x0 = 1.9 + i * 0.84
        m.add(slab_between([V(x0, 4.1, -6.0), V(x0, 5.15, -0.9)], [V(x0 + 0.86, 4.1, -6.0), V(x0 + 0.86, 5.15, -0.9)], 0.2, shade((92, 70, 52), 0.08, rng), rng, 0.04))
    # stone fire ring and the copper vat over it
    for k in range(8):
        a = k / 8 * math.tau
        m.add(blob(0.45, shade(STONE, 0.12, rng), rng, 0, 0.25, 0.08, (1, 0.7, 1)), T(4.4 + math.cos(a) * 1.3, 0.28, -4.3 + math.sin(a) * 1.25))
    m.add(lathe([(0.0, 0.5), (1.0, 0.6), (1.4, 1.1), (1.5, 2.2), (1.35, 2.75), (1.5, 2.85), (1.5, 2.95), (0.0, 2.95)], 16, (176, 110, 64)), T(4.4, 0, -4.3))
    m.add(lathe([(1.52, 1.5), (1.58, 1.5), (1.58, 1.7), (1.52, 1.7)], 16, (120, 74, 46), caps=False), T(4.4, 0, -4.3))
    m.add(lathe([(0.0, 2.9), (1.3, 2.9), (1.3, 2.96), (0.0, 2.96)], 16, (112, 84, 40)), T(4.4, 0, -4.3))  # the wort
    add_cyl(m, (3.6, 2.4, -3.9), (5.4, 4.0, -4.9), 0.07, WOOD, 4)  # paddle
    # the little iron fire basket where the game's fire burns
    for k in range(3):
        a = k / 3 * math.tau + 0.3
        add_cyl(m, (4.6 + math.cos(a) * 0.7, 0, -2 + math.sin(a) * 0.7), (4.6, 1.3, -2), 0.06, IRON, 4)
    m.add(lathe([(0.2, 1.2), (0.75, 1.55), (0.8, 1.7), (0.0, 1.45)], 10, IRON), T(4.6, 0, -2))
    # barrel rack: three on a cradle, two more stood up, and a tap
    for x in (-6.6, -4.4):
        add_beam(m, (x, 0.2, -4.6), (x, 0.9, -4.6), 0.3, DARK)
    add_beam(m, (-6.9, 0.9, -4.0), (-4.1, 0.9, -4.0), 0.25, DARK)
    add_beam(m, (-6.9, 0.9, -5.2), (-4.1, 0.9, -5.2), 0.25, DARK)
    for k in range(2):
        m.add(barrel_tris(rng, 1.7, 0.7), M(T(-6.8 + k * 1.75 + 0.85, 1.65, -4.6), RZ(math.pi / 2), T(0, -0.85, 0)))
    m.add(barrel_tris(rng, 1.7, 0.7), M(T(-5.95, 3.05, -4.6), RZ(math.pi / 2), T(0, -0.85, 0)))
    add_cyl(m, (-5.0, 1.65, -5.35), (-5.0, 1.65, -5.7), 0.08, WOOD, 4)
    for p in ((-3.4, -5.4), (-2.4, -4.6)):
        m.add(barrel_tris(rng, 1.8, 0.75), T(p[0], 0, p[1]))
    # bunches of herbs and hops hung under the lean-to
    for i in range(5):
        x = 2.8 + i * 0.85
        add_cyl(m, (x, 4.3, -1.9), (x, 3.6, -1.9), 0.02, (150, 130, 96), 3)
        m.add(blob(0.3, shade((112, 132, 64), 0.12, rng), rng, 0, 0.3, 0.1, (0.8, 1.3, 0.8)), T(x, 3.4, -1.9))
    # beehive skeps on a bench behind
    add_box(m, (-5.0, 0.8, 6.8), (4.2, 0.25, 1.0), WOOD)
    for x in (-6.6, -6.0, -3.4):
        add_beam(m, (x + 0.4, 0, 6.8), (x + 0.4, 0.7, 6.8), 0.2, DARK)
    for x in (-6.4, -5.0, -3.6):
        m.add(lathe([(0.6, 0.0), (0.62, 0.4), (0.5, 0.8), (0.28, 1.05), (0.0, 1.12)], 10, THATCH), T(x, 0.92, 6.8))
        for y in (0.25, 0.55, 0.85):
            k = 1 - y / 1.2
            m.add(lathe([(0.62 * k + 0.06, y), (0.62 * k + 0.06, y + 0.06)], 10, (150, 116, 62), caps=False), T(x, 0.92, 6.8))
    # a sign: a horn cup carved on a board
    add_box(m, (cx + 1.5, 3.2, cz - hz - 0.4), (1.2, 0.8, 0.1), (196, 160, 80))
    return m


def dock(L=48):
    """A plank jetty on piles, starting at z = 0 and running out along -Z.
    Same layout as the game's own dock (deck at 1.2, piles to -8), with
    crates, a barrel, a coil of rope, mooring posts and a rowing boat tied up
    at the end."""
    m = Mesh(111 + L)
    rng = m.rng
    z = 0.575
    while z < L - 0.5:
        add_box(m, (rng.uniform(-0.1, 0.1), 1.2 + rng.uniform(-0.04, 0.04), -z), (6 + rng.uniform(-0.2, 0.3), 0.42, 1.12), shade(WEATHER, 0.12, rng), RY(rng.uniform(-0.015, 0.015)), bevel=0.05)
        z += 1.23
    for x in (-2.2, 2.2):
        add_box(m, (x, 0.8, -L / 2), (0.5, 0.5, L), DARK)
    for zz in range(0, L + 1, 6):
        for x in (-2.8, 2.8):
            add_cyl(m, (x, -8, -zz), (x, 2.2, -zz), 0.4, shade(DARK, 0.1, rng), 8, 0.36, noise=0.03)
            add_cyl(m, (x, 1.55, -zz), (x, 1.85, -zz), 0.47, (176, 150, 104), 8)
            # a cross brace between the piles, below the deck
            if zz + 6 <= L:
                add_beam(m, (x, 0.4, -zz), (x, -3.5, -zz - 6), 0.22, DARK)
        add_beam(m, (-2.8, 0.6, -zz), (2.8, 0.6, -zz), 0.3, DARK)
    # mooring bollards near the end
    for x in (-2.6, 2.6):
        add_cyl(m, (x, 1.4, -L + 1.2), (x, 2.6, -L + 1.2), 0.32, DARK, 8)
        add_cyl(m, (x, 2.6, -L + 1.2), (x, 2.8, -L + 1.2), 0.4, DARK, 8)
    # crates, a barrel and a coil of rope
    for at in ((1.6, 2.4, -6), (1.6, 2.4, -8.1), (1.7, 4.3, -7)):
        add_box(m, at, (1.9, 1.9, 1.9), shade((150, 110, 70), 0.1, rng), RY(rng.uniform(-0.3, 0.3)), bevel=0.08)
        add_box(m, (at[0], at[1], at[2]), (1.96, 0.2, 1.96), DARK, RY(0))
    m.add(barrel_tris(rng, 1.8, 0.75), T(-1.8, 1.45, -10))
    m.add(lathe([(0.3, 0), (0.7, 0), (0.7, 0.4), (0.3, 0.4)], 12, (176, 150, 104)), T(-1.8, 1.45, -L + 3))
    # the rowing boat, tied up beside the end
    boat = Mesh(112)
    add_hull(boat, 9, 2.9, 1.0, 0.8)
    m.add(boat.tris, T(-5.5, -0.4, -L + 4))
    for k in (-1, 1):
        add_box(m, (-5.5, 0.35, -L + 4 + k * 1.6), (2.2, 0.15, 0.5), WOOD)
    add_cyl(m, (-5.0, 0.4, -L + 2.5), (-5.9, 0.5, -L + 7), 0.07, WOOD, 4)
    add_cyl(m, (-4.6, 0.6, -L + 1.5), (-2.6, 2.6, -L + 1.2), 0.04, (176, 150, 104), 3)
    return m


def palisade_gate():
    """A gateway for the palisade: two great sharpened posts, a carved lintel
    with dragon heads and a little shingle roof, a painted shield, and the
    doors swung open inward (+Z). The way through runs along Z."""
    m = Mesh(117)
    rng = m.rng
    for x in (-3.1, 3.1):
        h = 10.5
        prof = [(0.98, 0), (0.92, h * 0.6), (0.9, h - 0.4), (0.45, h + 0.4), (0.0, h + 1.1)]
        tris = lathe(prof, 10, shade(DARK, 0.05, rng), rng, 0.06, 0.05)
        tris = [(a, b, c, (178, 148, 104) if (a[1] + b[1] + c[1]) / 3 > h - 0.45 else cc) for a, b, c, cc in tris]
        m.add(tris, T(x, 0, 0))
        for y in (2.0, 6.5):
            add_cyl(m, (x, y, 0), (x, y + 0.35, 0), 1.0, IRON, 10)
        # carved knotwork band
        for k in range(6):
            a = k / 6 * math.tau
            add_box(m, (x + math.cos(a) * 0.92, 4.4 + (k % 2) * 0.4, math.sin(a) * 0.92), (0.2, 0.7, 0.2), (150, 40, 36), RY(-a))
    add_box(m, (0, 9.1, 0), (8.6, 1.0, 1.2), shade(DARK, 0.04, rng), bevel=0.08)
    for k in range(9):
        add_box(m, (-3.2 + k * 0.8, 9.1, -0.62), (0.3, 0.6, 0.06), GOLD if k % 2 else (150, 40, 36))
    # a small gable roof over the lintel
    for s_ in (-1, 1):
        for c in range(2):
            v0, v1 = c / 2, (c + 1) / 2 + 0.05
            a = [V(x, 10.9 - 1.1 * v0, s_ * 0.9 * v0) for x in (-4.4, 0, 4.4)]
            b = [V(x, 10.9 - 1.1 * v1 - 0.08, s_ * 0.9 * v1) for x in (-4.4, 0, 4.4)]
            m.add(slab_between(a, b, 0.2, shade((92, 70, 52), 0.08, rng), rng, 0.04))
    # dragon heads looking out from the lintel ends
    for s_ in (-1, 1):
        base = V(s_ * 4.1, 9.4, 0)
        neck = base + V(s_ * 0.35, 0.6, -0.3)
        add_cyl(m, base, neck, 0.28, DARK, 6, 0.22)
        m.add(hull([neck, neck + V(0, 0.15, -0.9), neck + V(0, 0.5, -0.2), neck + V(s_ * 0.18, 0.25, -0.3), neck + V(-s_ * 0.18, 0.25, -0.3)], (150, 40, 36)))
        add_box(m, neck + V(0, 0.42, -0.35), (0.08, 0.08, 0.08), GOLD)
    # the shield over the way through
    disc(m, (0, 9.1, -0.62), (0, 0, -1), 0.85, GOLD, IRON, IRON, seg=16, paint=(150, 40, 36))
    # doors swung open against the inside of the posts
    for s_ in (-1, 1):
        x = s_ * 2.6
        for k in range(4):
            add_box(m, (x, 3.9, 1.35 + k * 0.7), (0.32, 7.4 + rng.uniform(-0.1, 0.1), 0.68), shade(WOOD, 0.08, rng), bevel=0.03)
        for y in (1.9, 5.9):
            add_box(m, (x - s_ * 0.2, y, 2.4), (0.06, 0.3, 2.9), IRON)
        add_beam(m, (x - s_ * 0.2, 1.9, 1.2), (x - s_ * 0.2, 5.9, 3.6), 0.2, DARK)
        add_cyl(m, (x - s_ * 0.24, 3.9, 3.3), (x - s_ * 0.24, 3.9, 3.5), 0.18, IRON, 6)
    # a worn path of stones through the gate
    for k in range(5):
        add_box(m, (rng.uniform(-0.6, 0.6), 0.06, -0.6 + k * 0.9), (1.2, 0.12, 0.7), shade(STONE, 0.1, rng), RY(rng.uniform(-0.3, 0.3)), bevel=0.04)
    return m


# ----------------------------------------------------------------------------- decorations (one cell each)


def decor_torch():
    """A carved torch post with an iron cup of burning pitch (the game's flame
    sits at y 5.75) and a ring of stones round its foot."""
    m = Mesh(121)
    rng = m.rng
    m.add(lathe([(0.28, 0), (0.25, 3.2), (0.22, 5.0), (0.2, 5.2), (0.0, 5.22)], 8, shade(DARK, 0.04, rng), rng, 0.04, 0.02))
    for k in range(10):  # a spiral of carving
        a = k * 0.9
        add_box(m, (math.cos(a) * 0.25, 1.0 + k * 0.32, math.sin(a) * 0.25), (0.12, 0.3, 0.12), (150, 110, 70), RY(-a))
    for y in (3.4, 3.75):
        add_cyl(m, (0, y, 0), (0, y + 0.18, 0), 0.3, (110, 78, 50), 8)
    m.add(lathe([(0.15, 5.1), (0.5, 5.35), (0.52, 5.65), (0.44, 5.65), (0.0, 5.45)], 10, IRON))
    for k in range(4):
        a = k / 4 * math.tau
        add_cyl(m, (0, 4.7, 0), (math.cos(a) * 0.5, 5.45, math.sin(a) * 0.5), 0.04, IRON, 3)
    for k in range(5):
        a = k / 5 * math.tau + 0.4
        m.add(blob(0.38, shade(STONE, 0.14, rng), rng, 0, 0.3, 0.1, (1.1, 0.7, 1)), T(math.cos(a) * 0.72, 0.18, math.sin(a) * 0.72))
    return m


def decor_brazier():
    """A big iron fire basket on three curling legs over a round of flagstones.
    The game's coals and fire sit in the bowl at y 4."""
    m = Mesh(122)
    rng = m.rng
    m.add(lathe([(2.75, 0), (2.75, 0.18), (0.0, 0.24)], 16, (96, 96, 94)))
    for k in range(7):
        a = k / 7 * math.tau
        add_box(m, (math.cos(a) * 1.9, 0.26, math.sin(a) * 1.9), (1.1, 0.06, 0.9), shade(STONE, 0.12, rng), RY(-a), bevel=0.03)
    for k in range(3):
        a = k / 3 * math.tau
        pts = []
        for i in range(7):
            t = i / 6
            r = 1.1 - 0.55 * t + 0.25 * math.sin(t * math.pi)
            pts.append(V(math.cos(a) * r, 0.24 + 3.3 * t, math.sin(a) * r))
        for p, q in zip(pts, pts[1:]):
            add_cyl(m, p, q, 0.1, IRON, 5)
        m.add(blob(0.16, IRON, rng, 0, 0.0, 0.0), T(*pts[0]))
        tip = pts[-1]
        add_cyl(m, tip, tip + V(math.cos(a) * 0.45, 0.4, math.sin(a) * 0.45), 0.08, IRON, 4)
    m.add(lathe([(0.3, 3.3), (0.9, 3.5), (1.15, 3.95), (1.1, 4.05), (0.0, 3.7)], 14, (46, 44, 44)))
    for k in range(8):  # basket bars
        a = k / 8 * math.tau
        add_cyl(m, (math.cos(a) * 1.1, 3.95, math.sin(a) * 1.1), (math.cos(a) * 1.3, 4.6, math.sin(a) * 1.3), 0.05, IRON, 3)
    m.add(lathe([(1.3, 4.55), (1.36, 4.55), (1.36, 4.65), (1.3, 4.65)], 14, IRON, caps=False))
    return m


def decor_runestone():
    """A tall rune stone: a rough grey slab with a red serpent band coiling
    up the face, rune marks inside, moss and stones at its foot."""
    m = Mesh(123)
    rng = m.rng
    h = 7.0
    prof = [(1.7, 0), (1.75, h * 0.35), (1.5, h * 0.75), (0.9, h * 0.95), (0.0, h)]
    tris = lathe(prof, 10, (118, 120, 118), rng, 0.06, 0.09)
    m.add(tris, np.diag([1, 1, 0.36, 1]))
    # the serpent: a band of red squares following a loop up the face
    for k in range(26):
        t = k / 25
        y = 0.8 + t * (h - 2.0)
        w = 1.25 * (1 - 0.45 * t)
        x = math.sin(t * math.pi * 2.0) * w
        add_box(m, (x, y, -0.6 + 0.02 * t), (0.34, 0.34, 0.1), (160, 44, 38), RZ(math.cos(t * math.pi * 2) * 0.8))
    m.add(hull([V(-0.2, h - 0.9, -0.55), V(0.25, h - 1.1, -0.55), V(0.0, h - 0.6, -0.62), V(0.0, h - 1.0, -0.66)], (160, 44, 38)))  # head
    for i in range(8):
        add_box(m, (-0.6 + (i % 4) * 0.4, 2.0 + (i // 4) * 1.3, -0.6), (0.1, 0.5, 0.06), (40, 36, 34), RZ(0.3 if i % 2 else -0.25))
    for k in range(7):
        a = k / 7 * math.tau
        m.add(blob(0.45, shade(MOSS, 0.12, rng), rng, 0, 0.35, 0.1, (1.4, 0.45, 1)), T(math.cos(a) * 1.3, 0.12, math.sin(a) * 0.55))
    for p in ((1.6, 0.25, 0.3), (-1.5, 0.2, -0.2)):
        m.add(blob(0.4, shade(STONE, 0.12, rng), rng, 0, 0.3, 0.1, (1, 0.7, 1)), T(*p))
    return m


def decor_banner():
    """A tall banner pole: an iron finial, a crossbar and a swallow-tailed
    banner in the clan colour (red, recoloured by the game) with a gold border
    and a raven, its foot held by stones."""
    m = Mesh(124)
    rng = m.rng
    add_cyl(m, (0, 0, 0), (0, 11, 0), 0.22, DARK, 8, 0.16)
    m.add(hull([V(0, 11.0, 0), V(0.35, 11.5, 0), V(-0.35, 11.5, 0), V(0, 12.2, 0), V(0, 11.4, 0.12), V(0, 11.4, -0.12)], IRON))
    add_cyl(m, (-0.2, 10.4, 0), (3.1, 10.4, 0), 0.12, DARK, 6)
    for x in (-0.2, 3.1):
        m.add(blob(0.16, GOLD, rng, 0, 0.0, 0.0), T(x, 10.4, 0))
    nx, ny = 6, 8
    grid = []
    for j in range(ny + 1):
        v = j / ny
        row = []
        for i in range(nx + 1):
            u = i / nx
            row.append(V(0.1 + 2.8 * u, 10.25 - v * 5.4, 0.2 * math.sin(u * math.pi * 2 + v * 2) * u))
        grid.append(row)
    for j in range(ny):
        m.add(strip_between(grid[j], grid[j + 1], RED, rng, 0.03))
    for i in range(2):  # swallow tails
        x = 0.1 + 1.4 * i
        tip = V(x + 0.7, 4.0, 0.1)
        m.add(strip_between([V(x, 4.85, 0.0), V(x + 1.4, 4.85, 0.0)], [tip, tip], RED))
    em = [V(1.5, 8.6, -0.25), V(0.6, 8.2, -0.25), V(2.4, 8.2, -0.25), V(1.5, 7.2, -0.25), V(1.8, 8.9, -0.25), V(1.2, 8.9, -0.25)]
    m.add(strip_between([em[1], em[5], em[4]], [em[3], em[0], em[2]], GOLD))
    for k in range(5):
        a = k / 5 * math.tau
        m.add(blob(0.42, shade(STONE, 0.12, rng), rng, 0, 0.3, 0.1, (1, 0.7, 1)), T(math.cos(a) * 0.6, 0.2, math.sin(a) * 0.6))
    return m


def decor_shieldrack():
    """A rack of painted round shields with spears and an axe leaning behind."""
    m = Mesh(125)
    rng = m.rng
    for x in (-2.6, 2.6):
        add_cyl(m, (x, 0, 0), (x, 4.0, 0), 0.2, DARK, 7)
        m.add(hull([V(x, 4.0, 0), V(x + 0.25, 4.2, 0), V(x - 0.25, 4.2, 0), V(x, 4.6, -0.1)], DARK))
        for s_ in (-1, 1):
            add_beam(m, (x, 0, s_ * 0.7), (x, 1.4, 0), 0.16, DARK)
    add_beam(m, (-2.9, 3.4, 0), (2.9, 3.4, 0), 0.26, DARK)
    add_beam(m, (-2.9, 0.8, 0.3), (2.9, 0.8, 0.3), 0.26, DARK)
    colours = [((150, 40, 36), CREAM), (GOLD, (150, 40, 36)), (BLUE, CREAM)]
    for (face, paint), x in zip(colours, (-1.7, 0, 1.7)):
        disc(m, (x, 2.1, -0.32), (0, math.sin(math.radians(-8)), -math.cos(math.radians(-8))), 1.15, face, IRON, IRON, seg=18, paint=paint)
    for x in (-2.1, -0.8, 0.9, 2.2):
        base = V(x, 0, 0.55)
        top = V(x + x * 0.05, 6.0, 0.25)
        add_cyl(m, base, top, 0.06, WOOD, 5)
        d = top - base
        d /= np.linalg.norm(d)
        m.add(hull([top, top + d * 0.9, top + d * 0.3 + V(0.14, 0, 0), top + d * 0.3 + V(-0.14, 0, 0), top + d * 0.3 + V(0, 0, 0.04)], STEEL))
    # an axe hung on the top rail
    add_cyl(m, (2.8, 3.5, -0.2), (2.6, 1.6, -0.2), 0.06, (138, 100, 64), 5)
    m.add(hull([V(2.75, 3.3, -0.2), V(3.4, 3.6, -0.2), V(3.4, 2.7, -0.2), V(2.7, 2.9, -0.2), V(3.0, 3.1, -0.26), V(3.0, 3.1, -0.14)], STEEL))
    return m


def decor_totem():
    """A carved god-post: three stacked faces (the middle with gold eyes),
    spread wings and a raven perched on top."""
    m = Mesh(126)
    rng = m.rng
    m.add(lathe([(0.7, 0), (0.66, 8.8), (0.5, 9.0), (0.0, 9.05)], 10, (96, 70, 48), rng, 0.04, 0.03))
    for i, y in enumerate((2.2, 4.6, 7.0)):
        wood = shade((120, 88, 58), 0.05, rng)
        m.add(hull([V(x, yy, z) for x in (-0.75, 0.75) for yy in (y - 1.0, y + 1.0) for z in (-0.45, 0.2)] + [V(0, y + 0.1, -0.95), V(0, y + 1.15, -0.5)], wood))
        add_box(m, (0, y + 0.6, -0.62), (1.4, 0.2, 0.3), shade(DARK, 0.04, rng))  # brow
        for x in (-0.33, 0.33):
            add_box(m, (x, y + 0.3, -0.7), (0.3, 0.2, 0.1), GOLD if i == 1 else (30, 26, 24))
        add_box(m, (0, y - 0.45, -0.72), (0.7, 0.16, 0.1), (150, 40, 36))
        if i == 0:  # a beard
            m.add(hull([V(-0.5, y - 0.55, -0.6), V(0.5, y - 0.55, -0.6), V(0, y - 1.3, -0.65), V(0, y - 0.6, -0.3)], (110, 80, 54)))
        if i == 2:  # horns
            for s_ in (-1, 1):
                add_cyl(m, (s_ * 0.6, y + 0.8, -0.2), (s_ * 1.2, y + 1.6, -0.3), 0.14, CREAM, 5, 0.04)
    for s_ in (-1, 1):
        m.add(hull([V(s_ * 0.5, 8.0, -0.15), V(s_ * 0.5, 8.6, -0.15), V(s_ * 2.6, 8.9, -0.1), V(s_ * 2.3, 8.2, -0.1), V(s_ * 1.4, 7.8, -0.1), V(s_ * 1.4, 8.3, 0.15)], DARK))
        for k in range(3):
            add_box(m, (s_ * (1.0 + k * 0.5), 8.35 + k * 0.08, -0.25), (0.08, 0.5, 0.06), (150, 40, 36))
    raven = (28, 28, 32)
    m.add(blob(0.5, raven, rng, 1, 0.05, 0.02, (0.8, 0.75, 1.2)), T(0, 9.45, 0.1))
    m.add(blob(0.3, raven, rng, 1, 0.05, 0.02), T(0, 9.95, -0.35))
    m.add(hull([V(0, 9.95, -0.6), V(0.08, 9.9, -0.6), V(-0.08, 9.9, -0.6), V(0, 9.85, -0.95)], (60, 56, 50)))
    m.add(hull([V(-0.25, 9.4, 0.5), V(0.25, 9.4, 0.5), V(0, 9.2, 1.1), V(0, 9.5, 0.6)], raven))
    return m


def decor_antlers():
    """An antler arch: two carved posts, a beam with a stag skull and great
    antlers, and an iron cup of fire at each post top (the game's flames sit
    at (+-3, 7.9, -0.6))."""
    m = Mesh(127)
    rng = m.rng
    bone = (220, 205, 180)
    for x in (-3, 3):
        add_cyl(m, (x, 0, 0), (x, 7.5, 0), 0.32, shade(DARK, 0.05, rng), 8, 0.28)
        for y in (1.2, 5.6):
            add_cyl(m, (x, y, 0), (x, y + 0.25, 0), 0.36, (150, 40, 36), 8)
        # iron bracket and cup holding the fire
        add_beam(m, (x, 7.1, -0.2), (x, 7.55, -0.6), 0.08, IRON)
        m.add(lathe([(0.1, 7.5), (0.3, 7.65), (0.32, 7.85), (0.0, 7.7)], 8, IRON), T(x, 0, -0.6))
    add_box(m, (0, 7.6, 0), (7.4, 0.6, 0.6), shade(DARK, 0.04, rng), bevel=0.06)
    for x in (-3.4, 3.4):
        m.add(hull([V(x, 7.3, -0.3), V(x, 7.9, -0.3), V(x, 7.3, 0.3), V(x, 7.9, 0.3), V(x * 1.08, 8.2, 0)], shade(DARK, 0.05, rng)))
    # the skull
    m.add(hull([V(x, y, z) for x in (-0.4, 0.4) for y in (8.0, 8.7) for z in (-0.15, 0.3)] + [V(0, 7.9, -0.75), V(0.15, 8.2, -0.75), V(-0.15, 8.2, -0.75)], bone))
    for x in (-0.2, 0.2):
        add_box(m, (x, 8.45, -0.18), (0.16, 0.16, 0.06), (40, 36, 34))
    # antlers: a main beam curving out and up, tines off it
    for s_ in (-1, 1):
        pts = []
        for i in range(7):
            t = i / 6
            pts.append(V(s_ * (0.35 + 2.0 * t), 8.6 + 2.4 * math.sin(t * 1.5) - 0.3 * t, -0.1 + 0.25 * t))
        for i, (p, q) in enumerate(zip(pts, pts[1:])):
            add_cyl(m, p, q, 0.12 - 0.012 * i, bone, 5)
        for i in (2, 3, 4, 5):
            p = pts[i]
            add_cyl(m, p, p + V(-s_ * 0.15, 0.8 - i * 0.06, -0.15), 0.07, bone, 4, 0.02)
    return m


def decor_woodpile():
    """Split logs stacked for winter under a little plank roof, a chopping
    block with an axe in it and a few split pieces on the ground."""
    m = Mesh(128)
    rng = m.rng
    for row in range(3):
        for i in range(5 - row):
            z = -1.8 + i * 0.9 + row * 0.45
            y = 0.45 + row * 0.8
            ln = 4.2 + rng.uniform(-0.2, 0.2)
            tris, mat = cyl_between((-ln / 2, y, z), (ln / 2, y, z), 0.45, shade(WOOD, 0.12, rng), 8)
            tris = [(a, b, c, (196, 160, 112) if abs(a[0] - b[0]) < 1e-6 and abs(b[0] - c[0]) < 1e-6 else col) for a, b, c, col in tris]
            m.add(tris, mat)
    # a lean-to roof of planks on four poles
    for x in (-2.3, 2.3):
        add_cyl(m, (x, 0, -2.3), (x, 2.8, -2.3), 0.1, WEATHER, 5)
        add_cyl(m, (x, 0, 2.0), (x, 3.3, 2.0), 0.1, WEATHER, 5)
    for k in range(6):
        x0 = -2.6 + k * 0.88
        m.add(slab_between([V(x0, 2.85, -2.6), V(x0, 3.4, 2.3)], [V(x0 + 0.9, 2.85, -2.6), V(x0 + 0.9, 3.4, 2.3)], 0.14, shade((92, 70, 52), 0.08, rng), rng, 0.04))
    # chopping block and axe
    add_cyl(m, (2.6, 0, -0.2), (2.6, 0.9, -0.2), 0.5, WEATHER, 9)
    m.add(lathe([(0.0, 0.89), (0.5, 0.89), (0.5, 0.91), (0.0, 0.91)], 9, (196, 160, 112)), T(2.6, 0, -0.2))
    add_cyl(m, (2.6, 0.95, -0.1), (2.7, 2.0, 0.6), 0.05, (138, 100, 64), 5)
    m.add(hull([V(2.45, 0.85, -0.25), V(2.75, 0.85, -0.25), V(2.45, 1.2, -0.05), V(2.75, 1.2, -0.05), V(2.6, 0.95, -0.55)], STEEL))
    for k in range(3):
        add_box(m, (2.2 + rng.uniform(-0.5, 0.5), 0.12, 1.2 + rng.uniform(-0.4, 0.4)), (0.9, 0.22, 0.35), (186, 150, 104), RY(rng.uniform(0, 3)))
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
    "TraderStall": trader_stall,
    "Palisade": palisade,
    "Tree_Pine": pine,
    "Tree_Spruce": spruce,
    "Tree_Birch": birch,
    "Rock": rock,
    "Bush": bush,
    "Longship": longship,
    "Deer": deer,
    "Boar": boar,
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
    "Dock": dock,
    "Jetty": lambda: dock(28),
    "PalisadeGate": palisade_gate,
    "DecorTorch": decor_torch,
    "DecorBrazier": decor_brazier,
    "DecorRuneStone": decor_runestone,
    "DecorBanner": decor_banner,
    "DecorShieldRack": decor_shieldrack,
    "DecorTotem": decor_totem,
    "DecorAntlers": decor_antlers,
    "DecorWoodpile": decor_woodpile,
    "Shield": shield,
}

# The ones the game swaps in (Shield is only an extra for your own builds).
SLOTS = [name for name in ASSETS if name != "Shield"]
