@tool
extends EditorScenePostImport
## The props are coloured by vertex colours alone, but the glTF importer only enables them
## on some of the materials; the Cats by a texture. It also gives every model the cartoon look:
## light and shade in two flat tones, a hard highlight on glossy parts and an ink outline.
## Applied to all scenes through [importer_defaults] in project.godot; after changing it, delete
## the models' imports in .godot/imported so they are imported again.

const OUTLINE: Shader = preload("res://assets/models/outline.gdshader")
## Roughness above which a material is matte and gets no highlight.
const GLOSSY := 0.35
## How soft the edge between light and shade is.
const SHADE_EDGE := 0.04
## The roughness of a glossy part, which sets the size of its toon highlight: from the models'
## 0.12 it lit everything within about 45 degrees, whitening small parts such as a Bomb's eyes.
const HIGHLIGHT := 0.03


func _post_import(scene: Node) -> Object:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		_keep_smooth_normals(node.mesh)
		for surface in node.mesh.get_surface_count():
			var material: BaseMaterial3D = node.mesh.surface_get_material(surface)
			material.vertex_color_use_as_albedo = material.albedo_texture == null  # the Cats are textured
			if material.emission_enabled:
				# Glowing parts (a Bomb's eyes and spark) shine in their own colour, as in Blender: the
				# importer turns their emission into plain white.
				material.emission_enabled = false
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			if material.roughness > GLOSSY:
				material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				material.roughness = SHADE_EDGE  # toon diffuse uses it as the width of the edge
			else:
				material.specular_mode = BaseMaterial3D.SPECULAR_TOON
				material.roughness = HIGHLIGHT
			material.next_pass = outline
	return scene


## The outline is pushed out along the normal averaged over every corner at the same place, so it
## does not break apart at hard edges. It is kept in the tangents, which no material reads and
## which bend with the skeleton.
func _keep_smooth_normals(mesh: ArrayMesh) -> void:
	var surfaces: Array[Dictionary] = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var summed: Dictionary[Vector3, Vector3] = {}
		for i in vertices.size():
			summed[vertices[i]] = summed.get(vertices[i], Vector3.ZERO) + normals[i]
		var smooth := PackedFloat32Array()
		for vertex in vertices:
			var normal := summed[vertex].normalized()
			smooth.append_array([normal.x, normal.y, normal.z, 1.0])
		arrays[Mesh.ARRAY_TANGENT] = smooth
		surfaces.append({"arrays": arrays, "primitive": mesh.surface_get_primitive_type(surface),
				"material": mesh.surface_get_material(surface), "name": mesh.surface_get_name(surface)})
	mesh.shadow_mesh = null  # the importer's one no longer matches and leaves everything in shade
	mesh.clear_surfaces()
	for surface in surfaces.size():
		mesh.add_surface_from_arrays(surfaces[surface].primitive, surfaces[surface].arrays)
		mesh.surface_set_material(surface, surfaces[surface].material)
		mesh.surface_set_name(surface, surfaces[surface].name)
