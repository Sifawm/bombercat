"""Game-style render: isometric ortho camera over a small arena built from the real
props (build_props.py) and cats. Builds its own scene "Juego" out of linked copies and
writes renders/juego.png. Run inside Blender with gatos.blend open:

    exec(open("/home/sifaw/Workspaces/bombercat/models/render_juego.py").read())
"""
import bpy, math
from mathutils import Vector

OUT = "/home/sifaw/Workspaces/bombercat/renders/juego.png"
CAT_SCALE = 0.72  # cats are ~1.2 m tall; this fits them to the 1 m grid

old = bpy.data.scenes.get("Juego")
if old:
    for o in list(old.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
sc = bpy.data.scenes.new("Juego")
sc.render.engine = bpy.data.scenes["Scene"].render.engine
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
try:
    sc.view_settings.view_transform = "Standard"  # punchy game colours
except TypeError:
    pass


def put(src, loc, rot_z=0.0, scale=1.0):
    o = bpy.data.objects.new("J_" + src, bpy.data.objects[src].data)
    o.location, o.rotation_euler.z, o.scale = loc, math.radians(rot_z), (scale,) * 3
    sc.collection.objects.link(o)


# ---- arena: W x H cells, brick border, stone pillars on even/even cells
W, H = 7, 5
pos = lambda i, j: Vector((i - (W - 1) / 2, j - (H - 1) / 2, 0))
cats = {(1, 1): ("Siames", 45), (5, 1): ("Tuxedo", 20), (1, 3): ("Tricolor", 70), (5, 3): ("Callejero", 45), (3, 2): ("Atigrado", 45)}
crates = [(3, 1), (3, 3), (2, 1)]
bombs = [(4, 3), (2, 3)]
for i in range(W):
    for j in range(H):
        put("Suelo_A" if (i + j) % 2 else "Suelo_B", pos(i, j))
        if i in (0, W - 1) or j in (0, H - 1):
            put("Muro", pos(i, j), 90 * ((i + j) % 2))
        elif i % 2 == 0 and j % 2 == 0:
            put("Bloque_Solido", pos(i, j))
for c in crates:
    put("Caja", pos(*c))
for c in bombs:
    put("Bomba", pos(*c), 45, 0.8)
for cell, (name, rz) in cats.items():
    put(name, pos(*cell), rz, CAT_SCALE)

# ---- isometric camera, sun, flat ambient
cam = bpy.data.objects.new("J_Camera", bpy.data.cameras.new("J_Camera"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 10.2
cam.rotation_euler = (math.radians(54.736), 0, math.radians(45))
cam.location = Vector((0, 0, 0.3)) + Vector((1, -1, 1)) * 15
sc.collection.objects.link(cam)
sc.camera = cam

sun = bpy.data.objects.new("J_Sun", bpy.data.lights.new("J_Sun", "SUN"))
sun.data.energy, sun.data.angle = 4.5, math.radians(8)
sun.rotation_euler = (math.radians(50), 0, math.radians(-15))
sc.collection.objects.link(sun)

w = bpy.data.worlds.get("J_World") or bpy.data.worlds.new("J_World")
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.30, 0.50, 0.85, 1)
bg.inputs["Strength"].default_value = 0.55
sc.world = w

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True, scene="Juego")
print("rendered", OUT)
