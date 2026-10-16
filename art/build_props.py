"""Builds the props in collection "Props": bomb, floor_a, floor_b, wall_pillar, crate,
wall_brick, wall_brick_low, spawn_marker and the Powerups (yarn_ball, tuna_can, catnip,
paw_swipe, nine_lives, cucumber). Same recipe as the cats: one mesh each, vertex colours in "Col", shared materials
(Cat_Fur matte, Cat_Gloss shiny, Prop_Glow emissive). One grid cell = 1 m; blocks sit on z=0,
floor tiles have their top at z=0. Run inside Blender with cats.blend open:

    exec(open(bpy.path.abspath("//build_props.py")).read())
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion
from mathutils.geometry import interpolate_bezier

MATTE, GLOSS, GLOW = 0, 1, 2
V = lambda *c: Vector(c)
T = Matrix.Translation
UP, FWD = V(0, 0, 1), V(0, -1, 0)


def vc_mat(name, rough, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    a = next((n for n in nt.nodes if n.type == "VERTEX_COLOR"), None) or nt.nodes.new("ShaderNodeVertexColor")
    a.layer_name = "Col"
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if emit:
        nt.links.new(a.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit
    return m


class Prop:
    """Accumulates parts into one mesh. Each part is made in a scratch bmesh so bevels and
    other ops can't touch earlier parts, then painted and appended."""

    def __init__(self):
        self.bm = bmesh.new()

    def part(self, make, colour, mat=MATTE, smooth=False):
        tmp = bmesh.new()
        make(tmp)
        layer = tmp.verts.layers.float_color.new("Col")
        fn = colour if callable(colour) else (lambda p: colour)
        for v in tmp.verts:
            v[layer] = (*fn(v.co), 1)
        for f in tmp.faces:
            f.material_index, f.smooth = mat, smooth
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        me = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, size, centre, colour, bevel=0.03, mat=MATTE):
        def make(bm):
            bmesh.ops.create_cube(bm, size=1, matrix=T(centre) @ Matrix.Diagonal((*size, 1)))
            if bevel:
                bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES", profile=0.5)
        self.part(make, colour, mat)

    def ball(self, centre, scale, colour, mat=MATTE, rot=None, seg=24):
        m = T(centre) @ (rot.to_matrix().to_4x4() if rot else Matrix()) @ Matrix.Diagonal((*scale, 1))
        self.part(lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1, matrix=m), colour, mat, True)

    def cone(self, centre, scale, colour, mat=MATTE, rot=None, r2=0.2, seg=16):
        m = T(centre) @ (rot.to_matrix().to_4x4() if rot else Matrix()) @ Matrix.Diagonal((*scale, 1))
        self.part(lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=1, radius2=r2, depth=2, matrix=m), colour, mat, True)

    def disc(self, centre, normal, up, rx, ry, colour, thick=0.012):
        """Flat ellipse lying on a surface: rx along (up x normal), ry along up."""
        right = up.cross(normal)
        m = T(centre) @ Matrix((right, up, normal)).transposed().to_4x4() @ Matrix.Diagonal((rx, ry, thick, 1))
        self.part(lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=1, radius2=1, depth=2, matrix=m), colour)

    def paw(self, centre, normal, up, size, colour):
        right = up.cross(normal)
        self.disc(centre - up * 0.16 * size, normal, up, 0.27 * size, 0.21 * size, colour)
        for dx, dy in ((-0.36, 0.16), (-0.13, 0.36), (0.13, 0.36), (0.36, 0.16)):
            self.disc(centre + (right * dx + up * dy) * size, normal, up, 0.11 * size, 0.11 * size, colour)

    def tube(self, pts, radius, colour, n=10):
        def make(bm):
            rings = []
            for i, p in enumerate(pts):
                t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
                n1 = (V(1, 0, 0) - V(1, 0, 0).dot(t) * t).normalized()
                n2 = t.cross(n1)
                rings.append([bm.verts.new(p + radius * (math.cos(k * math.tau / n) * n1 + math.sin(k * math.tau / n) * n2)) for k in range(n)])
            for A, B in zip(rings, rings[1:]):
                for k in range(n):
                    bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
        self.part(make, colour, smooth=True)

    def ring(self, centre, radius, thickness, colour, mat=MATTE, rot=None, seg=24, n=8):
        """Torus around the Z axis (before `rot`)."""
        m = T(centre) @ (rot.to_matrix().to_4x4() if rot else Matrix())

        def make(bm):
            rings = [[bm.verts.new(m @ V((radius + thickness * math.cos(k * math.tau / n)) * math.cos(i * math.tau / seg),
                                         (radius + thickness * math.cos(k * math.tau / n)) * math.sin(i * math.tau / seg),
                                         thickness * math.sin(k * math.tau / n))) for k in range(n)] for i in range(seg)]
            for i in range(seg):
                A, B = rings[i], rings[(i + 1) % seg]
                for k in range(n):
                    bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
        self.part(make, colour, mat, True)

    def finish(self, name, x, collection="Props"):
        col = bpy.data.collections.get(collection) or bpy.data.collections.new(collection)
        if col.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(col)
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in (vc_mat("Cat_Fur", 0.75), vc_mat("Cat_Gloss", 0.12), vc_mat("Prop_Glow", 0.5, emit=4.0)):
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        ob.location = (x, -2.5, 0)
        col.objects.link(ob)
        return ob


# ---------------------------------------------------------------- bomb: a round black cat
def bomb():
    p = Prop()
    C, R = V(0, 0, 0.34), 0.34
    BLK, PINK, YEL = V(0.025, 0.025, 0.04), V(0.9, 0.42, 0.48), V(1.0, 0.75, 0.05)
    p.ball(C, (R, R, R), BLK, GLOSS, seg=32)
    for s in (-1, 1):
        tilt = Quaternion((0, 1, 0), s * 0.45)
        p.cone(V(s * 0.19, 0, 0.64), (0.11, 0.075, 0.13), BLK, GLOSS, tilt)
        p.cone(V(s * 0.185, -0.035, 0.63), (0.065, 0.045, 0.085), PINK, MATTE, tilt, r2=0.15)
        # glowing slanted eyes with slit pupils, laid on the sphere
        nrm = V(s * 0.40, -0.86, 0.22).normalized()
        q = (-nrm).to_track_quat("Y", "Z") @ Quaternion((0, 1, 0), s * 0.35)
        p.ball(C + nrm * (R - 0.004), (0.085, 0.016, 0.055), YEL, GLOW, q, 16)
        p.ball(C + nrm * (R + 0.006), (0.016, 0.010, 0.046), V(0.004, 0.004, 0.004), GLOSS, q, 10)
    p.ball(C + V(0, -0.985, 0.02) * R, (0.028, 0.016, 0.02), PINK, GLOSS, seg=10)
    # metal cap, fuse and spark
    p.part(lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.085, radius2=0.075, depth=0.08, matrix=T((0, 0, 0.70))),
           V(0.42, 0.44, 0.48), GLOSS, True)
    fuse = interpolate_bezier(V(0, 0, 0.73), V(0, 0, 0.86), V(0.04, 0.03, 0.92), V(0.13, 0.05, 0.93), 8)
    p.tube(fuse, 0.02, V(0.78, 0.66, 0.45))
    tip = fuse[-1]
    p.ball(tip, (0.055,) * 3, V(1.0, 0.85, 0.3), GLOW, seg=10)
    for d in (V(1, 0, 0), V(0.3, 0, 1), V(0.3, 0.9, -0.3), V(0.3, -0.9, -0.3), V(-0.6, 0.5, 0.6), V(-0.6, -0.5, 0.6)):
        d.normalize()
        p.cone(tip + d * 0.09, (0.022, 0.022, 0.06), V(1.0, 0.4, 0.03), GLOW, UP.rotation_difference(d), r2=0.0, seg=6)
    return p


# ---------------------------------------------------------------- floor: grass slab on soil
def floor(grass):
    p = Prop()
    soil = V(0.33, 0.21, 0.11)
    p.box((1, 1, 0.12), (0, 0, -0.06), lambda c: grass if c.z > -0.04 else soil, bevel=0.015)
    return p


# ---------------------------------------------------------------- indestructible: stone with a paw on top
def wall_pillar():
    p = Prop()
    p.box((0.98, 0.98, 0.48), (0, 0, 0.24), V(0.30, 0.33, 0.43), bevel=0.05)
    p.box((0.86, 0.86, 0.12), (0, 0, 0.52), V(0.50, 0.54, 0.65), bevel=0.035)
    p.paw(V(0, 0, 0.58), UP, V(0, 1, 0), 0.55, V(0.24, 0.26, 0.36))
    return p


# ---------------------------------------------------------------- destructible: taped cardboard box
def crate():
    p = Prop()
    card, tape, ink = V(0.62, 0.43, 0.24), V(0.86, 0.76, 0.55), V(0.36, 0.23, 0.12)
    p.box((0.84, 0.84, 0.60), (0, 0, 0.30), card, bevel=0.025)
    p.box((0.15, 0.86, 0.02), (0, 0, 0.605), tape, bevel=0)
    for s in (-1, 1):
        p.box((0.15, 0.02, 0.20), (0, s * 0.425, 0.505), tape, bevel=0)
        p.paw(V(0, s * 0.42, 0.21), V(0, s, 0), UP, 0.32, ink)
        p.paw(V(s * 0.42, 0, 0.30), V(s, 0, 0), UP, 0.42, ink)
    return p


# ---------------------------------------------------------------- border wall: courses of brick
def wall_brick(courses=2):
    """Two courses for the normal Wall; one for the low variant that does not hide the Tiles behind it."""
    p = Prop()
    p.box((0.94, 0.94, 0.28 * courses), (0, 0, 0.14 * courses), V(0.72, 0.68, 0.60), bevel=0)  # mortar core
    a, b = V(0.55, 0.21, 0.13), V(0.64, 0.28, 0.16)
    rows = [((-0.25125, 0.4775, a), (0.25125, 0.4775, b)),
            ((-0.37625, 0.2275, b), (0, 0.5, a), (0.37625, 0.2275, b))]
    for course, bricks in enumerate(rows[:courses]):
        for x, w, c in bricks:
            p.box((w, 0.98, 0.285), (x, 0, 0.1425 + 0.315 * course), c, bevel=0.02)
    return p


# ---------------------------------------------------------------- spawn point marker: gold plate with a paw (Map Studio only)
def spawn_marker():
    p = Prop()
    p.disc(V(0, 0, 0.012), UP, V(0, 1, 0), 0.42, 0.42, V(1.0, 0.72, 0.08))
    p.paw(V(0, 0, 0.03), UP, V(0, 1, 0), 0.5, V(0.45, 0.2, 0.02))
    return p


# ---------------------------------------------------------------- Powerups: about half a Tile wide,
# resting on z=0, each with its own silhouette and dominant colour
def yarn_ball():
    p = Prop()
    C, R = V(0, 0, 0.27), 0.25
    pink, light = V(0.85, 0.08, 0.35), V(1.0, 0.35, 0.55)
    p.ball(C, (R, R, R), pink, seg=24)
    for axis, angle in ((V(1, 0, 0), 0.5), (V(1, 0, 0), 1.5), (V(0, 1, 0), 0.9), (V(0, 1, 0), 2.1), (V(1, 1, 0).normalized(), 1.2)):
        p.ring(C, R + 0.004, 0.022, light, rot=Quaternion(axis, angle))
    strand = interpolate_bezier(C + V(0.2, -0.1, -0.12), V(0.36, -0.2, 0.0), V(0.30, -0.36, 0.05), V(0.14, -0.38, 0.03), 10)
    p.tube(strand, 0.022, light)
    return p


def tuna_can():
    p = Prop()
    steel, label, fish = V(0.75, 0.78, 0.82), V(0.05, 0.25, 0.85), V(1.0, 0.75, 0.2)
    p.cone(V(0, 0, 0.14), (0.27, 0.27, 0.14), steel, GLOSS, r2=1.0, seg=24)
    p.cone(V(0, 0, 0.14), (0.278, 0.278, 0.09), label, MATTE, r2=1.0, seg=24)
    p.ring(V(0, 0, 0.28), 0.25, 0.022, steel, GLOSS)
    p.disc(V(-0.03, 0, 0.285), UP, V(0, 1, 0), 0.13, 0.075, fish)
    p.cone(V(0.14, 0, 0.285), (0.07, 0.075, 0.012), fish, rot=Quaternion((0, 1, 0), -math.pi / 2), r2=0.0, seg=3)
    return p


def catnip():
    p = Prop()
    pot, soil, leaf, bloom = V(0.72, 0.30, 0.14), V(0.16, 0.09, 0.05), V(0.20, 0.80, 0.18), V(0.65, 0.35, 0.90)
    p.cone(V(0, 0, 0.11), (0.14, 0.14, 0.11), pot, r2=1.35, seg=16)
    p.ring(V(0, 0, 0.22), 0.19, 0.025, pot)
    p.disc(V(0, 0, 0.215), UP, V(0, 1, 0), 0.18, 0.18, soil)
    for i in range(6):
        a = i * math.tau / 6
        lean = Quaternion((0, 0, 1), a) @ Quaternion((0, 1, 0), 0.6)
        p.ball(V(0.13 * math.cos(a), 0.13 * math.sin(a), 0.36 + 0.05 * (i % 2)), (0.05, 0.10, 0.14), leaf, rot=lean, seg=12)
    p.ball(V(0, 0, 0.44), (0.07, 0.07, 0.15), leaf, seg=12)
    p.ball(V(0, 0, 0.60), (0.055,) * 3, bloom, seg=10)
    return p


def paw_swipe():
    p = Prop()
    fur, pad, claw = V(1.0, 0.45, 0.08), V(0.95, 0.45, 0.55), V(0.95, 0.95, 0.9)
    p.ball(V(0, 0.02, 0.18), (0.15, 0.13, 0.2), fur, seg=16)                       # forearm
    p.ball(V(0, 0, 0.42), (0.23, 0.15, 0.2), fur, seg=20)                          # paw
    for dx, dz in ((-0.17, 0.52), (-0.06, 0.60), (0.06, 0.60), (0.17, 0.52)):
        p.ball(V(dx, -0.01, dz), (0.075, 0.08, 0.085), fur, seg=12)                # toes
        p.cone(V(dx, -0.07, dz + 0.07), (0.022, 0.022, 0.05), claw, GLOSS, Quaternion((1, 0, 0), 0.9), r2=0.0, seg=8)
        p.disc(V(dx, -0.085, dz - 0.01), FWD, UP, 0.04, 0.045, pad)
    p.disc(V(0, -0.145, 0.40), FWD, UP, 0.11, 0.085, pad)
    return p


def nine_lives():
    p = Prop()
    white, gold, pink = V(0.95, 0.95, 0.98), V(1.0, 0.72, 0.1), V(0.9, 0.42, 0.48)
    C = V(0, 0, 0.26)
    p.ball(C, (0.26, 0.22, 0.22), white, seg=24)
    for s in (-1, 1):
        tilt = Quaternion((0, 1, 0), s * 0.45)
        p.cone(V(s * 0.16, 0, 0.47), (0.09, 0.06, 0.11), white, MATTE, tilt)
        p.cone(V(s * 0.155, -0.03, 0.46), (0.05, 0.035, 0.07), pink, MATTE, tilt, r2=0.15)
        p.ball(C + V(s * 0.10, -0.2, 0.03), (0.03, 0.015, 0.045), V(0.02, 0.02, 0.03), GLOSS, seg=10)
    p.ball(C + V(0, -0.215, -0.04), (0.022, 0.014, 0.016), pink, GLOSS, seg=8)
    p.ring(V(0, 0, 0.68), 0.17, 0.028, gold, GLOW, rot=Quaternion((1, 0, 0), 0.25))
    return p


def cucumber():
    p = Prop()
    dark, light = V(0.06, 0.32, 0.08), V(0.30, 0.62, 0.20)
    lie = Quaternion((0, 1, 0), 1.2) @ Quaternion((0, 0, 1), 0.5)
    C = V(0, 0, 0.2)
    p.ball(C, (0.13, 0.13, 0.36), dark, rot=lie, seg=20)
    axis = lie @ V(0, 0, 1)
    side, other = lie @ V(1, 0, 0), lie @ V(0, 1, 0)
    for i in range(12):                                                             # warts
        a, t = i * 2.4, -0.26 + 0.52 * i / 11
        p.ball(C + axis * t + (side * math.cos(a) + other * math.sin(a)) * 0.115, (0.022,) * 3, light, seg=6)
    p.ball(C + axis * 0.36, (0.04, 0.04, 0.03), light, rot=lie, seg=8)             # stalk end
    return p


# ---------------------------------------------------------------- living_room: parquet, furniture as Walls.
# A piece's front faces -Y, which the game shows facing the camera; Map Studio rotates it.
def parquet(wood, alt):
    p = Prop()
    p.box((1, 1, 0.1), (0, 0, -0.07), V(0.33, 0.21, 0.11), bevel=0)
    for i in range(4):
        p.box((0.995, 0.245, 0.02), (0, -0.375 + i * 0.25, -0.01), wood if i % 2 == 0 else alt, bevel=0.004)
    return p


def wall_room(h=0.62):
    """Wallpapered wall with a skirting board and a wooden cap; the low variant does not hide the Tiles behind it."""
    p = Prop()
    paper, stripe, board, cap = V(0.36, 0.56, 0.55), V(0.44, 0.65, 0.62), V(0.93, 0.9, 0.84), V(0.27, 0.45, 0.45)
    p.box((0.96, 0.96, h - 0.07), (0, 0, (h - 0.07) / 2), paper, bevel=0)
    for d in (-0.3, 0, 0.3):
        p.box((0.08, 0.97, h - 0.2), (d, 0, (h - 0.2) / 2 + 0.1), stripe, bevel=0)
        p.box((0.97, 0.08, h - 0.2), (0, d, (h - 0.2) / 2 + 0.1), stripe, bevel=0)
    p.box((0.98, 0.98, 0.12), (0, 0, 0.06), board, bevel=0.01)
    p.box((1.0, 1.0, 0.07), (0, 0, h - 0.035), cap, bevel=0.02)
    return p


def sofa(arm):
    """One seat of a sofa: arm -1 ends it on the left (as seen from the front), 1 on the right, 0 none."""
    p = Prop()
    fabric, cushion, foot = V(0.76, 0.26, 0.25), V(0.88, 0.40, 0.36), V(0.35, 0.2, 0.1)
    p.box((1.0, 0.86, 0.22), (0, 0, 0.15), fabric, bevel=0.02)
    p.box((1.0, 0.24, 0.38), (0, 0.31, 0.45), fabric, bevel=0.03)
    left, right = (-0.5 + (0.2 if arm < 0 else 0.02)), (0.5 - (0.2 if arm > 0 else 0.02))
    p.box((right - left, 0.6, 0.11), ((left + right) / 2, -0.1, 0.31), cushion, bevel=0.03)
    p.box((right - left, 0.13, 0.26), ((left + right) / 2, 0.14, 0.46), cushion, bevel=0.04)
    if arm:
        p.box((0.2, 0.86, 0.24), (arm * 0.4, 0, 0.38), fabric, bevel=0.04)
        for y in (-0.36, 0.36):
            p.box((0.08, 0.08, 0.05), (arm * 0.4, y, 0.025), foot, bevel=0.01)
    return p


def bookshelf():
    import random
    rnd = random.Random(7)
    p = Prop()
    wood, back = V(0.55, 0.35, 0.2), V(0.4, 0.25, 0.14)
    books = [V(0.85, 0.3, 0.25), V(0.25, 0.45, 0.75), V(0.95, 0.75, 0.25), V(0.35, 0.65, 0.4), V(0.6, 0.4, 0.75)]
    p.box((0.98, 0.06, 0.72), (0, 0.42, 0.36), back, bevel=0)
    for s in (-1, 1):
        p.box((0.06, 0.86, 0.72), (s * 0.46, 0.03, 0.36), wood, bevel=0.01)
    for z in (0.03, 0.37, 0.71):
        p.box((0.98, 0.86, 0.05), (0, 0.03, z), wood, bevel=0.01)
    for shelf in (0.06, 0.4):
        x = -0.41
        while x < 0.36:
            w, h = rnd.uniform(0.06, 0.1), rnd.uniform(0.2, 0.28)
            p.box((w - 0.01, 0.5, h), (x + w / 2, 0.12, shelf + h / 2), rnd.choice(books), bevel=0.005)
            x += w
    # on top, seen from the camera: a lying stack of books and a potted plant
    for i, c in enumerate(books[:3]):
        p.box((0.34 - i * 0.04, 0.26, 0.05), (-0.2, 0.05, 0.76 + i * 0.05), c, bevel=0.01)
    p.cone(V(0.22, 0.02, 0.81), (0.09, 0.09, 0.08), V(0.72, 0.30, 0.14), r2=1.3, seg=12)
    for i in range(5):
        a = i * math.tau / 5
        p.ball(V(0.22 + 0.07 * math.cos(a), 0.02 + 0.07 * math.sin(a), 0.95), (0.06, 0.06, 0.1), V(0.25, 0.65, 0.25), seg=10)
    return p


def cat_tree():
    p = Prop()
    carpet, sisal, top, pink = V(0.85, 0.75, 0.6), V(0.78, 0.63, 0.4), V(0.55, 0.4, 0.72), V(0.85, 0.08, 0.35)
    p.box((0.86, 0.86, 0.08), (0, 0, 0.04), carpet, bevel=0.02)
    p.cone(V(0, 0, 0.38), (0.09, 0.09, 0.3), sisal, r2=1.0, seg=12)
    for z in (0.16, 0.26, 0.36, 0.46, 0.56):
        p.ring(V(0, 0, z), 0.09, 0.012, V(0.66, 0.52, 0.32))
    p.cone(V(0, 0, 0.7), (0.36, 0.36, 0.04), top, r2=1.0, seg=20)
    p.tube([V(0.26, -0.12, 0.66), V(0.27, -0.13, 0.55), V(0.27, -0.14, 0.45)], 0.01, pink)
    p.ball(V(0.27, -0.14, 0.4), (0.06,) * 3, pink)
    return p


def table_corner():
    """A quarter of a 2 x 2 table under a gingham cloth, its outer corner at -X +Y; four turned ones make the table."""
    p = Prop()
    cloth, check, cup = V(0.95, 0.93, 0.86), V(0.86, 0.32, 0.32), V(0.4, 0.6, 0.85)
    p.box((0.96, 0.96, 0.5), (0.02, -0.02, 0.25), cloth, bevel=0.02)
    for d in (-0.25, 0.25):
        p.box((0.12, 0.965, 0.012), (d, -0.02, 0.5), check, bevel=0)
        p.box((0.965, 0.12, 0.012), (0.02, d, 0.5), check, bevel=0)
    p.box((0.012, 0.965, 0.08), (-0.462, -0.02, 0.06), check, bevel=0)
    p.box((0.965, 0.012, 0.08), (0.02, 0.462, 0.06), check, bevel=0)
    p.disc(V(0.3, -0.3, 0.512), UP, V(0, 1, 0), 0.11, 0.11, V(0.98, 0.98, 0.98))
    p.cone(V(0.3, -0.3, 0.57), (0.05, 0.05, 0.05), cup, GLOSS, r2=1.2, seg=12)
    return p


def rug():
    """5 x 5 Tiles of rug, laid over the Floor as decoration; it is not a Tile."""
    p = Prop()
    red, gold, blue = V(0.6, 0.16, 0.2), V(0.92, 0.72, 0.3), V(0.2, 0.3, 0.6)
    p.box((4.8, 4.8, 0.012), (0, 0, 0.006), red, bevel=0)
    p.box((4.3, 4.3, 0.014), (0, 0, 0.007), gold, bevel=0)
    p.box((4.0, 4.0, 0.016), (0, 0, 0.008), red, bevel=0)
    p.disc(V(0, 0, 0.018), UP, V(0, 1, 0), 1.1, 1.1, gold)
    p.disc(V(0, 0, 0.02), UP, V(0, 1, 0), 0.85, 0.85, blue)
    for x in (-1.6, 1.6):
        for y in (-1.6, 1.6):
            p.disc(V(x, y, 0.018), UP, V(0, 1, 0), 0.25, 0.25, blue)
    for i in range(24):
        for y in (-2.45, 2.45):
            p.box((0.03, 0.1, 0.006), (-2.3 + i * 0.2, y, 0.003), V(0.95, 0.9, 0.8), bevel=0)
    return p


PROPS = [("bomb", bomb()), ("floor_a", floor(V(0.36, 0.62, 0.22))), ("floor_b", floor(V(0.27, 0.52, 0.17))),
         ("wall_pillar", wall_pillar()), ("crate", crate()), ("wall_brick", wall_brick()),
         ("wall_brick_low", wall_brick(1)), ("spawn_marker", spawn_marker()),
         ("yarn_ball", yarn_ball()), ("tuna_can", tuna_can()), ("catnip", catnip()),
         ("paw_swipe", paw_swipe()), ("nine_lives", nine_lives()), ("cucumber", cucumber()),
         ("floor_parquet_a", parquet(V(0.50, 0.31, 0.19), V(0.46, 0.28, 0.17))),
         ("floor_parquet_b", parquet(V(0.42, 0.26, 0.16), V(0.39, 0.24, 0.15))),
         ("wall_room", wall_room()), ("wall_room_low", wall_room(0.32)),
         ("sofa_left", sofa(-1)), ("sofa_middle", sofa(0)), ("sofa_right", sofa(1)),
         ("bookshelf", bookshelf()), ("cat_tree", cat_tree()), ("table_corner", table_corner()), ("rug", rug())]
for i, (name, prop) in enumerate(PROPS):
    prop.finish(name, i * 1.5)
