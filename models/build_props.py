"""Builds the stage props in collection "Escenario": Bomba, Suelo_A, Suelo_B, Bloque_Solido,
Caja, Muro. Same recipe as the cats: one mesh each, vertex colours in "Col", shared materials
(Cat_Fur matte, Cat_Gloss shiny, Prop_Glow emissive). One grid cell = 1 m; blocks sit on z=0,
floor tiles have their top at z=0. Run inside Blender with gatos.blend open:

    exec(open("/home/sifaw/Workspaces/bombercat/models/build_props.py").read())
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

    def finish(self, name, x, collection="Escenario"):
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
def bomba():
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
def suelo(grass):
    p = Prop()
    soil = V(0.33, 0.21, 0.11)
    p.box((1, 1, 0.12), (0, 0, -0.06), lambda c: grass if c.z > -0.04 else soil, bevel=0.015)
    return p


# ---------------------------------------------------------------- indestructible: stone with a paw on top
def bloque_solido():
    p = Prop()
    p.box((0.98, 0.98, 0.48), (0, 0, 0.24), V(0.30, 0.33, 0.43), bevel=0.05)
    p.box((0.86, 0.86, 0.12), (0, 0, 0.52), V(0.50, 0.54, 0.65), bevel=0.035)
    p.paw(V(0, 0, 0.58), UP, V(0, 1, 0), 0.55, V(0.24, 0.26, 0.36))
    return p


# ---------------------------------------------------------------- destructible: taped cardboard box
def caja():
    p = Prop()
    card, tape, ink = V(0.62, 0.43, 0.24), V(0.86, 0.76, 0.55), V(0.36, 0.23, 0.12)
    p.box((0.84, 0.84, 0.60), (0, 0, 0.30), card, bevel=0.025)
    p.box((0.15, 0.86, 0.02), (0, 0, 0.605), tape, bevel=0)
    for s in (-1, 1):
        p.box((0.15, 0.02, 0.20), (0, s * 0.425, 0.505), tape, bevel=0)
        p.paw(V(0, s * 0.42, 0.21), V(0, s, 0), UP, 0.32, ink)
        p.paw(V(s * 0.42, 0, 0.30), V(s, 0, 0), UP, 0.42, ink)
    return p


# ---------------------------------------------------------------- border wall: two courses of brick
def muro():
    p = Prop()
    p.box((0.94, 0.94, 0.56), (0, 0, 0.28), V(0.72, 0.68, 0.60), bevel=0)  # mortar core
    a, b = V(0.55, 0.21, 0.13), V(0.64, 0.28, 0.16)
    for x, w, c in ((-0.25125, 0.4775, a), (0.25125, 0.4775, b)):
        p.box((w, 0.98, 0.285), (x, 0, 0.1425), c, bevel=0.02)
    for x, w, c in ((-0.37625, 0.2275, b), (0, 0.5, a), (0.37625, 0.2275, b)):
        p.box((w, 0.98, 0.285), (x, 0, 0.4575), c, bevel=0.02)
    return p


PROPS = [("Bomba", bomba()), ("Suelo_A", suelo(V(0.36, 0.62, 0.22))), ("Suelo_B", suelo(V(0.27, 0.52, 0.17))),
         ("Bloque_Solido", bloque_solido()), ("Caja", caja()), ("Muro", muro())]
for i, (name, prop) in enumerate(PROPS):
    prop.finish(name, i * 1.5)
