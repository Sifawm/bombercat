"""Renders the picture of each Map that Configure Match shows: the Map as the Godot project
exports it (shared/src/maps/<map>.json, its `look`), built from the real props, seen
isometrically on a transparent background. Writes game/assets/maps/<map>.png. Run from the
repository root, for every Map or only the ones named:

    blender -b art/cats.blend -P art/render_map.py [-- living_room rooftops]

then re-import (godot --headless --path game --import).
"""
import bpy, json, math, os, sys
from mathutils import Euler, Vector

MAPS = bpy.path.abspath("//../shared/src/maps")
OUT = bpy.path.abspath("//../game/assets/maps")
WIDTH = 1100
MARGIN = 1.03
WALL_HEIGHT = 0.7


def render(name):
    look = json.load(open(os.path.join(MAPS, name + ".json")))["look"]
    old = bpy.data.scenes.get("MapRender")
    if old:
        for o in list(old.collection.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    sc = bpy.data.scenes.new("MapRender")
    sc.render.engine = bpy.data.scenes["Scene"].render.engine
    sc.render.film_transparent = True
    try:
        sc.view_settings.view_transform = "Standard"  # punchy game colours
    except TypeError:
        pass

    def put(model, x, y, turn=0):
        o = bpy.data.objects.new("M_" + model, bpy.data.objects[model].data)
        o.location, o.rotation_euler.z = (x, -y, 0), math.radians(turn)  # a Tile's y grows southwards, Blender's -Y
        sc.collection.objects.link(o)

    cells = look["cells"]
    width = max(c["x"] for c in cells) + 1
    height = max(c["y"] for c in cells) + 1
    for y in range(height):
        for x in range(width):
            put(look["floor"][(x + y) % len(look["floor"])], x, y)
    for c in cells + look["decor"]:
        put(c["model"], c["x"], c["y"], c["turn"])

    cam = bpy.data.objects.new("M_Camera", bpy.data.cameras.new("M_Camera"))
    cam.data.type = "ORTHO"
    turn = Euler((math.radians(54.736), 0, math.radians(45))).to_matrix()
    centre = Vector(((width - 1) / 2, -(height - 1) / 2, 0))
    # Frame the outline of the Map, at the foot and at the top of its Walls, with the picture's shape fitted to it.
    seen = [turn.transposed() @ (Vector((x, -y, z)) - centre)
            for x in (-0.5, width - 0.5) for y in (-0.5, height - 0.5) for z in (0, WALL_HEIGHT)]
    left, right = min(p.x for p in seen), max(p.x for p in seen)
    bottom, top = min(p.y for p in seen), max(p.y for p in seen)
    cam.data.ortho_scale = (right - left) * MARGIN
    cam.rotation_euler = turn.to_euler()
    cam.location = centre + turn @ Vector(((left + right) / 2, (bottom + top) / 2, 30))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x = WIDTH
    sc.render.resolution_y = round(WIDTH * (top - bottom) / (right - left))

    sun = bpy.data.objects.new("M_Sun", bpy.data.lights.new("M_Sun", "SUN"))
    sun.data.energy, sun.data.angle = 4.5, math.radians(8)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-15))
    sc.collection.objects.link(sun)
    w = bpy.data.worlds.get("M_World") or bpy.data.worlds.new("M_World")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.30, 0.50, 0.85, 1)
    bg.inputs["Strength"].default_value = 0.55
    sc.world = w

    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True, scene="MapRender")
    print("rendered", sc.render.filepath)


names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for name in names or sorted(f[:-5] for f in os.listdir(MAPS) if f.endswith(".json")):
    render(name)
