extends LifeSkillStation
class_name Furnace
## Furnace station for smelting ore.
## Opens smelting UI when interacted.


func _ready() -> void:
	station_type = "smelting"
	prompt_text = "Press F to smelt"
	super._ready()

	_create_visual()


func _create_visual() -> void:
	# Create furnace body
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.5, 1.0)
	body.mesh = box
	body.position.y = 0.75

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.4, 0.35, 0.3)
	body.material_override = body_mat

	add_child(body)

	# Create opening (darker inset)
	var opening := MeshInstance3D.new()
	var opening_box := BoxMesh.new()
	opening_box.size = Vector3(0.5, 0.6, 0.2)
	opening.mesh = opening_box
	opening.position = Vector3(0, 0.5, 0.45)

	var opening_mat := StandardMaterial3D.new()
	opening_mat.albedo_color = Color(0.1, 0.05, 0.0)
	opening.material_override = opening_mat

	add_child(opening)

	# Create fire glow in opening
	var fire := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	fire.mesh = sphere
	fire.position = Vector3(0, 0.5, 0.35)

	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.4, 0.0)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.3, 0.0)
	fire_mat.emission_energy_multiplier = 3.0
	fire.material_override = fire_mat

	add_child(fire)

	# Add light
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.5, 0.6)
	light.light_color = Color(1.0, 0.5, 0.1)
	light.light_energy = 1.0
	light.omni_range = 3.0
	add_child(light)


func _open_minigame() -> void:
	if minigame_ui is SmeltingUI:
		var smelting_ui := minigame_ui as SmeltingUI
		smelting_ui.smelting_complete.connect(_on_smelting_complete, CONNECT_ONE_SHOT)
		smelting_ui.smelting_cancelled.connect(_on_smelting_cancelled, CONNECT_ONE_SHOT)
		smelting_ui.start_smelting(inventory)


func _on_smelting_complete(results: Dictionary) -> void:
	_end_interaction()


func _on_smelting_cancelled() -> void:
	_end_interaction()
