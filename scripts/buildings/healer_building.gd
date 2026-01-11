extends Building
class_name HealerBuilding


func _init() -> void:
	building_id = "healer"
	building_name = "Healer"
	building_size = Vector3(6, 4, 5)
	wall_color = Color(0.9, 0.88, 0.85)  # Light/clean color
	roof_color = Color(0.55, 0.25, 0.2)
	sign_text = "Healer"


func _build_structure() -> void:
	super._build_structure()
	_add_cross_symbol()


func _add_cross_symbol() -> void:
	# Add a simple cross above door to indicate healing
	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.8, 0.2, 0.2)
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(0.8, 0.2, 0.2)
	cross_mat.emission_energy_multiplier = 0.5

	var cross_h := MeshInstance3D.new()
	cross_h.name = "CrossH"
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.8, 0.2, 0.1)
	cross_h.mesh = h_mesh
	cross_h.position = Vector3(0, 3.2, building_size.z / 2 + 0.1)
	cross_h.material_override = cross_mat
	add_child(cross_h)

	var cross_v := MeshInstance3D.new()
	cross_v.name = "CrossV"
	var v_mesh := BoxMesh.new()
	v_mesh.size = Vector3(0.2, 0.8, 0.1)
	cross_v.mesh = v_mesh
	cross_v.position = Vector3(0, 3.2, building_size.z / 2 + 0.1)
	cross_v.material_override = cross_mat
	add_child(cross_v)
