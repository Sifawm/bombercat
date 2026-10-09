"""Animation showcase: the five cats in a row, each looping a different animation, with labels.
Builds its own scene "Anim" (linked copies of the rigs) and renders PNG frames to FRAMES;
encode them afterwards with ffmpeg. Run inside Blender with cats.blend open:

    exec(open(bpy.path.abspath("//render_anim.py")).read())
"""
import bpy, math
from mathutils import Vector

FRAMES = globals().get("FRAMES", "/tmp/anim_frames/f_")
LENGTH = 96  # 4 s at 24 fps; every strip layout below repeats cleanly within it
# cat, animation, strip start frames, repeats per strip
SHOW = [("turing", "idle", [0], 2), ("berni", "walk", [0], 6), ("aquiles", "place_bomb", [0, 24, 48, 72], 1),
        ("hami", "die", [0, 48], 1), ("ada", "win", [0], 4)]

old = bpy.data.scenes.get("Anim")
if old:
    for o in list(old.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
sc = bpy.data.scenes.new("Anim")
sc.render.engine = bpy.data.scenes["Scene"].render.engine
sc.render.resolution_x, sc.render.resolution_y = 1280, 480
sc.render.fps = 24
sc.frame_start, sc.frame_end = 0, LENGTH - 1
try:
    sc.view_settings.view_transform = "Standard"
except TypeError:
    pass


def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


for i, (cat, anim, starts, repeat) in enumerate(SHOW):
    x = (i - 2) * 1.35
    src = bpy.data.objects["Rig_" + cat]
    arm = src.copy()
    arm.name = "A_Rig_" + cat
    arm.location = (x, 0, 0)
    sc.collection.objects.link(arm)
    body = bpy.data.objects[cat].copy()
    body.name = "A_" + cat
    body.parent = arm
    next(m for m in body.modifiers if m.type == "ARMATURE").object = arm
    sc.collection.objects.link(body)

    ad = arm.animation_data
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    act = bpy.data.actions[anim]
    tr = ad.nla_tracks.new()
    for s in starts:
        st = tr.strips.new(anim, s, act)
        if hasattr(st, "action_slot") and getattr(act, "slots", None):
            st.action_slot = act.slots[0]
        st.repeat = repeat

    cu = bpy.data.curves.new("A_Label_" + anim, "FONT")
    cu.body, cu.size, cu.align_x, cu.extrude = anim, 0.17, "CENTER", 0.005
    cu.materials.append(mat("A_Text", (0.12, 0.10, 0.10)))
    label = bpy.data.objects.new("A_Label_" + anim, cu)
    label.location, label.rotation_euler.x = (x, -1.2, 0.01), math.radians(90)
    sc.collection.objects.link(label)

floor = bpy.data.meshes.new("A_Floor")
floor.from_pydata([(-40, -20, 0), (40, -20, 0), (40, 40, 0), (-40, 40, 0)], [], [(0, 1, 2, 3)])
floor.materials.append(mat("A_FloorMat", (0.80, 0.72, 0.60)))
sc.collection.objects.link(bpy.data.objects.new("A_Floor", floor))

cam = bpy.data.objects.new("A_Camera", bpy.data.cameras.new("A_Camera"))
cam.location = (0, -9.5, 2.3)
cam.rotation_euler = (Vector((0, 0, 0.62)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 52
sc.collection.objects.link(cam)
sc.camera = cam

sun = bpy.data.objects.new("A_Sun", bpy.data.lights.new("A_Sun", "SUN"))
sun.data.energy, sun.data.angle = 4.0, math.radians(10)
sun.rotation_euler = (math.radians(55), 0, math.radians(-25))
sc.collection.objects.link(sun)

w = bpy.data.worlds.get("A_World") or bpy.data.worlds.new("A_World")
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.80, 0.72, 0.60, 1)
bg.inputs["Strength"].default_value = 0.6
sc.world = w

sc.render.filepath = FRAMES
bpy.ops.render.render(animation=True, scene="Anim")
print("rendered frames to", FRAMES)
