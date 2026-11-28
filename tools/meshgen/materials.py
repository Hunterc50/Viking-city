"""
Split a mesh into one piece per Roblox material (wood, stone, thatch, ...)
and per shade, so the game can show each piece with Roblox's own textured
materials (wood grain, slate, fabric) instead of flat colour.

Each piece is named  Mat_<Material>_<rrggbb>  and holds triangles of that
material whose colours are close to that shade. The game reads the name,
sets the MeshPart's Material and Color, and drops the flat palette texture.
"""

import colorsys

from mesh import Mesh

# shades per material: more keeps variety, fewer keeps the part count low
SHADES = {"Glow": 1, "Wood": 3, "Stone": 2, "Thatch": 2, "Leaves": 3, "Cloth": 3, "Metal": 1}


def classify(rgb):
    r, g, b = (c / 255 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    hue = h * 360
    if v >= 0.97 and s > 0.6 and 10 <= hue <= 48:
        return "Glow"  # embers and hot iron: shown as Neon, so they shine
    if v > 0.75 and s < 0.3 and 25 <= hue <= 65:
        return "Cloth"  # cream: sail canvas, linen
    if s < 0.16:
        return "Metal" if (b * 255 - r * 255 >= 4 and v < 0.62) else "Stone"
    if s < 0.26 and 40 <= hue <= 110:
        return "Stone"  # mossy, weathered greys
    if 65 <= hue <= 170:
        return "Leaves"
    if 170 < hue < 330 and s > 0.22:
        return "Cloth"
    if (hue < 14 or hue >= 330) and s > 0.5 and v > 0.35:
        return "Cloth"
    if 32 <= hue <= 62 and v > 0.5 and s > 0.25:
        return "Thatch"
    return "Wood"


def _lum(rgb):
    return 0.3 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]


# models that read best in one material all over
FORCE = {"Deer": "Cloth"}


def split(mesh, name=None):
    """[(piece name, Mesh)] for `mesh`, one piece per material and shade."""
    by_class = {}
    for t in mesh.tris:
        by_class.setdefault(FORCE.get(name) or classify(t[3]), []).append(t)
    pieces = []
    for cls in sorted(by_class):
        tris = by_class[cls]
        n = min(SHADES.get(cls, 2), len({t[3] for t in tris}))
        tris.sort(key=lambda t: _lum(t[3]))
        # equal-sized luminance bands
        for k in range(n):
            band = tris[k * len(tris) // n:(k + 1) * len(tris) // n]
            if not band:
                continue
            avg = [round(sum(t[3][i] for t in band) / len(band)) for i in range(3)]
            m = Mesh()
            m.tris = band
            name = "Mat_%s_%02x%02x%02x" % (cls, *avg)
            pieces.append((name, m))
    return pieces
