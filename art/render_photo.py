"""Photoreal render: the five cats as furry plush toys in a studio, Cycles.
Builds its own scene "Photo" (cats are mesh COPIES with particle fur, originals
untouched) and writes renders/photo.png. Run inside Blender with cats.blend open:

    exec(open(bpy.path.abspath("//render_photo.py")).read())

Set PREVIEW = True before exec for a fast half-res test.
"""
import bpy, bmesh, math
from mathutils import Vector

PREVIEW = globals().get("PREVIEW", False)
OUT = bpy.path.abspath("//../renders/photo.png")
# name, x, y, rotation towards the camera (degrees)
CATS = [("turing", -1.84, -0.2, 14), ("berni", -0.92, -0.05, 7), ("aquiles", 0, 0.05, 0),
        ("hami", 0.92, -0.05, -7), ("ada", 1.84, -0.2, -14)]
COLLARS = [Vector(c) for c in ((0.8, 0.04, 0.04), (0.03, 0.2, 0.85), (0.05, 0.55, 0.12), (0.45, 0.08, 0.7), (0.95, 0.45, 0.02))]

old = bpy.data.scenes.get("Photo")
if old:
    for o in list(old.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
sc = bpy.data.scenes.new("Photo")
try:
    sc.render.engine = "CYCLES"
except TypeError as e:
    print("Cycles unavailable:", e)
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
sc.render.resolution_percentage = 50 if PREVIEW else 100
sc.cycles.samples = 24 if PREVIEW else 64
sc.cycles.use_denoising = True


def principled(name, rgb, rough):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def hair_mat():
    m = bpy.data.materials.get("Cat_FurHair")
    if m:
        return m
    m = bpy.data.materials.new("Cat_FurHair")
    m.use_nodes = True
    nt = m.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    h = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
    try:
        h.parametrization = "COLOR"
    except TypeError:
        pass
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "Col"
    nt.links.new(a.outputs["Color"], h.inputs["Color"])
    h.inputs["Roughness"].default_value = 0.55
    h.inputs["Radial Roughness"].default_value = 0.7
    nt.links.new(h.outputs[0], out.inputs["Surface"])
    return m


def gloss_mat():
    """Cat_Gloss with a wet-glass finish, so eyes, nose and bell catch the studio lights."""
    m = bpy.data.materials.get("F_Gloss")
    if not m:
        m = bpy.data.materials["Cat_Gloss"].copy()
        m.name = "F_Gloss"
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.03
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = 1.0
        b.inputs["Coat Roughness"].default_value = 0.02
    return m


EYE_MARGIN = 0.015  # bare skin left around the eye outline; 0 lets hair roots poke through the rim


def under_eye(v):
    """True if v lies under an eye: inside its outline ellipse, measured on the head surface (see build_cat.py)."""
    HC, HS = Vector((0, 0, 0.76)), Vector((0.40, 0.35, 0.33))
    for s in (-1, 1):
        ex, z = s * 0.158, 0.785
        p = Vector((ex, HC.y - HS.y * (1 - (ex / HS.x) ** 2 - ((z - HC.z) / HS.z) ** 2) ** 0.5, z))
        n = Vector((p.x / HS.x**2, (p.y - HC.y) / HS.y**2, (p.z - HC.z) / HS.z**2)).normalized()
        up = (Vector((0, 0, 1)) - n.z * n).normalized()
        d = v - p
        if abs(d.dot(n)) < 0.1 and (d.dot(n.cross(up)) / (0.092 + EYE_MARGIN)) ** 2 + (d.dot(up) / (0.104 + EYE_MARGIN)) ** 2 < 1:
            return True
    return False


for name, x, y, rz in CATS:
    me = bpy.data.objects[name].data.copy()
    me.name = "F_" + name
    # per-corner byte colours: the format particle hair reliably inherits from its emitter
    src = me.color_attributes["Col"]
    vals = [tuple(d.color) for d in src.data]
    me.color_attributes.remove(src)
    dst = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for lp in me.loops:
        dst.data[lp.index].color = vals[lp.vertex_index]
    me.materials[1] = gloss_mat()
    me.materials.append(hair_mat())

    ob = bpy.data.objects.new("F_" + name, me)
    ob.location, ob.rotation_euler.z = (x, y, 0), math.radians(rz)
    sc.collection.objects.link(ob)

    # fur everywhere except eyes/nose/bell (gloss material) and the collar
    furry = {v for p in me.polygons if p.material_index == 0 for v in p.vertices}
    furry = [v for v in furry if min((Vector(vals[v][:3]) - c).length for c in COLLARS) > 0.05]
    # no hair under the eyes (fur runs right up to their rim) or on the nose, and a bare band so the collar shows
    co = lambda v: me.vertices[v].co
    furry = [v for v in furry if not under_eye(co(v)) and (co(v) - Vector((0, -0.37, 0.70))).length > 0.05 and not 0.44 < co(v).z < 0.52]
    ob.vertex_groups.new(name="fur").add(furry, 1.0, "REPLACE")

    ps = ob.modifiers.new("Fur", "PARTICLE_SYSTEM").particle_system.settings
    ps.name = "F_Fur_" + name
    ps.type = "HAIR"
    ps.count = 7000
    ps.hair_length = 0.03
    ps.hair_step = 4
    ps.child_type = "INTERPOLATED"
    ps.rendered_child_count = 12 if PREVIEW else 45
    ps.child_percent = 2
    ps.clump_factor = 0.15
    ps.roughness_1, ps.roughness_1_size = 0.02, 0.3
    ps.roughness_endpoint = 0.015
    ps.radius_scale = 0.004
    ps.root_radius, ps.tip_radius = 1.0, 0.15
    ps.material = len(me.materials)
    ob.particle_systems[0].vertex_group_density = "fur"

# ---- studio: floor + backdrop, three area lights
def plane(name, verts, material):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], [(0, 1, 2, 3)])
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    sc.collection.objects.link(o)


set_mat = principled("F_Backdrop", (0.62, 0.50, 0.40), 0.55)
plane("F_Floor", [(-30, -30, 0), (30, -30, 0), (30, 9, 0), (-30, 9, 0)], set_mat)
plane("F_Wall", [(-30, 9, 0), (30, 9, 0), (30, 9, 30), (-30, 9, 30)], set_mat)


def look_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()


def area(name, loc, size, watts, rgb=(1, 1, 1)):
    l = bpy.data.lights.new(name, "AREA")
    l.size, l.energy, l.color = size, watts, rgb
    o = bpy.data.objects.new(name, l)
    o.location = loc
    look_at(o, (0, 0, 0.6))
    sc.collection.objects.link(o)


area("F_Key", (-3.5, -4.0, 4.5), 3.0, 900, (1.0, 0.95, 0.88))
area("F_Fill", (4.5, -3.5, 1.8), 4.0, 220, (0.85, 0.92, 1.0))
area("F_Rim", (1.5, 4.5, 3.5), 2.0, 600)

w = bpy.data.worlds.get("F_World") or bpy.data.worlds.new("F_World")
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.7, 0.75, 0.85, 1)
bg.inputs["Strength"].default_value = 0.25
sc.world = w

cam = bpy.data.objects.new("F_Camera", bpy.data.cameras.new("F_Camera"))
cam.location = (0, -9.8, 1.25)
look_at(cam, (0, 0, 0.6))
cam.data.lens = 70
cam.data.dof.use_dof = True
cam.data.dof.focus_distance = 9.8
cam.data.dof.aperture_fstop = 4.0
sc.collection.objects.link(cam)
sc.camera = cam

sc.render.filepath = OUT.replace(".png", "_preview.png") if PREVIEW else OUT
bpy.ops.render.render(write_still=True, scene="Photo")
print("rendered", sc.render.filepath)
