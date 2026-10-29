"""Builds the chibi cats, each as ONE mesh with its colours baked into a texture (<name>_Skin,
packed in the .blend) and two materials of its own (<name>_Fur, <name>_Gloss). Run inside
Blender, or headless from the repository root and then save:

    exec(open(bpy.path.abspath("//build_cat.py")).read())
    blender -b art/cats.blend -P art/build_cat.py --python-expr "import bpy; bpy.ops.wm.save_mainfile()"

Cat faces -Y, feet on z=0, ~1.2 m tall. A Cat's palette is a dict of colour functions
(world position -> linear RGB) per body part; see CATS at the bottom. Each texel of the texture
is coloured by those functions at the point of the body it covers, so pattern edges are as
sharp as the texture, not as coarse as the mesh.
"""
import bpy, bmesh, math
import numpy as np
from mathutils import Vector, Matrix, Euler
from mathutils.geometry import interpolate_bezier

TEXTURE = 2048
## Texels each island's colour is spread beyond its edge, so mipmaps and filtering never
## sample the empty space between islands.
BLEED = 8

FUR, GLOSS = 0, 1
PINK, BLACK, WHITE = Vector((0.9, 0.42, 0.48)), Vector((0.004,) * 3), Vector((1, 1, 1))
GOLD = Vector((1.0, 0.65, 0.08))
TAIL_TIP = Vector((0, 0.84, 0.62))
_k = [Vector(v) for v in ((0, 0.17, 0.20), (0, 0.40, 0.12), (0, 0.62, 0.25), (0, 0.62, 0.50),
                          (0, 0.62, 0.72), (0, 0.80, 0.82), TAIL_TIP)]
TAIL_PTS = interpolate_bezier(_k[0], _k[1], _k[2], _k[3], 12) + interpolate_bezier(_k[3], _k[4], _k[5], _k[6], 12)[1:]
TAIL_JOINTS = [0, 6, 11, 17, 22]  # ring indices where the 4 tail bones start/end

# deform bones = vertex groups; every part is skinned rigidly to one bone, the tail is blended
GROUPS = ["Body", "Head", "Ear.L", "Ear.R", "Arm.L", "Arm.R", "Foot.L", "Foot.R", "Tail1", "Tail2", "Tail3", "Tail4"]
GI = {g: i for i, g in enumerate(GROUPS)}


def tail_w(i):
    c = [(a + b) / 2 for a, b in zip(TAIL_JOINTS, TAIL_JOINTS[1:])]
    if i <= c[0]:
        return {"Tail1": 1.0}
    if i >= c[-1]:
        return {"Tail4": 1.0}
    j = max(n for n in range(3) if c[n] <= i)
    t = (i - c[j]) / (c[j + 1] - c[j])
    return {"Tail%d" % (j + 1): 1 - t, "Tail%d" % (j + 2): t}


def tex_mat(name, rough, image):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    t.image = image
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    return m


def bake(me, sources, name):
    """The texture of mesh `me`: every texel inside a UV triangle gets the colour function of
    that triangle's part, at the point it covers (`sources`: vertex index -> (point, function))."""
    size = TEXTURE
    rgb = np.zeros((size, size, 3), np.float32)
    filled = np.zeros((size, size), bool)
    uvs = me.uv_layers.active.data
    me.calc_loop_triangles()
    for tri in me.loop_triangles:
        uv = np.array([uvs[l].uv for l in tri.loops]) * size - 0.5
        pts = np.array([sources[v][0] for v in tri.vertices])
        fn = sources[tri.vertices[0]][1]
        lo = np.floor(uv.min(0)).astype(int).clip(0, size - 1)
        hi = np.ceil(uv.max(0)).astype(int).clip(0, size - 1)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        (ax, ay), (bx, by), (cx, cy) = uv
        area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
        if abs(area) < 1e-12:
            continue
        w1 = ((xs - ax) * (cy - ay) - (cx - ax) * (ys - ay)) / area
        w2 = ((bx - ax) * (ys - ay) - (xs - ax) * (by - ay)) / area
        w0 = 1 - w1 - w2
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)  # a hair over, so no texel between triangles is missed
        for x, y, a, b, c in zip(xs[inside], ys[inside], w0[inside], w1[inside], w2[inside]):
            if not filled[y, x]:
                rgb[y, x] = fn(Vector(a * pts[0] + b * pts[1] + c * pts[2]))
                filled[y, x] = True
    for _ in range(BLEED):
        grown = rgb.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(rgb, dy, 0), dx, 1)
            got = np.roll(np.roll(filled, dy, 0), dx, 1) & ~filled
            grown[got] = src[got]
            filled = filled | got
        rgb = grown
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, size, size)  # linear colours, stored as sRGB like any colour texture
    srgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(np.maximum(rgb, 0), 1 / 2.4) - 0.055)
    img.pixels.foreach_set(np.dstack([srgb, np.ones((size, size))]).astype(np.float32).ravel())
    img.pack()
    return img


def sstep(a, b, x):
    t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)


# ---- colour-function helpers
flat = lambda c: (lambda p: c)
zfade = lambda lo, hi, z0, z1: (lambda p: lo.lerp(hi, sstep(z0, z1, p.z)))
by_side = lambda left, right: (lambda p: left if p.x < 0 else right)  # left = cat's -X


def patches(base, *blobs):
    """base colour plus round spots: (centre, radius, colour), later ones on top."""
    blobs = [(Vector(c), r, col) for c, r, col in blobs]

    def fn(p):
        c = base(p) if callable(base) else base
        for centre, r, col in blobs:
            e = max(r * 0.04, 0.006)  # a soft edge, but only a few texels wide
            c = c.lerp(col, sstep(r + e, r - e, (p - centre).length))
        return c
    return fn


def blaze(top, brow=0.075, jaw=0.32):
    """White amount (0..1) of a face blaze: a point at height `top` between the eyes that
    widens down the nose (`brow` = half-width there) and flares `jaw` wide over cheeks and chin."""
    def fn(p):
        w = -0.03 + brow * sstep(top, top - 0.14, p.z) + jaw * min(max((0.71 - p.z) / 0.15, 0), 1)
        return sstep(w + 0.01, w - 0.01, abs(p.x)) * sstep(0.0, -0.08, p.y)
    return fn


CHIN = (0.012, -0.30, 0.59)  # small dark mark under the mouth


def build(name, pal, x=0.0, collection="Cats"):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.verts.layers.float_color.new("Col")  # the game uses the texture; render_photo.py these
    dl = bm.verts.layers.deform.verify()
    cur = ["Body"]  # bone the next parts are skinned to
    sources = {}  # vertex -> (where its part was painted, the part's colour function)

    def paint(verts, fn, mat):
        for v in verts:
            sources[v] = (v.co.copy(), fn)
            v[col] = (*fn(v.co), 1)
            v[dl][GI[cur[0]]] = 1.0
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = mat
            f.smooth = True

    def TRS(loc, scale, rot=(0, 0, 0)):
        q = rot if hasattr(rot, "to_matrix") else Euler(rot)
        return Matrix.Translation(loc) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))

    def ball(loc, scale, fn, mat=FUR, rot=(0, 0, 0), seg=32):
        vs = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1, matrix=TRS(loc, scale, rot), calc_uvs=True)["verts"]
        paint(vs, fn, mat)
        return vs

    def cone(loc, scale, fn, rot=(0, 0, 0), r2=0.2):
        vs = bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=1, radius2=r2, depth=2, matrix=TRS(loc, scale, rot), calc_uvs=True)["verts"]
        paint(vs, fn, FUR)

    def tube(pts, radii, fn, closed=False, n=12, ring_w=None):
        rings, last = [], len(pts) - 1
        for i, (p, r) in enumerate(zip(pts, radii)):
            a = pts[(i - 1) % len(pts) if closed else max(i - 1, 0)]
            b = pts[(i + 1) % len(pts) if closed else min(i + 1, last)]
            t = (b - a).normalized()
            ref = Vector((0, 0, 1)) if closed else Vector((1, 0, 0))
            n1 = (ref - ref.dot(t) * t).normalized()
            n2 = t.cross(n1)
            rings.append([bm.verts.new(p + r * (math.cos(k * math.tau / n) * n1 + math.sin(k * math.tau / n) * n2)) for k in range(n)])
        count = len(rings) if closed else last
        for i in range(count):
            A, B = rings[i], rings[(i + 1) % len(rings)]
            for k in range(n):
                face = bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
                for loop, (u, w) in zip(face.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                    loop[uv].uv = (u / n, w / count)  # unwrapped, so the seam faces span the strip's end
        paint([v for r in rings for v in r], fn, FUR)
        for ring, w in zip(rings, ring_w or ()):
            for v in ring:
                v[dl].clear()
                for b, wt in w.items():
                    v[dl][GI[b]] = wt

    # ---- body (pear shaped); dense enough for crisp patch edges
    HC, HS = Vector((0, 0, 0.76)), Vector((0.40, 0.35, 0.33))
    for v in ball((0, 0, 0.31), (0.24, 0.21, 0.26), pal["body"], seg=64):
        f = 1 - 0.22 * (v.co.z - 0.31) / 0.26
        v.co.x *= f
        v.co.y *= f

    cur[0] = "Head"
    ball(HC, HS, pal["head"], seg=96)
    for s in (-1, 1):
        side = ".L" if s > 0 else ".R"  # cat faces -Y, so its left is +X
        cur[0] = "Ear" + side
        # ears: big so they read from the isometric camera, pink inside
        et = (0, s * 0.42, 0)
        cone((s * 0.255, 0.0, 1.04), (0.155, 0.10, 0.20), pal["ear"], rot=et, r2=0.18)
        cone((s * 0.245, -0.045, 1.02), (0.095, 0.06, 0.14), flat(pal.get("ear_in", PINK)), rot=et, r2=0.15)
        cur[0] = "Head"
        ball((s * 0.042, -0.335, 0.675), (0.055, 0.045, 0.042), pal["muzzle"], seg=16)
        # eyes: outline, gradient iris, pupil, two glints, laid on the head surface
        ex, z = s * 0.158, 0.785
        u = 1 - (ex / HS.x) ** 2 - ((z - HC.z) / HS.z) ** 2
        p = Vector((ex, HC.y - HS.y * u ** 0.5, z))
        nrm = Vector((p.x / HS.x**2, (p.y - HC.y) / HS.y**2, (p.z - HC.z) / HS.z**2)).normalized()
        q = (-nrm).to_track_quat('Y', 'Z')
        ball(p - nrm * 0.012, (0.092, 0.016, 0.104), flat(BLACK), GLOSS, q, 24)
        ball(p - nrm * 0.006, (0.078, 0.020, 0.090), zfade(pal["eye_bottom"], pal["eye_top"], z - 0.07, z + 0.05), GLOSS, q, 24)
        ball(p + nrm * 0.004, (0.034, 0.014, 0.056), flat(BLACK), GLOSS, q, 16)
        ball(p + nrm * 0.016 + Vector((-0.026, 0, 0.034)), (0.02, 0.008, 0.02), flat(WHITE), GLOSS, q, 12)
        ball(p + nrm * 0.014 + Vector((0.022, 0, -0.03)), (0.01, 0.006, 0.01), flat(WHITE), GLOSS, q, 12)
        cur[0] = "Arm" + side
        ball((s * 0.235, -0.02, 0.42), (0.072, 0.072, 0.135), pal["arm"], rot=(0, -s * 0.7, 0), seg=20)
        cur[0] = "Foot" + side
        ball((s * 0.12, -0.05, 0.075), (0.10, 0.14, 0.075), pal["foot"], seg=20)
    cur[0] = "Head"
    ball((0, -0.378, 0.705), (0.03, 0.018, 0.02), flat(pal.get("nose", PINK)), GLOSS, seg=12)

    # ---- tail: tapered hook curling away from the head
    pts, N = TAIL_PTS, len(TAIL_PTS)
    tube(pts, [0.058 - 0.014 * i / (N - 1) for i in range(N)], pal["tail"], ring_w=[tail_w(i) for i in range(N)])
    cur[0] = "Tail4"
    ball(pts[-1], (0.044,) * 3, pal["tail"], seg=12)

    # ---- collar + bell
    cur[0] = "Body"
    ring = [Vector((0.172 * math.cos(a), 0.152 * math.sin(a), 0.475)) for a in (i * math.tau / 24 for i in range(24))]
    tube(ring, [0.026] * 24, flat(pal["collar"]), closed=True, n=8)
    ball((0, -0.185, 0.44), (0.042,) * 3, flat(GOLD), GLOSS, seg=16)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.index_update()
    sources = {v.index: (tuple(co), fn) for v, (co, fn) in sources.items()}
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.data.collections[collection].objects.link(ob)

    # every part an island of the texture, each as big as its share of the body
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    skin = bake(me, sources, name + "_Skin")
    me.materials.append(tex_mat(name + "_Fur", 0.75, skin))
    me.materials.append(tex_mat(name + "_Gloss", 0.12, skin))
    for g in GROUPS:
        ob.vertex_groups.new(name=g)
    return rig(name, ob, x, collection)


# ---------------------------------------------------------------- rig
def bone_defs():
    """(name, head, tail, parent, roll axis). Roll axis = where the bone's local Z points,
    so the animation angles below mean the same thing on every bone."""
    F, X, U = Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))
    d = [("Root", (0, 0, 0), (0, 0.3, 0), None, U),
         ("Body", (0, 0, 0.12), (0, 0, 0.50), "Root", F),
         ("Head", (0, 0, 0.50), (0, 0, 0.95), "Body", F)]
    for s, side in ((1, ".L"), (-1, ".R")):
        d += [("Ear" + side, (s * 0.173, 0, 0.857), (s * 0.337, 0, 1.223), "Head", F),
              ("Arm" + side, (s * 0.19, -0.02, 0.48), (s * 0.31, -0.03, 0.33), "Body", F),
              ("Foot" + side, (s * 0.12, -0.02, 0.20), (s * 0.12, -0.05, 0.04), "Root", F)]
    for n in range(4):
        d.append(("Tail%d" % (n + 1), TAIL_PTS[TAIL_JOINTS[n]], TAIL_PTS[TAIL_JOINTS[n + 1]], "Tail%d" % n if n else "Body", X))
    return d


def rig(name, ob, x, collection):
    old = bpy.data.objects.get("Rig_" + name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    arm = bpy.data.objects.new("Rig_" + name, bpy.data.armatures.new("Rig_" + name))
    arm.location.x = x
    bpy.data.collections[collection].objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for bname, head, tail, parent, roll in bone_defs():
        b = eb.new(bname)
        b.head, b.tail = head, tail
        b.align_roll(roll)
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return arm


# ---------------------------------------------------------------- animations (24 fps)
# Angles in degrees, in bone-local XYZ:
#   Root        loc = world x/y/z, rot Z = spin
#   Body, Head  rot X = lean forward, Z = tilt sideways; Body loc Y = up
#   Arm, Foot   rot X = swing forward; Arm rot Z = raise (+ for .L, - for .R)
#   Tail1-4     rot X = sway sideways, Z = curl up;  Ear rot Z = flop
def _arms(z):
    return {"Arm.L": dict(rot=(0, 0, z)), "Arm.R": dict(rot=(0, 0, -z))}


def _tail(sway):
    return {"Tail%d" % n: dict(rot=(sway * f, 0, 0)) for n, f in ((1, 1.0), (2, 0.8), (3, 0.6))}


_breath = dict(scale=(1.02, 0.975, 1.02))
_rest = dict(scale=(1, 1, 1))
_step = lambda a: {"Foot.L": dict(rot=(a, 0, 0)), "Foot.R": dict(rot=(-a, 0, 0)),
                   "Arm.L": dict(rot=(-a * 0.9, 0, 0)), "Arm.R": dict(rot=(a * 0.9, 0, 0))}
_hop_lo = {"Root": dict(loc=(0, 0, 0)), "Body": dict(scale=(1.06, 0.92, 1.06)), "Head": dict(rot=(0, 0, 0)),
           "Foot.L": dict(rot=(0, 0, 0)), "Foot.R": dict(rot=(0, 0, 0)), **_arms(125), **_tail(0)}
_hop_hi = lambda tilt: {"Root": dict(loc=(0, 0, 0.3)), "Body": dict(scale=(0.96, 1.06, 0.96)), "Head": dict(rot=(-12, 0, tilt)),
                        "Foot.L": dict(rot=(-25, 0, 0)), "Foot.R": dict(rot=(-25, 0, 0)), **_arms(140), **_tail(tilt * 2)}


def _swat(side, sign):
    """One paw thrown out to the side and across the front; `sign` is +1 for .L, -1 for .R (Arm rot Z)."""
    arm = "Arm" + side
    return {
        0: {},
        3: {"Body": dict(rot=(-4, 0, 0)), "Head": dict(rot=(-4, 0, 0)), arm: dict(rot=(30, 0, 100 * sign))},  # out to the side
        6: {"Body": dict(rot=(6, 0, 0)), "Head": dict(rot=(3, 0, 0)), arm: dict(rot=(60, 0, -10 * sign))},  # across the front
        8: {arm: dict(rot=(55, 0, -5 * sign))},
        13: {"Body": dict(rot=(0, 0, 0)), "Head": dict(rot=(0, 0, 0)), arm: dict(rot=(0, 0, 0))},
    }


ANIMS = {
    "idle": {  # 2 s loop: breathing, head sway, tail swish, one ear twitch
        0: {"Body": _rest, "Head": dict(rot=(0, 0, 0)), "Ear.L": dict(rot=(0, 0, 0)), **_tail(0)},
        12: {"Body": _breath, "Head": dict(rot=(2, 0, 3)), **_tail(14)},
        24: {"Body": _rest, "Head": dict(rot=(0, 0, 0)), **_tail(0)},
        28: {"Ear.L": dict(rot=(0, 0, 0))},
        31: {"Ear.L": dict(rot=(-20, 0, 0))},  # flicked back: no wider than the head, so the menus need no room for it
        34: {"Ear.L": dict(rot=(0, 0, 0))},
        36: {"Body": _breath, "Head": dict(rot=(2, 0, -3)), **_tail(-14)},
        48: {"Body": _rest, "Head": dict(rot=(0, 0, 0)), "Ear.L": dict(rot=(0, 0, 0)), **_tail(0)},
    },
    "walk": {  # 16-frame loop: waddle with a bounce on every step
        0: {**_step(35), "Body": dict(loc=(0, 0, 0), rot=(0, 0, 5)), "Head": dict(rot=(0, 0, -3)), **_tail(12)},
        4: {**_step(0), "Body": dict(loc=(0, 0.045, 0), rot=(0, 0, 0)), "Head": dict(rot=(0, 0, 0)), **_tail(0)},
        8: {**_step(-35), "Body": dict(loc=(0, 0, 0), rot=(0, 0, -5)), "Head": dict(rot=(0, 0, 3)), **_tail(-12)},
        12: {**_step(0), "Body": dict(loc=(0, 0.045, 0), rot=(0, 0, 0)), "Head": dict(rot=(0, 0, 0)), **_tail(0)},
        16: {**_step(35), "Body": dict(loc=(0, 0, 0), rot=(0, 0, 5)), "Head": dict(rot=(0, 0, -3)), **_tail(12)},
    },
    "place_bomb": {  # one shot: crouch and push both paws forward
        0: {"Body": dict(loc=(0, 0, 0), rot=(0, 0, 0)), "Head": dict(rot=(0, 0, 0)), "Arm.L": dict(rot=(0, 0, 0)), "Arm.R": dict(rot=(0, 0, 0))},
        6: {"Body": dict(loc=(0, -0.05, 0), rot=(10, 0, 0)), "Head": dict(rot=(6, 0, 0)), "Arm.L": dict(rot=(75, 0, 0)), "Arm.R": dict(rot=(75, 0, 0))},
        10: {"Body": dict(loc=(0, -0.06, 0), rot=(12, 0, 0)), "Head": dict(rot=(8, 0, 0)), "Arm.L": dict(rot=(85, 0, 0)), "Arm.R": dict(rot=(85, 0, 0))},
        20: {"Body": dict(loc=(0, 0, 0), rot=(0, 0, 0)), "Head": dict(rot=(0, 0, 0)), "Arm.L": dict(rot=(0, 0, 0)), "Arm.R": dict(rot=(0, 0, 0))},
    },
    "die": {  # one shot: blown up, spins in the air, lands flat as a pancake
        0: {"Root": dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)), **_arms(0), "Head": dict(rot=(0, 0, 0))},
        5: {"Root": dict(loc=(0, 0, 0.45), rot=(0, 0, 180), scale=(1, 1, 1)), **_arms(120), "Head": dict(rot=(-15, 0, 0))},
        12: {"Root": dict(loc=(0, 0, 0.55), rot=(0, 0, 450), scale=(1, 1, 1)), **_arms(130), "Head": dict(rot=(-15, 0, 0))},
        20: {"Root": dict(loc=(0, 0, 0), rot=(0, 0, 720), scale=(1, 1, 1)), **_arms(100), "Head": dict(rot=(0, 0, 0))},
        24: {"Root": dict(loc=(0, 0, 0), rot=(0, 0, 720), scale=(1.5, 1.5, 0.14)), **_arms(90), "Head": dict(rot=(0, 0, 0))},
        30: {"Root": dict(loc=(0, 0, 0), rot=(0, 0, 720), scale=(1.6, 1.6, 0.10)), **_arms(90), "Head": dict(rot=(0, 0, 0))},
    },
    "win": {  # 1 s loop: two happy hops with the arms up
        0: _hop_lo, 6: _hop_hi(6), 12: _hop_lo, 18: _hop_hi(-6), 24: _hop_lo,
    },
    # The Laser Pointer's hunt (docs/laser-pointer.md). The game scales the pounce's height.
    "pounce": {  # one shot: crouch, a hop as high as win's at the dot with the paws up, land on it
        0: {},
        4: {"Body": dict(loc=(0, -0.06, 0), rot=(6, 0, 0), scale=(1.06, 0.92, 1.06)), "Head": dict(rot=(-6, 0, 0)),
            **_arms(20), **_tail(0)},
        8: {"Root": dict(loc=(0, 0, 0.3)), "Body": dict(loc=(0, 0, 0), rot=(-6, 0, 0), scale=(0.95, 1.07, 0.95)),
            "Head": dict(rot=(-6, 0, 0)), **_arms(140), "Foot.L": dict(rot=(-30, 0, 0)), "Foot.R": dict(rot=(-30, 0, 0)), **_tail(10)},
        12: {"Root": dict(loc=(0, 0, 0)), "Body": dict(loc=(0, -0.05, 0), rot=(6, 0, 0), scale=(1.07, 0.9, 1.07)),
             "Head": dict(rot=(0, 0, 0)), **_arms(60), "Foot.L": dict(rot=(0, 0, 0)), "Foot.R": dict(rot=(0, 0, 0)), **_tail(-6)},
        18: {"Root": dict(loc=(0, 0, 0)), "Body": dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)), "Head": dict(rot=(0, 0, 0)),
             **_arms(0), **_tail(0)},
    },
    "swat_l": _swat(".L", 1),  # one shot: wind one paw up and slap it down in front
    "swat_r": _swat(".R", -1),
    "bite": {  # one shot: draw the head back, lunge it forward at the dot with the paws out, chomp twice
        0: {},
        3: {"Root": dict(loc=(0, 0, 0)), "Body": dict(rot=(-4, 0, 0)), "Head": dict(rot=(-10, 0, 0))},
        6: {"Root": dict(loc=(0, -0.12, 0)), "Body": dict(rot=(6, 0, 0)), "Head": dict(rot=(4, 0, 6), scale=(1, 1, 1)),
            "Arm.L": dict(rot=(70, 0, 0)), "Arm.R": dict(rot=(70, 0, 0))},
        8: {"Head": dict(rot=(-4, 0, -6), scale=(1.08, 0.9, 1.08))},
        10: {"Head": dict(rot=(5, 0, 6), scale=(1, 1, 1))},
        12: {"Head": dict(rot=(-2, 0, -4), scale=(1.08, 0.9, 1.08))},
        16: {"Root": dict(loc=(0, 0, 0)), "Body": dict(rot=(0, 0, 0)), "Head": dict(rot=(0, 0, 0), scale=(1, 1, 1)),
             "Arm.L": dict(rot=(0, 0, 0)), "Arm.R": dict(rot=(0, 0, 0))},
    },
}
_PROP = dict(rot="rotation_euler", loc="location", scale="scale")


def _use(ad_or_strip, act):
    if hasattr(ad_or_strip, "action_slot") and getattr(act, "slots", None):
        ad_or_strip.action_slot = act.slots[0]


def animate(rigs):
    """Keys every action on the first rig, then stashes them all (muted NLA tracks, so glTF
    export picks each one up as its own animation) on every rig. 'idle' stays active."""
    first = rigs[0]
    for name in ANIMS:
        if name in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[name])
    acts = []
    for name, frames in ANIMS.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        first.animation_data_create().action = act
        # key every bone at rest on frame 0, so no action inherits the pose of the one played before
        for pb in first.pose.bones:
            for ch, prop in _PROP.items():
                if ch not in frames[0].get(pb.name, {}):
                    pb.keyframe_insert(prop, frame=0)
        for frame, pose in frames.items():
            for bone, chans in pose.items():
                pb = first.pose.bones[bone]
                for ch, val in chans.items():
                    setattr(pb, _PROP[ch], [math.radians(v) for v in val] if ch == "rot" else val)
                    pb.keyframe_insert(_PROP[ch], frame=frame)
        for pb in first.pose.bones:
            pb.location, pb.rotation_euler, pb.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
        acts.append(act)
    for arm in rigs:
        ad = arm.animation_data_create()
        for act in acts:
            ad.action = act
            _use(ad, act)
            tr = ad.nla_tracks.new()
            tr.name = act.name
            _use(tr.strips.new(act.name, 0, act), act)
            tr.mute = True
        ad.action = acts[0]
        _use(ad, acts[0])


# ---------------------------------------------------------------- cats
V = lambda *c: Vector(c)

# Turing, siamese (seal point): warm tan coat, near-black mask, ears, legs and tail, icy blue eyes
CREAM, POINT = V(0.45, 0.27, 0.15), V(0.03, 0.018, 0.014)
_face = V(0, -0.36, 0.73)


def _siam_head(p):
    d = Vector(((p.x - _face.x) * 0.72, (p.y - _face.y) * 0.6, (p.z - _face.z) * 1.4)).length
    return CREAM.lerp(POINT, sstep(0.40, 0.22, d))  # colours are linear: mid-blend reads pale, keep it steep


TURING = dict(
    body=lambda p: CREAM.lerp(V(0.64, 0.45, 0.29), sstep(0.26, 0.08, (p - V(0, -0.21, 0.28)).length)),
    head=_siam_head, ear=zfade(CREAM, POINT, 0.78, 0.92), ear_in=V(0.22, 0.09, 0.08), muzzle=flat(V(0.06, 0.035, 0.026)), nose=POINT,
    arm=zfade(POINT, CREAM, 0.33, 0.40), foot=zfade(POINT, CREAM, 0.10, 0.16),
    tail=lambda p: CREAM.lerp(POINT, sstep(0.22, 0.36, p.y + (p.z - 0.2))),
    eye_top=V(0.10, 0.36, 0.85), eye_bottom=V(0.60, 0.88, 1.0), collar=V(0.8, 0.04, 0.04),
)

# Berni, tuxedo: black with a white blaze from between the eyes down to muzzle, jaw and bib,
# long white gloves, white socks and tail tip, dark ears, a black chin mark, sage-green eyes
TBLK, TWHT = V(0.012, 0.012, 0.016), V(0.93, 0.93, 0.91)
_tux_blaze = blaze(0.90, brow=0.08)
BERNI = dict(
    body=patches(TBLK, ((0, -0.22, 0.31), 0.24, TWHT)),
    head=patches(lambda p: TBLK.lerp(TWHT, _tux_blaze(p)), (CHIN, 0.04, TBLK)),
    ear=flat(TBLK), ear_in=V(0.07, 0.04, 0.045), muzzle=flat(TWHT),
    arm=zfade(TWHT, TBLK, 0.42, 0.46), foot=flat(TWHT),
    tail=patches(TBLK, (TAIL_TIP, 0.13, TWHT)),
    eye_top=V(0.10, 0.26, 0.05), eye_bottom=V(0.62, 0.80, 0.30), collar=V(0.03, 0.2, 0.85),
)

# Hami, calico: white face blaze, chest and legs; black mask over the cat's left eye and ear,
# orange temple and crown on its right; orange saddle between black shoulders and rump
ORANGE, CBLK, CWHT = V(0.8, 0.28, 0.04), V(0.02, 0.018, 0.016), V(0.95, 0.94, 0.9)
PEACH = V(0.9, 0.55, 0.28)
_cal_blaze = blaze(0.95, brow=0.085)
_cal_mask = patches(CBLK, ((-0.43, -0.06, 0.78), 0.20, ORANGE), ((-0.12, -0.12, 1.08), 0.17, ORANGE), ((0.20, 0.26, 0.86), 0.19, ORANGE))
_cal_back = patches(ORANGE, ((0.08, 0.10, 0.52), 0.20, CBLK), ((-0.04, 0.20, 0.10), 0.19, CBLK))
HAMI = dict(
    body=lambda p: CWHT.lerp(_cal_back(p), sstep(-0.02, 0.04, p.y + 0.35 * p.x)),  # colour wraps forward on its left flank
    head=patches(lambda p: _cal_mask(p).lerp(CWHT, _cal_blaze(p)), (CHIN, 0.035, CBLK)),
    ear=by_side(ORANGE, CBLK), muzzle=patches(CWHT, ((0.085, -0.36, 0.665), 0.035, PEACH)),
    arm=lambda p: CWHT.lerp(PEACH, sstep(0.38, 0.34, p.z) * (p.x < 0)), foot=flat(CWHT),
    tail=lambda p: ORANGE.lerp(CBLK, sstep(0.50, 0.58, p.z)),
    eye_top=V(0.10, 0.42, 0.10), eye_bottom=V(0.60, 0.95, 0.42), collar=V(0.05, 0.55, 0.12),
)

# Ada Lovelace: white with a chocolate mask and ears, white streaks on the forehead, a black
# smudge down the nose, marbled taupe and apricot back, blue eyes
BROWN, SOOT, TAUPE, APRICOT, SWHT = V(0.10, 0.055, 0.04), V(0.012, 0.01, 0.01), V(0.26, 0.20, 0.17), V(0.85, 0.52, 0.32), V(0.95, 0.95, 0.95)
_str_jaw = blaze(0.90, brow=0)
_str_warm = patches(SWHT, ((0.10, 0.20, 0.44), 0.11, APRICOT), ((-0.12, 0.16, 0.24), 0.10, APRICOT), ((0.20, 0.02, 0.22), 0.08, APRICOT))


_str_band = lambda p: sstep(-0.15, 0.45, math.sin(p.z * 34 + 2.2 * math.sin(p.x * 9 + p.y * 6) + p.x * 7))  # wavy marbling


def _str_body(p):
    # marbled back and flanks: taupe bands over white and apricot; chest and belly stay white
    return SWHT.lerp(_str_warm(p).lerp(TAUPE, _str_band(p)), sstep(0.0, 0.10, p.y + 1.5 * abs(p.x) - 0.06))


ADA = dict(
    body=_str_body,
    head=patches(lambda p: BROWN.lerp(SWHT, _str_jaw(p)), ((-0.03, -0.34, 0.80), 0.035, SWHT), ((-0.045, -0.33, 0.86), 0.045, SWHT),
                 ((-0.06, -0.31, 0.92), 0.04, SWHT), ((0.08, -0.30, 0.94), 0.045, SWHT), ((0.008, -0.35, 0.745), 0.065, SOOT)),
    ear=flat(BROWN), muzzle=patches(SWHT, ((0.01, -0.37, 0.72), 0.05, SOOT)), nose=SOOT,
    arm=lambda p: SWHT.lerp(TAUPE, (0.35 + 0.65 * _str_band(p)) * sstep(0.21, 0.26, abs(p.x)) * sstep(0.34, 0.39, p.z)), foot=flat(SWHT),  # marbled outside, white mitts
    tail=zfade(TAUPE, BROWN, 0.30, 0.60),
    eye_top=V(0.04, 0.30, 0.62), eye_bottom=V(0.40, 0.80, 0.95), collar=V(0.45, 0.08, 0.7),
)

# Aquiles: taupe-grey tabby with dark stripes; white blaze, muzzle, bib and toes; ringed
# dark-tipped tail; pale blue eyes
TGREY, TDARK, TLIGHT = V(0.30, 0.24, 0.19), V(0.04, 0.034, 0.03), V(0.93, 0.92, 0.89)
_stripe = lambda phase: sstep(0.15, 0.55, math.sin(phase))
_tab_blaze = blaze(0.86, brow=0.07, jaw=0.20)


def _tabby_body(p):
    c = TGREY.lerp(TDARK, _stripe(p.z * 38 + abs(p.x) * 6) * sstep(-0.12, 0.04, p.y))  # bands across the back
    return c.lerp(TLIGHT, sstep(0.23, 0.14, (p - V(0, -0.24, 0.30)).length))


def _tabby_head(p):
    brow = _stripe(p.x * 44 + math.pi / 2) * sstep(0.87, 0.93, p.z)                     # forehead "M", runs over the top
    cheek = _stripe(p.z * 42) * sstep(0.26, 0.32, abs(p.x)) * sstep(0.88, 0.80, p.z)   # whisker stripes on the cheeks
    return TGREY.lerp(TDARK, max(brow, cheek)).lerp(TLIGHT, _tab_blaze(p))


AQUILES = dict(
    body=_tabby_body, head=_tabby_head, ear=zfade(TGREY, TDARK, 0.95, 1.15), muzzle=flat(TLIGHT),
    arm=lambda p: TGREY.lerp(TDARK, _stripe(p.z * 60)).lerp(TLIGHT, sstep(0.345, 0.325, p.z)),
    foot=lambda p: TGREY.lerp(TLIGHT, sstep(-0.05, -0.09, p.y)),
    tail=lambda p: TGREY.lerp(TDARK, max(_stripe((p.y + p.z) * 34), sstep(0.25, 0.10, (p - TAIL_TIP).length))),
    eye_top=V(0.10, 0.27, 0.50), eye_bottom=V(0.52, 0.76, 0.90), collar=V(0.95, 0.45, 0.02),
)

CATS = dict(turing=TURING, berni=BERNI, hami=HAMI, ada=ADA, aquiles=AQUILES)
animate([build(name, pal, x=i * 1.2) for i, (name, pal) in enumerate(CATS.items())])
