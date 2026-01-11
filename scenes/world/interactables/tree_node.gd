extends LifeSkillStation
class_name TreeNode
## Tree node station for chopping.
## Opens chopping minigame when interacted.

@export var wood_type: String = "oak"  # oak, birch, mahogany


func _ready() -> void:
	station_type = "chopping"
	prompt_text = "Press F to chop"
	super._ready()

	_create_visual()


func _create_visual() -> void:
	# Create trunk
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.4
	cylinder.height = 2.5
	trunk.mesh = cylinder
	trunk.position.y = 1.25

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.15)
	trunk.material_override = trunk_mat

	add_child(trunk)

	# Create leaves/canopy
	var leaves := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 1.8
	leaves.mesh = sphere
	leaves.position.y = 3.0

	var leaves_mat := StandardMaterial3D.new()
	match wood_type:
		"oak":
			leaves_mat.albedo_color = Color(0.2, 0.5, 0.2)
		"birch":
			leaves_mat.albedo_color = Color(0.4, 0.6, 0.3)
		"mahogany":
			leaves_mat.albedo_color = Color(0.15, 0.35, 0.15)
	leaves.material_override = leaves_mat

	add_child(leaves)


func _open_minigame() -> void:
	if minigame_ui is ChoppingMinigame:
		var chopping_ui := minigame_ui as ChoppingMinigame
		chopping_ui.chopping_complete.connect(_on_chopping_complete, CONNECT_ONE_SHOT)
		chopping_ui.chopping_cancelled.connect(_on_chopping_cancelled, CONNECT_ONE_SHOT)
		chopping_ui.start_chopping(wood_type)


func _on_chopping_complete(wood_count: int) -> void:
	# Wood is added via EventBus in the minigame
	_end_interaction()


func _on_chopping_cancelled() -> void:
	_end_interaction()
