"""Exports each rigged cat (mesh + skeleton + all animations) and each prop to
game/assets/models/<name>.glb, vertex colours as COLOR_0. Run inside Blender with cats.blend open:

    exec(open(bpy.path.abspath("//export_glb.py")).read())

or headless from the repository root:

    blender -b art/cats.blend -P art/export_glb.py
"""
import bpy, os

OUT = bpy.path.abspath("//../game/assets/models")
os.makedirs(OUT, exist_ok=True)
props = bpy.ops.export_scene.gltf.get_rna_type().properties
# use_active_scene: without it the exporter also walks the render scenes (Game/Photo/Anim) and leaks their copies in
opts = dict(export_format="GLB", use_selection=True, use_active_scene=True, export_animations=True, export_skins=True,
            export_animation_mode="ACTIONS", export_vertex_color="MATERIAL", export_apply=False)
opts = {k: v for k, v in opts.items() if k in props}

for rig in [o for o in bpy.data.collections["Cats"].objects if o.type == "ARMATURE"]:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
    for child in rig.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = rig
    x, rig.location.x = rig.location.x, 0.0  # export at the origin, then put it back in the line-up
    try:
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, rig.name.replace("Rig_", "") + ".glb"), **opts)
    finally:
        rig.location.x = x
print("exported", sorted(os.listdir(OUT)), "with", opts)

# static props (no skeleton), also exported at the origin
for prop in [o for o in bpy.data.collections["Props"].objects if o.type == "MESH"]:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    prop.select_set(True)
    bpy.context.view_layer.objects.active = prop
    loc, prop.location = prop.location.copy(), (0, 0, 0)
    try:
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, prop.name + ".glb"), **{**opts, "export_animations": False})
    finally:
        prop.location = loc
print("exported", sorted(os.listdir(OUT)))
