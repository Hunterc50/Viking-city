"""
A tiny procedural mesh kit: build shapes from triangles with a colour each,
then write them as .glb (one file, texture inside) and .obj/.mtl/.png.

Colours become cells of a small palette texture, so every face keeps its own
shade on any importer that reads textures (Roblox Studio's 3D Importer does).
Units are studs; +Y is up; Roblox and glTF share the same axes.
"""

import io
import json
import math
import random
import struct

import numpy as np
from PIL import Image

# ----------------------------------------------------------------------------- maths


def T(x=0.0, y=0.0, z=0.0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def S(x=1.0, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return np.diag([x, y, z, 1.0])


def RX(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1.0]])


def RY(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1.0]])


def RZ(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1.0]])


def M(*ms):
    out = np.eye(4)
    for m in ms:
        out = out @ m
    return out


def look_along(direction):
    """A rotation turning +Y to point along `direction`."""
    d = np.array(direction, dtype=float)
    d /= np.linalg.norm(d)
    up = np.array([0.0, 1.0, 0.0])
    axis = np.cross(up, d)
    s = np.linalg.norm(axis)
    c = float(np.dot(up, d))
    if s < 1e-8:
        return np.eye(4) if c > 0 else RX(math.pi)
    axis /= s
    a = math.atan2(s, c)
    x, y, z = axis
    C = 1 - math.cos(a)
    sa, ca = math.sin(a), math.cos(a)
    r = np.array(
        [
            [ca + x * x * C, x * y * C - z * sa, x * z * C + y * sa],
            [y * x * C + z * sa, ca + y * y * C, y * z * C - x * sa],
            [z * x * C - y * sa, z * y * C + x * sa, ca + z * z * C],
        ]
    )
    m = np.eye(4)
    m[:3, :3] = r
    return m


# ----------------------------------------------------------------------------- colour


def shade(rgb, amount, rng):
    k = 1 + rng.uniform(-amount, amount)
    return tuple(int(max(0, min(255, round(c * k / 3) * 3))) for c in rgb)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ----------------------------------------------------------------------------- mesh


class Mesh:
    def __init__(self, seed=1):
        self.tris = []  # (p0, p1, p2, rgb)
        self.rng = random.Random(seed)

    # -- low level
    def tri(self, a, b, c, rgb):
        self.tris.append((np.array(a, float), np.array(b, float), np.array(c, float), tuple(rgb)))

    def quad(self, a, b, c, d, rgb):
        self.tri(a, b, c, rgb)
        self.tri(a, c, d, rgb)

    def add(self, tris, m=None):
        """Adds (p0, p1, p2, rgb) triangles, transformed by matrix m."""
        for a, b, c, rgb in tris:
            if m is not None:
                a = (m @ np.append(a, 1.0))[:3]
                b = (m @ np.append(b, 1.0))[:3]
                c = (m @ np.append(c, 1.0))[:3]
            self.tris.append((np.array(a, float), np.array(b, float), np.array(c, float), tuple(rgb)))

    def count(self):
        return len(self.tris)


def _outward(tris, centre_fn):
    """Flips triangles whose normal points toward the shape's inside."""
    out = []
    for a, b, c, rgb in tris:
        n = np.cross(b - a, c - a)
        mid = (a + b + c) / 3
        if np.dot(n, mid - centre_fn(mid)) < 0:
            b, c = c, b
        out.append((a, b, c, rgb))
    return out


# ----------------------------------------------------------------------------- primitives
# Each returns a list of triangles in local space.


def box(sx, sy, sz, rgb, rng=None, vary=0.0, bevel=0.0):
    """A box centred on the origin. With bevel > 0 the edges are chamfered."""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    tris = []
    col = lambda: shade(rgb, vary, rng) if rng and vary else rgb  # noqa: E731
    if bevel <= 0:
        v = [np.array([x, y, z]) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for f in faces:
            c = col()
            tris.append((v[f[0]], v[f[1]], v[f[2]], c))
            tris.append((v[f[0]], v[f[2]], v[f[3]], c))
        return _outward(tris, lambda p: np.zeros(3))
    # chamfered box: the convex hull of three inset boxes
    b = min(bevel, hx * 0.45, hy * 0.45, hz * 0.45)
    pts = []
    for (ax, ay, az) in ((hx, hy - b, hz - b), (hx - b, hy, hz - b), (hx - b, hy - b, hz)):
        for x in (-ax, ax):
            for y in (-ay, ay):
                for z in (-az, az):
                    pts.append(np.array([x, y, z]))
    return hull(pts, rgb, rng, vary)


def hull(points, rgb, rng=None, vary=0.0):
    """Convex hull of points (gift wrapping via scipy if present, else brute force)."""
    pts = np.array(points, float)
    try:
        from scipy.spatial import ConvexHull

        h = ConvexHull(pts)
        simplices = h.simplices
    except Exception:
        simplices = _brute_hull(pts)
    centre = pts.mean(axis=0)
    tris = []
    for s in simplices:
        c = shade(rgb, vary, rng) if rng and vary else rgb
        tris.append((pts[s[0]], pts[s[1]], pts[s[2]], c))
    return _outward(tris, lambda p: centre)


def _brute_hull(pts):
    n = len(pts)
    faces = []
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                nrm = np.cross(pts[j] - pts[i], pts[k] - pts[i])
                if np.linalg.norm(nrm) < 1e-9:
                    continue
                d = (pts - pts[i]) @ nrm
                if np.all(d <= 1e-7) or np.all(d >= -1e-7):
                    faces.append((i, j, k))
    return faces


def lathe(profile, segments, rgb, rng=None, vary=0.0, noise=0.0, phase=0.0, colours=None, caps=True):
    """Spins a profile [(radius, y), ...] (bottom to top) around +Y.
    `noise` jitters the radius of each vertex for a hand-made look.
    `colours` (optional) gives one colour per profile band."""
    rings = []
    for i, (r, y) in enumerate(profile):
        ring = []
        for s in range(segments):
            a = phase + s / segments * math.tau
            rr = r * (1 + (rng.uniform(-noise, noise) if rng and noise and 0 < r else 0))
            ring.append(np.array([math.cos(a) * rr, y, math.sin(a) * rr]))
        rings.append(ring)
    tris = []
    for i in range(len(rings) - 1):
        band = colours[i] if colours else rgb
        for s in range(segments):
            a, b = rings[i][s], rings[i][(s + 1) % segments]
            c, d = rings[i + 1][(s + 1) % segments], rings[i + 1][s]
            col = shade(band, vary, rng) if rng and vary else band
            tris.append((a, b, c, col))
            tris.append((a, c, d, col))
    # caps
    for idx, ring in ((0, rings[0]), (-1, rings[-1])):
        r, y = profile[idx]
        if r > 1e-6 and caps:
            centre = np.array([0.0, y, 0.0])
            for s in range(segments):
                tris.append((centre, ring[s], ring[(s + 1) % segments], rgb))

    def centre_fn(p):
        return np.array([0.0, p[1], 0.0])

    # flip by radial direction, caps by vertical
    out = []
    ys = [y for _, y in profile]
    lo, hi = min(ys), max(ys)
    for a, b, c, col in tris:
        mid = (a + b + c) / 3
        n = np.cross(b - a, c - a)
        if abs(mid[1] - lo) < 1e-6 and abs(a[1] - lo) < 1e-6 and abs(b[1] - lo) < 1e-6 and abs(c[1] - lo) < 1e-6:
            want = np.array([0, -1.0, 0])
        elif abs(mid[1] - hi) < 1e-6 and abs(a[1] - hi) < 1e-6 and abs(b[1] - hi) < 1e-6 and abs(c[1] - hi) < 1e-6:
            want = np.array([0, 1.0, 0])
        else:
            want = mid - centre_fn(mid)
        if np.dot(n, want) < 0:
            b, c = c, b
        out.append((a, b, c, col))
    return out


def cylinder(r, h, segments, rgb, r_top=None, rng=None, vary=0.0, noise=0.0):
    """Along +Y from y=0 to y=h."""
    rt = r if r_top is None else r_top
    return lathe([(r, 0.0), (rt, h)], segments, rgb, rng, vary, noise)


def blob(radius, rgb, rng, detail=1, noise=0.25, vary=0.08, squash=(1, 1, 1)):
    """A lumpy icosphere: rocks, leaf clumps, hay."""
    t = (1 + 5 ** 0.5) / 2
    verts = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    verts = [np.array(v, float) / np.linalg.norm(v) for v in verts]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(detail):
        cache = {}

        def mid(i, j):
            key = (min(i, j), max(i, j))
            if key not in cache:
                v = verts[i] + verts[j]
                verts.append(v / np.linalg.norm(v))
                cache[key] = len(verts) - 1
            return cache[key]

        nf = []
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = nf
    disp = [1 + rng.uniform(-noise, noise) for _ in verts]
    sq = np.array(squash, float)
    pts = [v * radius * disp[i] * sq for i, v in enumerate(verts)]
    tris = []
    for a, b, c in faces:
        tris.append((pts[a], pts[b], pts[c], shade(rgb, vary, rng)))
    return _outward(tris, lambda p: np.zeros(3))


def strip_between(path_a, path_b, rgb, rng=None, vary=0.0):
    """Quads between two matching polylines (open surface, both sides)."""
    tris = []
    for i in range(len(path_a) - 1):
        a, b, c, d = path_a[i], path_a[i + 1], path_b[i + 1], path_b[i]
        col = shade(rgb, vary, rng) if rng and vary else rgb
        tris += [(a, b, c, col), (a, c, d, col), (a, c, b, col), (a, d, c, col)]
    return tris


def slab_between(path_a, path_b, thickness, rgb, rng=None, vary=0.0, up=(0, 1, 0)):
    """A thick surface between two polylines: top, bottom and edges.
    The top faces the `up` side; every face is wound to point outward."""
    up = np.array(up, float)
    n = len(path_a)
    top_a = [np.array(p, float) for p in path_a]
    top_b = [np.array(p, float) for p in path_b]
    nrms = []
    for i in range(n):
        j = min(i, n - 2)
        e1 = top_a[j + 1] - top_a[j]
        e2 = top_b[i] - top_a[i]
        nrm = np.cross(e1, e2)
        ln = np.linalg.norm(nrm)
        nrm = nrm / ln if ln > 1e-9 else up
        if np.dot(nrm, up) < 0:
            nrm = -nrm
        nrms.append(nrm)
    bot_a = [top_a[i] - nrms[i] * thickness for i in range(n)]
    bot_b = [top_b[i] - nrms[i] * thickness for i in range(n)]
    tris = []

    def face(a, b, c, d, col, want):
        nn = np.cross(b - a, c - a)
        if np.dot(nn, want) < 0:
            a, b, c, d = a, d, c, b
        tris.append((a, b, c, col))
        tris.append((a, c, d, col))

    dark = None
    for i in range(n - 1):
        col = shade(rgb, vary, rng) if rng and vary else rgb
        dark = mix(col, (0, 0, 0), 0.25)
        nm = (nrms[i] + nrms[i + 1]) / 2
        across = (top_a[i] + top_a[i + 1] - top_b[i] - top_b[i + 1]) / 2
        face(top_a[i], top_a[i + 1], top_b[i + 1], top_b[i], col, nm)
        face(bot_a[i], bot_b[i], bot_b[i + 1], bot_a[i + 1], dark, -nm)
        face(top_a[i], bot_a[i], bot_a[i + 1], top_a[i + 1], dark, across)
        face(top_b[i], top_b[i + 1], bot_b[i + 1], bot_b[i], dark, -across)
    along0 = top_a[0] - top_a[1]
    along1 = top_a[-1] - top_a[-2]
    face(top_a[0], top_b[0], bot_b[0], bot_a[0], dark, along0)
    face(top_a[-1], top_b[-1], bot_b[-1], bot_a[-1], dark, along1)
    return tris


# ----------------------------------------------------------------------------- export

CELL = 8  # pixels per palette cell (wide enough to survive mipmaps)
GRID = 32  # cells per row -> up to 1024 colours, 256 px texture


class Palette:
    def __init__(self, colours=0):
        self.index = {}
        self.grid = GRID
        while self.grid * self.grid < colours:
            self.grid *= 2

    def uv(self, rgb):
        if rgb not in self.index:
            assert len(self.index) < self.grid * self.grid, "too many colours for the palette"
            self.index[rgb] = len(self.index)
        i = self.index[rgb]
        g = self.grid
        cx, cy = i % g, i // g
        return ((cx + 0.5) / g, (cy + 0.5) / g)

    def image(self):
        g = self.grid
        img = Image.new("RGB", (g * CELL, g * CELL), (128, 128, 128))
        px = img.load()
        for rgb, i in self.index.items():
            cx, cy = i % g, i // g
            for x in range(CELL):
                for y in range(CELL):
                    px[cx * CELL + x, cy * CELL + y] = rgb
        return img


def _arrays(tris, palette):
    pos, nrm, uv = [], [], []
    for a, b, c, rgb in tris:
        n = np.cross(b - a, c - a)
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            continue
        n = n / ln
        u = palette.uv(rgb)
        for p in (a, b, c):
            pos.append(p)
            nrm.append(n)
            uv.append(u)
    return np.array(pos, np.float32), np.array(nrm, np.float32), np.array(uv, np.float32)


def write_glb(path, parts, max_tris=9000):
    """parts: list of (name, Mesh). Big meshes are split into several nodes."""
    palette = Palette(len({t[3] for _, mesh in parts for t in mesh.tris}))
    chunks = []
    groups = []  # (name, [chunk indices]) for each part
    for name, mesh in parts:
        tris = mesh.tris
        n = max(1, math.ceil(len(tris) / max_tris))
        idx = []
        for k in range(n):
            sub = tris[k * max_tris:(k + 1) * max_tris]
            if sub:
                idx.append(len(chunks))
                chunks.append((name if n == 1 else f"{name}_{k + 1}", sub))
        groups.append((name, idx))
    arrays = [(name, *_arrays(tris, palette)) for name, tris in chunks]
    png = io.BytesIO()
    palette.image().save(png, format="PNG")
    png_bytes = png.getvalue()

    bin_parts = []
    offset = 0
    views, accessors, meshes, nodes = [], [], [], []

    def push(data, target=None):
        nonlocal offset
        raw = data.tobytes() if hasattr(data, "tobytes") else data
        pad = (4 - len(raw) % 4) % 4
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(raw)}
        if target:
            view["target"] = target
        views.append(view)
        bin_parts.append(raw + b"\0" * pad)
        offset += len(raw) + pad
        return len(views) - 1

    img_view = push(png_bytes)
    for name, pos, nrm, uv in arrays:
        idx = np.arange(len(pos), dtype=np.uint32)
        vp = push(pos, 34962)
        vn = push(nrm, 34962)
        vt = push(uv, 34962)
        vi = push(idx, 34963)
        base = len(accessors)
        accessors += [
            {"bufferView": vp, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": pos.min(axis=0).tolist(), "max": pos.max(axis=0).tolist()},
            {"bufferView": vn, "componentType": 5126, "count": len(nrm), "type": "VEC3"},
            {"bufferView": vt, "componentType": 5126, "count": len(uv), "type": "VEC2"},
            {"bufferView": vi, "componentType": 5125, "count": len(idx), "type": "SCALAR"},
        ]
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": base, "NORMAL": base + 1, "TEXCOORD_0": base + 2}, "indices": base + 3, "material": 0}]})
        nodes.append({"name": name, "mesh": len(meshes) - 1})
    # a big part split into chunks gets a parent node with its own name
    roots = []
    for name, idx in groups:
        if len(idx) == 1:
            roots.append(idx[0])
        else:
            nodes.append({"name": name, "children": idx})
            roots.append(len(nodes) - 1)

    gltf = {
        "asset": {"version": "2.0", "generator": "viking-city meshgen"},
        "scene": 0,
        "scenes": [{"nodes": roots}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [{"name": "Palette", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.9}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728}],
        "images": [{"bufferView": img_view, "mimeType": "image/png", "name": "palette"}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": offset}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    binary = b"".join(bin_parts)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binary)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)
    return sum(len(t) for _, t in chunks)


def write_obj(path_base, parts, texture_name):
    """Writes path_base.obj and path_base.mtl using a shared palette png."""
    palette = Palette(len({t[3] for _, mesh in parts for t in mesh.tris}))
    lines = [f"mtllib {path_base.split('/')[-1]}.mtl"]
    vi = 1
    for name, mesh in parts:
        lines.append(f"o {name}")
        lines.append("usemtl Palette")
        for a, b, c, rgb in mesh.tris:
            n = np.cross(b - a, c - a)
            ln = np.linalg.norm(n)
            if ln < 1e-12:
                continue
            n /= ln
            u, v = palette.uv(rgb)
            for p in (a, b, c):
                lines.append(f"v {p[0]:.4f} {p[1]:.4f} {p[2]:.4f}")
            lines.append(f"vt {u:.5f} {1 - v:.5f}")
            lines.append(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}")
            k = (vi - 1) // 3 + 1
            lines.append(f"f {vi}/{k}/{k} {vi + 1}/{k}/{k} {vi + 2}/{k}/{k}")
            vi += 3
    with open(path_base + ".obj", "w") as f:
        f.write("\n".join(lines) + "\n")
    with open(path_base + ".mtl", "w") as f:
        f.write(f"newmtl Palette\nKd 1 1 1\nKa 0 0 0\nKs 0 0 0\nmap_Kd {texture_name}\n")
    palette.image().save(path_base.rsplit("/", 1)[0] + "/" + texture_name)
