"""
Settler meshes: a man and a woman in five levels of gear (the village rank).
  1 Settler    wool clothes, leather shoes          (woman: apron dress, brooches)
  2 Chieftain  + fur mantle, fur boots, fur hat
  3 Hersir     + leather jerkin, bracers, iron cap  (woman: red apron, headscarf)
  4 Jarl       + mail shirt, nose-guard helm, cloak, back shield (woman: shieldmaiden)
  5 King       + gold-trimmed mail, spectacle helm with crest, red cloak, arm rings

Each settler is four pieces that ride on the game's moving villager rig, in the
rig part's own space (studs, at full adult size):
  Body  the torso part, 2 x 2 x 1, centred      (skirts and cloaks hang below)
  Head  the head part, centred 0.5 above the torso top
  Arm   an arm, 1 x 2 x 1, centred (used for both arms)
  Leg   a leg, 1 x 2 x 1, centred (used for both legs), foot at y = -1
Faces look toward -Z.
"""

import math

import numpy as np

from assets import V, add_box, add_cyl, disc, hull, recolour
from mesh import RX, RY, RZ, M, T, Mesh, blob, lathe, mix

SKIN = (232, 190, 152)
LIP = (196, 132, 112)
EYE = (40, 34, 30)
WHITE = (236, 232, 224)
LEATHER = (110, 74, 46)
DARK_LEATHER = (72, 50, 34)
FUR = (128, 104, 80)
FUR_LIGHT = (176, 156, 128)
MAIL = (128, 132, 138)
MAIL_DARK = (98, 102, 108)
STEEL = (166, 170, 176)
GOLD = (214, 172, 84)
BRONZE = (176, 128, 64)
LINEN = (214, 200, 170)

HAIR = {"Man": (150, 92, 46), "Woman": (214, 176, 104)}

# clothes colours by gear level
MAN_TUNIC = {1: (150, 118, 82), 2: (60, 86, 130), 3: (140, 52, 42), 4: (60, 86, 130), 5: (140, 40, 36)}
WOMAN_APRON = {1: (86, 110, 66), 2: (60, 86, 130), 3: (150, 52, 44), 4: (110, 74, 46), 5: (120, 40, 60)}
TROUSERS = (86, 76, 64)
CLOAK = {4: (52, 70, 104), 5: (150, 36, 34)}


def ellipsoid(m, centre, radii, rgb, detail=2, noise=0.0, vary=0.02):
    m.add(blob(1.0, rgb, m.rng, detail, noise, vary, radii), T(*centre))


# ----------------------------------------------------------------------------- head


def head(gender, gear):
    m = Mesh(100 + gear + (50 if gender == "Woman" else 0))
    hair = HAIR[gender]
    # skull and jaw
    ellipsoid(m, (0, 0.05, 0), (0.55, 0.62, 0.58), SKIN)
    ellipsoid(m, (0, -0.25, -0.08), (0.44, 0.36, 0.46), SKIN)
    # neck
    add_cyl(m, (0, -0.95, 0.05), (0, -0.4, 0.05), 0.27, SKIN, 10)
    # ears
    for s in (-1, 1):
        ellipsoid(m, (s * 0.55, 0.0, 0.05), (0.08, 0.16, 0.11), SKIN, 1)
    # nose
    m.add(hull([V(0, 0.12, -0.56), V(0.09, -0.12, -0.62), V(-0.09, -0.12, -0.62), V(0, -0.16, -0.7), V(0, -0.14, -0.55)], SKIN))
    # eyes: whites, irises, brows
    for s in (-1, 1):
        add_box(m, (s * 0.2, 0.06, -0.545), (0.17, 0.09, 0.04), WHITE)
        add_box(m, (s * 0.2, 0.06, -0.57), (0.08, 0.09, 0.03), (70, 96, 130))
        add_box(m, (s * 0.2, 0.06, -0.585), (0.035, 0.05, 0.02), EYE)
        add_box(m, (s * 0.21, 0.2, -0.55), (0.22, 0.05, 0.06), mix(hair, (0, 0, 0), 0.3), RZ(s * -0.12))
    # mouth
    add_box(m, (0, -0.33, -0.5), (0.2, 0.04, 0.04), LIP)

    helmet = gender == "Man" and gear >= 3
    if gender == "Man":
        # beard: full and braided at the tip, longer with rank
        ln = 0.35 + 0.08 * gear
        m.add(blob(1.0, hair, m.rng, 1, 0.15, 0.05, (0.46, 0.34, 0.3)), T(0, -0.42, -0.36))
        m.add(hull([V(0.38, -0.2, -0.3), V(-0.38, -0.2, -0.3), V(0.3, -0.5, -0.5), V(-0.3, -0.5, -0.5), V(0.12, -0.45 - ln, -0.45), V(-0.12, -0.45 - ln, -0.45), V(0, -0.2, -0.05)], hair, m.rng, 0.06))
        add_box(m, (0, -0.48 - ln, -0.45), (0.12, 0.12, 0.12), BRONZE if gear < 5 else GOLD)
        # moustache
        for s in (-1, 1):
            m.add(hull([V(0, -0.2, -0.6), V(s * 0.26, -0.33, -0.55), V(s * 0.22, -0.24, -0.6), V(0, -0.25, -0.62)], hair))
        if not helmet:
            ellipsoid(m, (0, 0.18, 0.08), (0.6, 0.55, 0.6), hair, 2, 0.06)
            # a short tail at the back
            add_cyl(m, (0, 0.0, 0.55), (0, -0.55, 0.62), 0.14, hair, 6, 0.08)
    else:
        # parted hair and a long braid down the back
        ellipsoid(m, (0, 0.2, 0.07), (0.6, 0.56, 0.6), hair, 2, 0.04)
        for k in range(6):
            y = -0.25 - k * 0.2
            m.add(blob(0.13 - k * 0.008, hair, m.rng, 1, 0.1, 0.05), T(0, y, 0.6 - k * 0.01))
        add_box(m, (0, -1.5, 0.58), (0.14, 0.1, 0.14), BRONZE)
        if gear == 3:
            # headscarf
            ellipsoid(m, (0, 0.27, 0.1), (0.64, 0.5, 0.62), (196, 176, 140), 2, 0.03)
        if gear >= 5:
            # gold circlet
            m.add(lathe([(0.62, 0.2), (0.62, 0.3)], 18, GOLD, caps=False), T(0, 0, 0.05))
            m.add(lathe([(0.6, 0.3), (0.6, 0.2)], 18, GOLD, caps=False), T(0, 0, 0.05))

    if gear == 2:
        # fur hat
        m.add(lathe([(0.66, 0.15), (0.68, 0.35), (0.6, 0.55), (0.3, 0.7), (0.0, 0.72)], 14, FUR, m.rng, 0.06, 0.05), T(0, 0.05, 0.05))
        m.add(lathe([(0.7, 0.12), (0.72, 0.32)], 14, FUR_LIGHT, m.rng, 0.06, 0.04, caps=False), T(0, 0.05, 0.05))
    if helmet:
        steel = STEEL if gear >= 5 else (118, 122, 128)
        # a rounded spangenhelm with a ridge and a brow band
        m.add(lathe([(0.66, 0.1), (0.66, 0.3), (0.58, 0.55), (0.36, 0.76), (0.0, 0.84)], 16, steel, m.rng, 0.03), T(0, 0.05, 0.05))
        m.add(lathe([(0.69, 0.08), (0.69, 0.24)], 16, GOLD if gear >= 5 else DARK_LEATHER, caps=False), T(0, 0.05, 0.05))
        m.add(lathe([(0.67, 0.24), (0.67, 0.08)], 16, GOLD if gear >= 5 else DARK_LEATHER, caps=False), T(0, 0.05, 0.05))
        add_box(m, (0, 0.62, 0.05), (0.09, 0.42, 1.2), mix(steel, (0, 0, 0), 0.15), RX(0.1))
        if gear >= 4:
            add_box(m, (0, 0.0, -0.68), (0.1, 0.42, 0.08), steel)  # nose guard
            # mail curtain over the neck
            m.add(lathe([(0.66, -0.45), (0.68, 0.1)], 16, MAIL_DARK, caps=False), T(0, 0.05, 0.12))
            m.add(lathe([(0.65, 0.1), (0.64, -0.45)], 16, MAIL_DARK, caps=False), T(0, 0.05, 0.12))
        if gear >= 5:
            for s in (-1, 1):
                m.add(lathe([(0.15, -0.03), (0.15, 0.03)], 10, GOLD, caps=False), M(T(s * 0.2, 0.06, -0.63), RX(math.pi / 2)))
                m.add(lathe([(0.15, 0.03), (0.15, -0.03)], 10, GOLD, caps=False), M(T(s * 0.2, 0.06, -0.63), RX(math.pi / 2)))
            m.add(hull([V(0, 0.9, 0.5), V(0, 1.2, 0.1), V(0, 1.15, -0.4), V(0, 0.88, -0.45), V(0.05, 0.9, 0), V(-0.05, 0.9, 0)], GOLD))
    return m


# ----------------------------------------------------------------------------- body


def torso_shape(m, rgb, waist=0.84, chest=0.98, depth=0.5, top=0.95, bottom=-1.0, shoulders=1.0):
    """A torso: rounded box from hips to shoulders, a little wider at the chest."""
    rows = [(bottom, waist, depth * 0.95), (-0.4, waist * 0.98, depth), (0.3, chest, depth * 1.04), (top - 0.2, shoulders, depth * 0.98), (top, shoulders * 0.9, depth * 0.85)]
    pts = []
    for y, w, d in rows:
        for a in range(12):
            t = a / 12 * math.tau
            x, z = math.cos(t), math.sin(t)
            # squarish: superellipse
            px = w * np.sign(x) * abs(x) ** 0.55
            pz = d * np.sign(z) * abs(z) ** 0.55
            pts.append((px, y, pz))
    m.add(hull([V(*p) for p in pts], rgb, m.rng, 0.03))


def skirt(m, top_y, bottom_y, r_top, r_bottom, rgb, depth=0.55, open_front=False):
    prof = [(r_top, top_y), (r_bottom, bottom_y)]
    tris = lathe(prof, 14, rgb, m.rng, 0.05, caps=False)
    m.add(tris, M(T(0, 0, 0), np.diag([1, 1, depth / max(r_top, r_bottom), 1])))
    tris = lathe([(r_bottom * 0.98, bottom_y), (r_top * 0.98, top_y)], 14, mix(rgb, (0, 0, 0), 0.3), caps=False)
    m.add(tris, M(T(0, 0, 0), np.diag([1, 1, depth / max(r_top, r_bottom), 1])))


def body(gender, gear):
    m = Mesh(200 + gear + (50 if gender == "Woman" else 0))
    if gender == "Man":
        tunic = MAN_TUNIC[gear]
        if gear >= 4:
            torso_shape(m, tunic)
            torso_shape(m, MAIL, waist=0.88, chest=1.02, depth=0.54)  # mail over the tunic
            skirt(m, -0.9, -1.75, 0.95, 1.08, MAIL)
            skirt(m, -1.7, -1.95, 1.05, 1.12, tunic)
        elif gear == 3:
            torso_shape(m, tunic)
            torso_shape(m, LEATHER, waist=0.88, chest=1.01, depth=0.53, top=0.8)
            skirt(m, -0.9, -1.7, 0.95, 1.06, LEATHER)
            # stitched panels
            for y in (-0.6, -0.2, 0.2, 0.55):
                add_box(m, (0, y, -0.55), (1.6, 0.05, 0.03), DARK_LEATHER)
        else:
            torso_shape(m, tunic)
            skirt(m, -0.9, -1.7, 0.92, 1.05, tunic)
            # embroidered neckline
            add_box(m, (0, 0.82, -0.47), (0.6, 0.12, 0.04), (200, 160, 80))
    else:
        apron = WOMAN_APRON[gear]
        if gear >= 4:
            # shieldmaiden: mail shirt over a long tunic, leather skirt
            torso_shape(m, LINEN, waist=0.72, chest=0.86, shoulders=0.88)
            torso_shape(m, MAIL, waist=0.76, chest=0.9, depth=0.52, shoulders=0.92)
            skirt(m, -0.9, -1.6, 0.85, 0.98, MAIL)
            skirt(m, -1.5, -2.6, 0.95, 1.08, apron)
        else:
            # underdress, apron dress held by two oval brooches with beads between
            torso_shape(m, LINEN, waist=0.72, chest=0.86, shoulders=0.88)
            torso_shape(m, apron, waist=0.75, chest=0.9, depth=0.52, top=0.55, shoulders=0.9)
            skirt(m, -0.9, -2.75, 0.8, 1.1, LINEN)
            skirt(m, -0.9, -2.55, 0.83, 1.12, apron)
            for s in (-1, 1):
                add_box(m, (s * 0.35, 0.7, -0.4), (0.12, 0.5, 0.05), apron)  # straps
                m.add(blob(1.0, BRONZE, m.rng, 1, 0.0, 0.03, (0.17, 0.12, 0.08)), T(s * 0.35, 0.45, -0.55))
            for k in range(7):
                t = k / 6
                x = -0.35 + 0.7 * t
                y = 0.42 - 0.22 * math.sin(math.pi * t)
                add_box(m, (x, y, -0.58), (0.08, 0.08, 0.08), [(60, 120, 150), (200, 150, 60), (160, 60, 50)][k % 3])
    # belt with a buckle and a knife / pouch
    belt_y = -0.82
    m.add(lathe([(1.0 if gender == "Man" else 0.86, belt_y - 0.1), (1.0 if gender == "Man" else 0.86, belt_y + 0.1)], 16, DARK_LEATHER, caps=False), np.diag([1, 1, 0.6, 1]))
    m.add(lathe([(0.98 if gender == "Man" else 0.84, belt_y + 0.1), (0.98 if gender == "Man" else 0.84, belt_y - 0.1)], 16, DARK_LEATHER, caps=False), np.diag([1, 1, 0.6, 1]))
    add_box(m, (0, belt_y, -0.6), (0.22, 0.2, 0.06), GOLD if gear >= 5 else STEEL)
    m.add(blob(1.0, LEATHER, m.rng, 1, 0.1, 0.05, (0.18, 0.22, 0.1)), T(0.62, belt_y - 0.3, -0.42))
    add_box(m, (-0.62, belt_y - 0.35, -0.45), (0.08, 0.5, 0.12), DARK_LEATHER, RZ(0.15))  # knife sheath

    if gear >= 2:
        # fur mantle over the shoulders
        m.add(blob(1.0, FUR, m.rng, 2, 0.12, 0.08, (1.18, 0.28, 0.68)), T(0, 0.92, 0.02))
    if gear >= 4:
        cloak = CLOAK[gear]
        # the cloak hangs from the shoulders down the back, pinned by a brooch
        pts_a = [V(-1.05, 0.9, 0.45), V(1.05, 0.9, 0.45)]
        prev = pts_a
        for k in range(1, 6):
            y = 0.9 - k * 0.55
            w = 1.05 + k * 0.08
            row = [V(-w, y, 0.5 + 0.04 * k), V(w, y, 0.5 + 0.04 * k)]
            for i in range(1):
                a, b, c, d = prev[0], prev[1], row[1], row[0]
                for tri in ((a, b, c), (a, c, d)):
                    m.tri(*tri, cloak)
                    m.tri(tri[0], tri[2], tri[1], mix(cloak, (0, 0, 0), 0.3))
            prev = row
        disc(m, (0.62, 0.72, -0.56), (0, 0, -1), 0.14, GOLD if gear >= 5 else STEEL, seg=10)
        if gear >= 5:
            add_box(m, (0, -0.95, -0.02), (2.08, 0.1, 1.12), GOLD)  # gold-trimmed hem of the mail
        if gender == "Man":
            # round shield slung on the back
            disc(m, (0, 0.05, 0.75), (0, 0, 1), 1.05, (168, 44, 38) if gear == 4 else GOLD, (150, 150, 156), (60, 60, 64), seg=16, paint=(224, 210, 178) if gear == 4 else (140, 40, 36))
    return m


def arm(gender, gear):
    m = Mesh(300 + gear + (50 if gender == "Woman" else 0))
    w = 0.42 if gender == "Man" else 0.36
    sleeve = {1: MAN_TUNIC[1], 2: MAN_TUNIC[2], 3: MAN_TUNIC[3], 4: MAIL, 5: MAIL}[gear] if gender == "Man" else (LINEN if gear < 4 else MAIL)
    # shoulder cap and sleeve
    m.add(blob(1.0, sleeve, m.rng, 2, 0.02, 0.03, (w * 1.15, 0.42, w * 1.1)), T(0, 0.65, 0))
    m.add(lathe([(w, -0.55), (w * 1.05, 0.2), (w * 1.1, 0.75)], 12, sleeve, m.rng, 0.03), T(0, 0, 0))
    # forearm (bare or sleeved) and the hand
    fore = SKIN if gear < 3 and gender == "Man" else sleeve
    m.add(lathe([(w * 0.86, -0.8), (w * 0.95, -0.5)], 12, fore, caps=False))
    m.add(lathe([(w * 0.95, -0.5), (w * 0.86, -0.8)], 12, fore, caps=False))
    m.add(blob(1.0, SKIN, m.rng, 1, 0.05, 0.02, (w * 0.85, 0.24, w * 0.75)), T(0, -0.98, -0.02))
    m.add(blob(1.0, SKIN, m.rng, 1, 0.05, 0.02, (0.1, 0.12, 0.1)), T(0.05, -0.98, -w * 0.7))  # thumb
    if gear >= 3:
        m.add(lathe([(w * 1.0, -0.78), (w * 1.05, -0.35)], 12, GOLD if gear >= 5 else DARK_LEATHER), T(0, 0, 0))
    if gear >= 5:
        m.add(lathe([(w * 1.12, 0.25), (w * 1.12, 0.36)], 12, GOLD), T(0, 0, 0))
    if gear >= 4:
        # mail sleeve ends in a ring
        m.add(lathe([(w * 1.14, -0.05), (w * 1.14, 0.03)], 12, MAIL_DARK))
    return m


def leg(gender, gear):
    m = Mesh(400 + gear + (50 if gender == "Woman" else 0))
    w = 0.44 if gender == "Man" else 0.38
    trousers = TROUSERS if gender == "Man" else LINEN
    m.add(lathe([(w * 0.9, -0.55), (w, 0.2), (w * 1.05, 1.0)], 12, trousers, m.rng, 0.03))
    # leg wraps (winingas) from ankle to knee
    wraps = (176, 156, 120) if gear < 3 else DARK_LEATHER
    for k in range(4):
        y = -0.8 + k * 0.14
        m.add(lathe([(w * 0.95, y), (w * 0.97, y + 0.1)], 12, wraps if k % 2 == 0 else mix(wraps, (0, 0, 0), 0.15)))
    # shoe or boot
    boot = gear >= 2
    col = DARK_LEATHER if boot else LEATHER
    m.add(hull([V(x, y, z) for x in (-w * 0.9, w * 0.9) for (y, z) in ((-1.0, -0.55), (-1.0, 0.4), (-0.75, 0.4), (-0.78, -0.5), (-0.62 if not boot else -0.3, 0.2), (-0.62 if not boot else -0.3, -0.25))], col))
    if boot:
        m.add(lathe([(w * 1.02, -0.4), (w * 1.08, -0.22)], 12, FUR_LIGHT, m.rng, 0.06))
    return m


PIECES = {"Head": head, "Body": body, "Arm": arm, "Leg": leg}


def settler(gender, gear):
    return [(piece, fn(gender, gear)) for piece, fn in PIECES.items()]


SETTLERS = {f"Settler_{g}_{k}": (g, k) for g in ("Man", "Woman") for k in range(1, 6)}
