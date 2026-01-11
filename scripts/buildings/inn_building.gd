extends Building
class_name InnBuilding


func _init() -> void:
	building_id = "inn"
	building_name = "Inn"
	building_size = Vector3(9, 5, 6)  # Large building
	wall_color = Color(0.85, 0.8, 0.7)
	roof_color = Color(0.55, 0.25, 0.2)
	sign_text = "Wanderer's Rest Inn"


func _build_structure() -> void:
	super._build_structure()
	_add_windows()
	_add_lanterns()


func _add_windows() -> void:
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.45, 0.3, 0.2)
	window_mat.roughness = 0.8

	# Ground floor windows
	for x_offset in [-3.0, 3.0]:
		var window := MeshInstance3D.new()
		window.name = "Window"
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(0.8, 1.0, 0.15)
		window.mesh = window_mesh
		window.position = Vector3(x_offset, 1.8, building_size.z / 2 + 0.05)
		window.material_override = window_mat
		add_child(window)

	# Second floor windows
	for x_offset in [-3.0, 0.0, 3.0]:
		var window := MeshInstance3D.new()
		window.name = "Window2F"
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(0.8, 1.0, 0.15)
		window.mesh = window_mesh
		window.position = Vector3(x_offset, 3.5, building_size.z / 2 + 0.05)
		window.material_override = window_mat
		add_child(window)


func _add_lanterns() -> void:
	var lantern_mat := StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(1.0, 0.9, 0.6)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1.0, 0.8, 0.4)
	lantern_mat.emission_energy_multiplier = 1.0

	for x_offset in [-4.0, 4.0]:
		var lantern := MeshInstance3D.new()
		lantern.name = "Lantern"
		var lantern_mesh := BoxMesh.new()
		lantern_mesh.size = Vector3(0.3, 0.4, 0.3)
		lantern.mesh = lantern_mesh
		lantern.position = Vector3(x_offset, 2.5, building_size.z / 2 + 0.3)
		lantern.material_override = lantern_mat
		add_child(lantern)

		# Add point light
		var light := OmniLight3D.new()
		light.name = "LanternLight"
		light.light_color = Color(1.0, 0.8, 0.5)
		light.light_energy = 0.5
		light.omni_range = 4.0
		lantern.add_child(light)
