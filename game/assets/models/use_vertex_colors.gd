@tool
extends EditorScenePostImport
## Every model is coloured by vertex colours alone, but the glTF importer only enables them
## on some of the materials. Applied to all scenes through [importer_defaults] in project.godot.


func _post_import(scene: Node) -> Object:
	for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material: BaseMaterial3D = node.mesh.surface_get_material(surface)
			material.vertex_color_use_as_albedo = true
	return scene
