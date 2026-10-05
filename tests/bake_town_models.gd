extends SceneTree
const Factory = preload("res://scripts/town_models.gd")
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/town")
	for kind in ["house", "shop", "shed", "clocktower", "reservoir", "greenhouse", "gate", "stairs", "bridge", "bench", "planter", "lamp"]:
		var factory := Factory.new()
		var model := factory.create(kind)
		# Batch identical materials into single real meshes to keep map rendering light.
		var groups := {}
		for child in model.get_children():
			var material: Material = child.material_override
			if not groups.has(material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[material] = surface
			var surface: SurfaceTool = groups[material]
			surface.append_from(child.mesh, 0, child.transform)
		for child in model.get_children():
			child.free()
		for material in groups:
			var mesh := MeshInstance3D.new()
			mesh.mesh = groups[material].commit()
			mesh.material_override = material
			model.add_child(mesh)
			mesh.owner = model
		var scene := PackedScene.new()
		var result := scene.pack(model)
		if result == OK:
			result = ResourceSaver.save(scene, "res://assets/models/town/%s.tscn" % kind)
		if result != OK:
			push_error("Could not save model: " + kind)
			quit(1)
			return
		print("MODEL: ", kind, " / ", model.get_child_count(), " mesh parts")
		model.free()
	quit()
