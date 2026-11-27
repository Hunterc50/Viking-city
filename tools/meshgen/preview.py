"""Renders a quick shaded preview of assets (painter's algorithm) to PNGs."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from assets import ASSETS

def render(mesh, path, size=420, yaw=0.7, pitch=0.35):
    tris = mesh.tris
    P = np.array([[a, b, c] for a, b, c, _ in tris])
    cols = [t[3] for t in tris]
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    R = np.array([[cy, 0, -sy], [0, 1, 0], [sy, 0, cy]]) 
    R = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]]) @ R
    Q = P @ R.T
    mn, mx = Q.reshape(-1, 3).min(0), Q.reshape(-1, 3).max(0)
    scale = (size * 0.9) / max(mx[0] - mn[0], mx[1] - mn[1])
    ctr = (mn + mx) / 2
    img = Image.new("RGB", (size, size), (150, 175, 200))
    d = ImageDraw.Draw(img)
    light = np.array([0.4, 0.8, -0.45]); light /= np.linalg.norm(light)
    order = np.argsort(Q[:, :, 2].mean(1))[::-1]  # far first (camera looks +z)
    for i in order:
        a, b, c = P[i]
        n = np.cross(b - a, c - a); ln = np.linalg.norm(n)
        if ln < 1e-12: continue
        n /= ln
        nv = R @ n
        if nv[2] > 0: continue  # backface
        k = 0.45 + 0.55 * max(0, float(n @ light))
        col = tuple(int(min(255, ch * k)) for ch in cols[i])
        pts = [((q[0] - ctr[0]) * scale + size / 2, size / 2 - (q[1] - ctr[1]) * scale) for q in Q[i]]
        d.polygon(pts, fill=col)
    img.save(path)

if __name__ == "__main__":
    out = sys.argv[1]
    names = sys.argv[2:] or list(ASSETS)
    os.makedirs(out, exist_ok=True)
    for n in names:
        render(ASSETS[n](), os.path.join(out, n + ".png"))
        print("ok", n)
