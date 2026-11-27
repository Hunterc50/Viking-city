"""Writes every asset in assets.py to meshes/<Slot>.glb.
Usage: python3 tools/meshgen/build.py [--obj] [Slot ...]   (no slots = all)
--obj also writes meshes/obj/<Slot>.obj/.mtl/.png for other 3D tools."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from assets import ASSETS, SLOTS  # noqa: E402
from mesh import write_glb, write_obj  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "meshes")


def main(args):
    obj = "--obj" in args
    names = [a for a in args if a != "--obj"]
    os.makedirs(OUT, exist_ok=True)
    if obj:
        os.makedirs(os.path.join(OUT, "obj"), exist_ok=True)
    built = []
    for name in names or ASSETS:
        mesh = ASSETS[name]()
        n = write_glb(os.path.join(OUT, name + ".glb"), [(name, mesh)])
        if obj:
            write_obj(os.path.join(OUT, "obj", name), [(name, mesh)], name + ".png")
        built.append((name, mesh))
        print(f"{name:20s} {n:6d} triangles")
    if not names:
        # everything in one file: import once, every slot comes along
        n = write_glb(os.path.join(OUT, "VikingAssets.glb"), [(name, mesh) for name, mesh in built if name in SLOTS])
        print(f"{'VikingAssets':20s} {n:6d} triangles (all slots)")


if __name__ == "__main__":
    main(sys.argv[1:])
