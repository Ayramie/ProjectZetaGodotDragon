extends LifeSkillStation
class_name MineNode
## Mining node station.
## Opens mining minigame when interacted.

@export var ore_type: String = "copper"  # copper, iron, gold


func _ready() -> void:
	station_type = "mining"
	prompt_text = "Press F to mine"
	super._ready()

	_create_visual()


func _create_visual() -> void:
	# Create a rock visual
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.2
	mesh_instance.mesh = sphere
	mesh_instance.position.y = 0.6

	var material := StandardMaterial3D.new()
	match ore_type:
		"copper":
			material.albedo_color = Color(0.7, 0.5, 0.3)
		"iron":
			material.albedo_color = Color(0.5, 0.5, 0.55)
		"gold":
			material.albedo_color = Color(0.9, 0.8, 0.3)
	mesh_instance.material_override = material

	add_child(mesh_instance)


func _open_minigame() -> void:
	if minigame_ui is MiningMinigame:
		var mining_ui := minigame_ui as MiningMinigame
		mining_ui.mining_complete.connect(_on_mining_complete, CONNECT_ONE_SHOT)
		mining_ui.mining_cancelled.connect(_on_mining_cancelled, CONNECT_ONE_SHOT)
		mining_ui.start_mining(ore_type)


func _on_mining_complete(ore_count: int) -> void:
	# Ore is added via EventBus in the minigame
	_end_interaction()


func _on_mining_cancelled() -> void:
	_end_interaction()
