extends LifeSkillStation
class_name FishingSpot
## Fishing spot station.
## Opens fishing minigame when interacted.


func _ready() -> void:
	station_type = "fishing"
	prompt_text = "Press F to fish"
	super._ready()

	# Create water visual
	_create_visual()


func _create_visual() -> void:
	# Create a simple water plane visual
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3, 3)
	mesh_instance.mesh = plane

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 0.8, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material

	add_child(mesh_instance)


func _open_minigame() -> void:
	if minigame_ui is FishingMinigame:
		var fishing_ui := minigame_ui as FishingMinigame
		fishing_ui.fishing_complete.connect(_on_fishing_complete, CONNECT_ONE_SHOT)
		fishing_ui.fishing_failed.connect(_on_fishing_failed, CONNECT_ONE_SHOT)
		fishing_ui.fishing_cancelled.connect(_on_fishing_cancelled, CONNECT_ONE_SHOT)
		fishing_ui.start_fishing()


func _on_fishing_complete(fish_id: String, quality: String) -> void:
	# Add fish to inventory
	inventory.add_item(fish_id, 1)
	_end_interaction()


func _on_fishing_failed() -> void:
	_end_interaction()


func _on_fishing_cancelled() -> void:
	_end_interaction()
