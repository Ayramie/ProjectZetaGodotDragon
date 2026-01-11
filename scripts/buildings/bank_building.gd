extends Building
class_name BankBuilding


func _init() -> void:
	building_id = "bank"
	building_name = "Bank"
	building_size = Vector3(8, 5, 6)  # Bigger building
	wall_color = Color(0.5, 0.5, 0.52)  # Stone
	roof_color = Color(0.45, 0.45, 0.48)  # Stone roof
	sign_text = "Bank"


func _build_structure() -> void:
	super._build_structure()
	_add_columns()
	_add_gold_symbol()


func _add_columns() -> void:
	var column_mat := StandardMaterial3D.new()
	column_mat.albedo_color = Color(0.55, 0.55, 0.58)
	column_mat.roughness = 0.7

	for x_offset in [-3.0, 3.0]:
		var column := MeshInstance3D.new()
		column.name = "Column"
		var col_mesh := CylinderMesh.new()
		col_mesh.top_radius = 0.3
		col_mesh.bottom_radius = 0.35
		col_mesh.height = building_size.y
		column.mesh = col_mesh
		column.position = Vector3(x_offset, building_size.y / 2, building_size.z / 2 + 0.5)
		column.material_override = column_mat
		add_child(column)


func _add_gold_symbol() -> void:
	# Add a gold coin symbol above the sign
	var coin := MeshInstance3D.new()
	coin.name = "GoldSymbol"
	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = 0.4
	coin_mesh.bottom_radius = 0.4
	coin_mesh.height = 0.1
	coin.mesh = coin_mesh
	coin.rotation_degrees.x = 90
	coin.position = Vector3(0, building_size.y + 0.8, building_size.z / 2 + 0.1)

	var coin_mat := StandardMaterial3D.new()
	coin_mat.albedo_color = Color(1.0, 0.85, 0.3)
	coin_mat.metallic = 0.9
	coin_mat.emission_enabled = true
	coin_mat.emission = Color(1.0, 0.85, 0.3)
	coin_mat.emission_energy_multiplier = 0.3
	coin.material_override = coin_mat
	add_child(coin)
