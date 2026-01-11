extends LifeSkillStation
class_name Campfire
## Campfire station for cooking.
## Opens cooking UI when interacted.


func _ready() -> void:
	station_type = "cooking"
	prompt_text = "Press F to cook"
	super._ready()

	_create_visual()


func _create_visual() -> void:
	# Create fire base (logs)
	var logs := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 0.3
	logs.mesh = cylinder
	logs.position.y = 0.15

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.3, 0.2, 0.1)
	logs.material_override = log_mat

	add_child(logs)

	# Create fire glow (emissive sphere)
	var fire := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	fire.mesh = sphere
	fire.position.y = 0.5

	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.5, 0.1)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.4, 0.0)
	fire_mat.emission_energy_multiplier = 2.0
	fire.material_override = fire_mat

	add_child(fire)

	# Add light
	var light := OmniLight3D.new()
	light.position.y = 0.8
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 1.5
	light.omni_range = 5.0
	add_child(light)


func _open_minigame() -> void:
	if minigame_ui is CookingUI:
		var cooking_ui := minigame_ui as CookingUI
		cooking_ui.cooking_complete.connect(_on_cooking_complete, CONNECT_ONE_SHOT)
		cooking_ui.cooking_cancelled.connect(_on_cooking_cancelled, CONNECT_ONE_SHOT)
		cooking_ui.start_cooking(inventory)


func _on_cooking_complete(results: Dictionary) -> void:
	_end_interaction()


func _on_cooking_cancelled() -> void:
	_end_interaction()
