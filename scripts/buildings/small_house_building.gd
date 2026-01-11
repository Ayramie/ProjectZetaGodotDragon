extends Building
class_name SmallHouseBuilding


func _init() -> void:
	building_id = "house_small"
	building_name = "Small House"
	building_size = Vector3(4, 3, 4)
	wall_color = Color(0.8, 0.75, 0.65)
	roof_color = Color(0.5, 0.3, 0.25)
	has_sign = false
	sign_text = ""


func _build_structure() -> void:
	super._build_structure()
	_add_window()
	_add_chimney()


func _add_window() -> void:
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.45, 0.3, 0.2)

	var window := MeshInstance3D.new()
	window.name = "Window"
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.6, 0.8, 0.15)
	window.mesh = window_mesh
	window.position = Vector3(1.2, 1.8, building_size.z / 2 + 0.05)
	window.material_override = window_mat
	add_child(window)


func _add_chimney() -> void:
	var chimney := MeshInstance3D.new()
	chimney.name = "Chimney"
	var chimney_mesh := BoxMesh.new()
	chimney_mesh.size = Vector3(0.6, 1.5, 0.6)
	chimney.mesh = chimney_mesh
	chimney.position = Vector3(-1.2, building_size.y + 0.75, -1.0)

	var chimney_mat := StandardMaterial3D.new()
	chimney_mat.albedo_color = Color(0.45, 0.4, 0.38)
	chimney.material_override = chimney_mat
	add_child(chimney)
