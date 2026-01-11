extends LifeSkillStation
class_name CraftingBench
## Crafting bench station for wood-based items.
## Opens crafting UI when interacted.


func _ready() -> void:
	station_type = "crafting"
	prompt_text = "Press F to craft"
	super._ready()

	_create_visual()


func _create_visual() -> void:
	# Create workbench top
	var top := MeshInstance3D.new()
	var top_box := BoxMesh.new()
	top_box.size = Vector3(1.5, 0.15, 0.8)
	top.mesh = top_box
	top.position.y = 0.9

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.5, 0.35, 0.2)
	top.material_override = top_mat

	add_child(top)

	# Create legs
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.4, 0.28, 0.15)

	for x in [-0.6, 0.6]:
		for z in [-0.3, 0.3]:
			var leg := MeshInstance3D.new()
			var leg_box := BoxMesh.new()
			leg_box.size = Vector3(0.1, 0.85, 0.1)
			leg.mesh = leg_box
			leg.position = Vector3(x, 0.425, z)
			leg.material_override = leg_mat
			add_child(leg)

	# Create shelf/crossbar
	var shelf := MeshInstance3D.new()
	var shelf_box := BoxMesh.new()
	shelf_box.size = Vector3(1.3, 0.08, 0.6)
	shelf.mesh = shelf_box
	shelf.position.y = 0.3
	shelf.material_override = leg_mat

	add_child(shelf)


func _open_minigame() -> void:
	if minigame_ui is CraftingUI:
		var crafting_ui := minigame_ui as CraftingUI
		crafting_ui.crafting_complete.connect(_on_crafting_complete, CONNECT_ONE_SHOT)
		crafting_ui.crafting_cancelled.connect(_on_crafting_cancelled, CONNECT_ONE_SHOT)
		crafting_ui.start_crafting(inventory)


func _on_crafting_complete(recipe_id: String, result_id: String) -> void:
	_end_interaction()


func _on_crafting_cancelled() -> void:
	_end_interaction()
