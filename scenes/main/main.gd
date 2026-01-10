extends Node3D
## Main game scene controller.
## Handles level loading, player spawning, and game flow.

@onready var world: Node3D = $World
@onready var entities: Node3D = $Entities
@onready var ui_layer: CanvasLayer = $UI

var player: Player = null
var camera: ThirdPersonCamera = null
var player_inventory: Inventory = null
var hud: HUD = null
var inventory_ui: InventoryUI = null

# Scene paths (loaded at runtime since .tscn files may not exist yet)
var player_scene_path: String = "res://scenes/player/player.tscn"
var camera_scene_path: String = "res://scenes/camera/third_person_camera.tscn"
var hud_scene_path: String = "res://ui/hud/hud.tscn"
var inventory_ui_path: String = "res://ui/inventory/inventory_ui.tscn"


func _ready() -> void:
	# Connect to game manager signals
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# If we're starting directly in this scene, start the game
	if GameManager.current_state == GameManager.GameState.MENU:
		# For testing, start immediately
		_start_game()


func _start_game() -> void:
	GameManager.set_game_state(GameManager.GameState.PLAYING)

	# Spawn player
	_spawn_player()

	# Setup camera
	_setup_camera()

	# Setup HUD
	_setup_hud()

	# Spawn initial enemies (for testing)
	_spawn_test_enemies()

	EventBus.game_started.emit()


func _spawn_player() -> void:
	# Create player based on selected class
	match GameManager.selected_class:
		GameManager.PlayerClass.WARRIOR:
			player = _create_player_instance("warrior")
		GameManager.PlayerClass.MAGE:
			player = _create_player_instance("mage")
		GameManager.PlayerClass.HUNTER:
			player = _create_player_instance("hunter")
		GameManager.PlayerClass.ADVENTURER:
			player = _create_player_instance("adventurer")

	if player:
		entities.add_child(player)
		player.global_position = Vector3(0, 0.5, 0)

		# Create and setup inventory
		player_inventory = Inventory.new()
		player_inventory.give_starter_items(GameManager.get_class_name_string())


func _create_player_instance(p_class: String) -> Player:
	var player_node := CharacterBody3D.new()

	# Add collision shape
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player_node.add_child(collision)

	# Add model container
	var model := Node3D.new()
	model.name = "Model"
	player_node.add_child(model)

	# Variables for animation setup
	var anim_player: AnimationPlayer = null
	var character_model: Node3D = null

	# Load actual character model based on class
	var model_path := _get_character_model_path(p_class)
	if ResourceLoader.exists(model_path):
		var character_scene: PackedScene = load(model_path)
		character_model = character_scene.instantiate()
		character_model.name = "CharacterMesh"
		# KayKit models are small, scale them up
		character_model.scale = Vector3(1.0, 1.0, 1.0)
		model.add_child(character_model)

		# Look for existing AnimationPlayer in the model
		anim_player = _find_animation_player(character_model)
	else:
		# Fallback to capsule mesh
		var mesh_instance := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.4
		capsule_mesh.height = 1.8
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position.y = 0.9
		# Give it a color based on class
		var mat := StandardMaterial3D.new()
		match p_class:
			"warrior": mat.albedo_color = Color(0.8, 0.6, 0.2)
			"mage": mat.albedo_color = Color(0.3, 0.3, 0.9)
			"hunter": mat.albedo_color = Color(0.2, 0.7, 0.3)
			"adventurer": mat.albedo_color = Color(0.6, 0.4, 0.6)
		mesh_instance.material_override = mat
		model.add_child(mesh_instance)

	# Create AnimationPlayer if model didn't have one
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		# Add to character model so animation paths resolve correctly
		if character_model:
			character_model.add_child(anim_player)
		else:
			player_node.add_child(anim_player)

	# Add AnimationController
	var anim_controller := AnimationController.new()
	anim_controller.name = "AnimationController"
	player_node.add_child(anim_controller)

	# Attach the appropriate class script
	var script_path := "res://scenes/player/player_classes/" + p_class + ".gd"
	if ResourceLoader.exists(script_path):
		player_node.set_script(load(script_path))
	else:
		player_node.set_script(load("res://scenes/player/player.gd"))

	player_node.name = "Player"
	return player_node


func _get_character_model_path(p_class: String) -> String:
	match p_class:
		"warrior":
			return "res://assets/kaykit/characters/adventurers/Knight.glb"
		"mage":
			return "res://assets/kaykit/characters/adventurers/Mage.glb"
		"hunter":
			return "res://assets/kaykit/characters/adventurers/Ranger.glb"
		"adventurer":
			return "res://assets/kaykit/characters/adventurers/Rogue.glb"
	return ""


func _find_animation_player(node: Node) -> AnimationPlayer:
	## Recursively find an AnimationPlayer in a node tree.
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _setup_camera() -> void:
	# Create camera rig - ThirdPersonCamera already has script via class_name
	camera = ThirdPersonCamera.new()
	camera.name = "ThirdPersonCamera"

	# Create the actual Camera3D as a child (must be added before entering tree)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 50.0
	cam.near = 0.1
	cam.far = 200.0
	cam.current = true
	camera.add_child(cam)

	# Add to scene tree
	add_child(camera)

	# Set target after adding to tree so _ready has run
	camera.target = player

	# Give player camera reference
	if player:
		player.camera = camera


func _setup_hud() -> void:
	# Instantiate HUD
	if ResourceLoader.exists(hud_scene_path):
		var hud_scene: PackedScene = load(hud_scene_path)
		hud = hud_scene.instantiate()
		ui_layer.add_child(hud)
		hud.set_player(player)
	else:
		push_warning("HUD scene not found at: " + hud_scene_path)

	# Instantiate Inventory UI
	if ResourceLoader.exists(inventory_ui_path):
		var inv_scene: PackedScene = load(inventory_ui_path)
		inventory_ui = inv_scene.instantiate()
		ui_layer.add_child(inventory_ui)
		inventory_ui.set_inventory(player_inventory)
	else:
		push_warning("Inventory UI scene not found at: " + inventory_ui_path)


func _spawn_test_enemies() -> void:
	# Spawn some test enemies
	for i in 5:
		var enemy := _create_test_enemy()
		entities.add_child(enemy)
		enemy.global_position = Vector3(
			randf_range(-20, 20),
			0.5,
			randf_range(-20, 20)
		)


func _create_test_enemy() -> EnemyBase:
	var enemy_node := CharacterBody3D.new()

	# Add collision shape
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	collision.shape = capsule
	collision.position.y = 0.8
	enemy_node.add_child(collision)

	# Add model container
	var model := Node3D.new()
	model.name = "Model"
	enemy_node.add_child(model)

	# Variables for animation setup
	var anim_player: AnimationPlayer = null
	var skeleton_model: Node3D = null

	# Load skeleton model (random type)
	var skeleton_types := [
		"res://assets/kaykit/characters/skeletons/Skeleton_Minion.glb",
		"res://assets/kaykit/characters/skeletons/Skeleton_Warrior.glb",
		"res://assets/kaykit/characters/skeletons/Skeleton_Rogue.glb",
		"res://assets/kaykit/characters/skeletons/Skeleton_Mage.glb"
	]
	var model_path: String = skeleton_types[randi() % skeleton_types.size()]

	if ResourceLoader.exists(model_path):
		var skeleton_scene: PackedScene = load(model_path)
		skeleton_model = skeleton_scene.instantiate()
		skeleton_model.name = "SkeletonMesh"
		model.add_child(skeleton_model)

		# Look for existing AnimationPlayer in the model
		anim_player = _find_animation_player(skeleton_model)
	else:
		# Fallback to red capsule
		var mesh_instance := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.4
		capsule_mesh.height = 1.6
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position.y = 0.8
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.8, 0.2, 0.2)
		mesh_instance.material_override = material
		model.add_child(mesh_instance)

	# Create AnimationPlayer if model didn't have one
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		# Add to skeleton model so animation paths resolve correctly
		if skeleton_model:
			skeleton_model.add_child(anim_player)
		else:
			enemy_node.add_child(anim_player)

	# Add AnimationController
	var anim_controller := AnimationController.new()
	anim_controller.name = "AnimationController"
	enemy_node.add_child(anim_controller)

	# Add health bar
	var health_bar := HealthBar3D.new()
	health_bar.name = "HealthBar3D"
	health_bar.position = Vector3(0, 2.2, 0)
	health_bar.bar_width = 1.2
	health_bar.max_value = 100
	health_bar.current_value = 100
	enemy_node.add_child(health_bar)

	# Attach enemy script
	enemy_node.set_script(load("res://scenes/enemies/enemy_base.gd"))
	enemy_node.name = "Enemy"

	return enemy_node


func _input(event: InputEvent) -> void:
	# Handle click-to-move
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)

	# Toggle pause
	if event.is_action_pressed("ui_cancel"):
		if inventory_ui and inventory_ui.visible:
			inventory_ui.close()
		else:
			GameManager.toggle_pause()

	# Toggle inventory (Tab or I)
	if event.is_action_pressed("toggle_inventory"):
		if inventory_ui:
			if inventory_ui.visible:
				inventory_ui.close()
			else:
				inventory_ui.open(player_inventory)

	# Hotbar items (1-5)
	if player and player_inventory:
		if event.is_action_pressed("hotbar_1"):
			player_inventory.use_hotbar_item(0, player)
		elif event.is_action_pressed("hotbar_2"):
			player_inventory.use_hotbar_item(1, player)
		elif event.is_action_pressed("hotbar_3"):
			player_inventory.use_hotbar_item(2, player)
		elif event.is_action_pressed("hotbar_4"):
			player_inventory.use_hotbar_item(3, player)
		elif event.is_action_pressed("hotbar_5"):
			player_inventory.use_hotbar_item(4, player)


func _handle_click(screen_pos: Vector2) -> void:
	if not player or not camera:
		return

	# Raycast from camera
	var cam := camera.get_node("Camera3D") as Camera3D
	if not cam:
		return

	var from := cam.project_ray_origin(screen_pos)
	var direction := cam.project_ray_normal(screen_pos)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 100)
	var result := space_state.intersect_ray(query)

	if result:
		var hit_object: Object = result.collider

		# Check if we clicked an enemy
		if hit_object is EnemyBase and hit_object.is_alive:
			player.set_target_enemy(hit_object)
			player.set_move_target(hit_object.global_position)
		else:
			# Click on ground - move to position
			player.clear_target()
			player.set_move_target(result.position)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PAUSED:
			get_tree().paused = true
		GameManager.GameState.PLAYING:
			get_tree().paused = false
		GameManager.GameState.GAME_OVER:
			# Show game over screen
			pass
