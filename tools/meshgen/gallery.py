"""Draws meshes/preview.png: a labelled picture of every slot."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw
from assets import ASSETS, SLOTS
from preview import render

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TOOLS = ("Axe", "Pickaxe", "Bow", "Sword", "Torch")
s, W = 320, 5
img = Image.new("RGB", (W * s, ((len(SLOTS) + W - 1) // W) * (s + 28)), (40, 34, 28))
d = ImageDraw.Draw(img)
tmp = os.path.join(ROOT, "meshes", "_tile.png")
for i, n in enumerate(SLOTS):
    render(ASSETS[n](), tmp, s, 1.4 if n in TOOLS else 0.6, 0.3)
    x, y = (i % W) * s, (i // W) * (s + 28)
    img.paste(Image.open(tmp), (x, y))
    d.text((x + 8, y + s + 8), n, fill=(214, 170, 92))
os.remove(tmp)
img.save(os.path.join(ROOT, "meshes", "preview.png"))
