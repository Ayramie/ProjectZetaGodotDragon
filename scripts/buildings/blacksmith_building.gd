extends Building
class_name BlacksmithBuilding


func _init() -> void:
	building_id = "blacksmith"
	building_name = "Blacksmith"
	building_size = Vector3(7, 4, 5)
	wall_color = Color(0.5, 0.5, 0.52)  # Stone color
	roof_color = Color(0.45, 0.3, 0.2)  # Wood color
	sign_text = "Blacksmith"


func _build_structure() -> void:
	super._build_structure()
	_add_anvil()
	_add_barrels()


func _add_anvil() -> void:
	var anvil := MeshInstance3D.new()
	anvil.name = "Anvil"
	var anvil_mesh := BoxMesh.new()
	anvil_mesh.size = Vector3(0.8, 0.6, 0.5)
	anvil.mesh = anvil_mesh
	anvil.position = Vector3(-4, 0.3, 3)

	var anvil_mat := StandardMaterial3D.new()
	anvil_mat.albedo_color = Color(0.3, 0.3, 0.32)
	anvil_mat.metallic = 0.8
	anvil.material_override = anvil_mat
	add_child(anvil)


func _add_barrels() -> void:
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.45, 0.3, 0.2)
	barrel_mat.roughness = 0.8

	var barrels_container := Node3D.new()
	barrels_container.name = "Barrels"
	barrels_container.position = Vector3(4, 0, 3)
	add_child(barrels_container)

	for i in 2:
		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel%d" % i
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.4
		barrel_mesh.bottom_radius = 0.45
		barrel_mesh.height = 1.0
		barrel.mesh = barrel_mesh
		barrel.position = Vector3(i * 1.0, 0.5, 0)
		barrel.material_override = barrel_mat
		barrels_container.add_child(barrel)
