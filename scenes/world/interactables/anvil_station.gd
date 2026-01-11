extends LifeSkillStation
class_name AnvilStation
## Anvil station for forging metal weapons.
## Opens anvil UI when interacted.


func _ready() -> void:
	station_type = "anvil"
	prompt_text = "Press F to forge"
	super._ready()

	_create_visual()


func _create_visual() -> void:
	# Create anvil base
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.6, 0.4, 0.4)
	base.mesh = base_box
	base.position.y = 0.2

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.3, 0.3, 0.3)
	base.material_override = base_mat

	add_child(base)

	# Create anvil top
	var top := MeshInstance3D.new()
	var top_box := BoxMesh.new()
	top_box.size = Vector3(0.8, 0.2, 0.5)
	top.mesh = top_box
	top.position.y = 0.5

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.25, 0.25, 0.28)
	top_mat.metallic = 0.8
	top_mat.roughness = 0.3
	top.material_override = top_mat

	add_child(top)

	# Create anvil horn
	var horn := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.15
	cone.height = 0.4
	horn.mesh = cone
	horn.position = Vector3(0.5, 0.5, 0)
	horn.rotation.z = -PI / 2

	horn.material_override = top_mat

	add_child(horn)


func _open_minigame() -> void:
	if minigame_ui is AnvilUI:
		var anvil_ui := minigame_ui as AnvilUI
		anvil_ui.crafting_complete.connect(_on_crafting_complete, CONNECT_ONE_SHOT)
		anvil_ui.crafting_cancelled.connect(_on_crafting_cancelled, CONNECT_ONE_SHOT)
		anvil_ui.start_forging(inventory)


func _on_crafting_complete(recipe_id: String, result_id: String) -> void:
	_end_interaction()


func _on_crafting_cancelled() -> void:
	_end_interaction()
