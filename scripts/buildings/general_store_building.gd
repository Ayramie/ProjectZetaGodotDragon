extends Building
class_name GeneralStoreBuilding


func _init() -> void:
	building_id = "general_store"
	building_name = "General Store"
	building_size = Vector3(6, 4, 5)
	wall_color = Color(0.85, 0.8, 0.7)
	roof_color = Color(0.55, 0.25, 0.2)
	sign_text = "General Store"


func _build_structure() -> void:
	super._build_structure()
	_add_windows()
	_add_crates()


func _add_windows() -> void:
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.45, 0.3, 0.2)
	window_mat.roughness = 0.8

	for x_offset in [-2.0, 2.0]:
		var window := MeshInstance3D.new()
		window.name = "Window"
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(0.8, 1.0, 0.15)
		window.mesh = window_mesh
		window.position = Vector3(x_offset, 2.5, building_size.z / 2 + 0.05)
		window.material_override = window_mat
		add_child(window)


func _add_crates() -> void:
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.45, 0.3, 0.2)
	crate_mat.roughness = 0.8

	var crates_container := Node3D.new()
	crates_container.name = "Crates"
	crates_container.position = Vector3(3.5, 0, 3)
	add_child(crates_container)

	for i in 2:
		var crate := MeshInstance3D.new()
		crate.name = "Crate%d" % i
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(0.8, 0.8, 0.8)
		crate.mesh = crate_mesh
		crate.position = Vector3(i * 0.9, 0.4, 0)
		crate.material_override = crate_mat
		crates_container.add_child(crate)
