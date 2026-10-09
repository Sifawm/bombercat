"""Game-style render: isometric ortho camera over a small arena built from the real
props (build_props.py) and cats. Builds its own scene "Game" out of linked copies and
writes renders/game.png. Run inside Blender with cats.blend open:

    exec(open(bpy.path.abspath("//render_game.py")).read())
"""
import bpy, math
from mathutils import Vector

OUT = bpy.path.abspath("//../renders/game.png")
CAT_SCALE = 0.72  # cats are ~1.2 m tall; this fits them to the 1 m grid

old = bpy.data.scenes.get("Game")
if old:
    for o in list(old.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
sc = bpy.data.scenes.new("Game")
sc.render.engine = bpy.data.scenes["Scene"].render.engine
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
try:
    sc.view_settings.view_transform = "Standard"  # punchy game colours
except TypeError:
    pass


def put(src, loc, rot_z=0.0, scale=1.0):
    o = bpy.data.objects.new("G_" + src, bpy.data.objects[src].data)
    o.location, o.rotation_euler.z, o.scale = loc, math.radians(rot_z), (scale,) * 3
    sc.collection.objects.link(o)


# ---- arena: W x H cells, brick border, stone pillars on even/even cells
W, H = 7, 5
pos = lambda i, j: Vector((i - (W - 1) / 2, j - (H - 1) / 2, 0))
cats = {(1, 1): ("turing", 45), (5, 1): ("berni", 20), (1, 3): ("hami", 70), (5, 3): ("ada", 45), (3, 2): ("aquiles", 45)}
crates = [(3, 1), (3, 3), (2, 1)]
bombs = [(4, 3), (2, 3)]
for i in range(W):
    for j in range(H):
        put("floor_a" if (i + j) % 2 else "floor_b", pos(i, j))
        if i in (0, W - 1) or j in (0, H - 1):
            put("wall_brick", pos(i, j), 90 * ((i + j) % 2))
        elif i % 2 == 0 and j % 2 == 0:
            put("wall_pillar", pos(i, j))
for c in crates:
    put("crate", pos(*c))
for c in bombs:
    put("bomb", pos(*c), 45, 0.8)
for cell, (name, rz) in cats.items():
    put(name, pos(*cell), rz, CAT_SCALE)

# ---- isometric camera, sun, flat ambient
cam = bpy.data.objects.new("G_Camera", bpy.data.cameras.new("G_Camera"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 10.2
cam.rotation_euler = (math.radians(54.736), 0, math.radians(45))
cam.location = Vector((0, 0, 0.3)) + Vector((1, -1, 1)) * 15
sc.collection.objects.link(cam)
sc.camera = cam

sun = bpy.data.objects.new("G_Sun", bpy.data.lights.new("G_Sun", "SUN"))
sun.data.energy, sun.data.angle = 4.5, math.radians(8)
sun.rotation_euler = (math.radians(50), 0, math.radians(-15))
sc.collection.objects.link(sun)

w = bpy.data.worlds.get("G_World") or bpy.data.worlds.new("G_World")
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.30, 0.50, 0.85, 1)
bg.inputs["Strength"].default_value = 0.55
sc.world = w

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True, scene="Game")
print("rendered", OUT)
