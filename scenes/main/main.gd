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

# Life skill UIs
var fishing_minigame: FishingMinigame = null
var mining_minigame: MiningMinigame = null
var chopping_minigame: ChoppingMinigame = null
var cooking_ui: CookingUI = null
var smelting_ui: SmeltingUI = null
var anvil_ui: AnvilUI = null
var crafting_ui: CraftingUI = null

# Life skill stations
var life_skill_stations: Array[Node3D] = []

# Scene paths (loaded at runtime since .tscn files may not exist yet)
var player_scene_path: String = "res://scenes/player/player.tscn"
var camera_scene_path: String = "res://scenes/camera/third_person_camera.tscn"
var hud_scene_path: String = "res://ui/hud/hud.tscn"
var inventory_ui_path: String = "res://ui/inventory/inventory_ui.tscn"


func _ready() -> void:
	# Connect to game manager signals
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Always start the game when this scene loads
	# This handles both direct loading and portal transitions from town
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

	# Setup life skill systems
	_setup_life_skill_uis()
	_spawn_life_skill_stations()

	EventBus.game_started.emit()


func _spawn_player() -> void:
	# Determine spawn position from spawn point or default
	var spawn_pos := Vector3(0, 0.5, 0)
	var spawn_name := SaveManager.get_spawn_point()
	if not spawn_name.is_empty():
		var spawn_points := get_node_or_null("World/SpawnPoints")
		if spawn_points:
			var spawn_marker := spawn_points.get_node_or_null(spawn_name)
			if spawn_marker:
				spawn_pos = spawn_marker.global_position

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
		player.global_position = spawn_pos

		# Register player with GameManager for enemy targeting
		GameManager.register_player(player)

		# Handle inventory - check if we already have one from previous scene
		if GameManager.inventory:
			player_inventory = GameManager.inventory
		else:
			# Create new inventory
			player_inventory = Inventory.new()
			GameManager.inventory = player_inventory

		# Check if we're loading a save
		if SaveManager.has_pending_load():
			# Apply saved player data
			SaveManager.apply_player_data(player)
			# Apply saved inventory data
			SaveManager.apply_inventory_data(player_inventory)
		elif SaveManager.has_scene_transition_data():
			# Restore state from scene transition
			SaveManager.apply_scene_transition_data(player)
		else:
			# New game - give starter items
			player_inventory.give_starter_items(GameManager.get_class_name_string())

		# Start first quest for new players
		if not QuestManager.is_quest_completed("tutorial_combat") and not QuestManager.is_quest_active("tutorial_combat"):
			QuestManager.start_quest("tutorial_combat")


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
		player.set_camera(camera)


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


func _setup_life_skill_uis() -> void:
	# Create and add all life skill UIs to the UI layer
	# These are hidden by default and shown when interacting with stations

	# Fishing minigame
	fishing_minigame = FishingMinigame.new()
	fishing_minigame.visible = false
	ui_layer.add_child(fishing_minigame)

	# Mining minigame
	mining_minigame = MiningMinigame.new()
	mining_minigame.visible = false
	ui_layer.add_child(mining_minigame)

	# Chopping minigame
	chopping_minigame = ChoppingMinigame.new()
	chopping_minigame.visible = false
	ui_layer.add_child(chopping_minigame)

	# Cooking UI
	cooking_ui = CookingUI.new()
	cooking_ui.visible = false
	ui_layer.add_child(cooking_ui)

	# Smelting UI
	smelting_ui = SmeltingUI.new()
	smelting_ui.visible = false
	ui_layer.add_child(smelting_ui)

	# Anvil UI
	anvil_ui = AnvilUI.new()
	anvil_ui.visible = false
	ui_layer.add_child(anvil_ui)

	# Crafting UI
	crafting_ui = CraftingUI.new()
	crafting_ui.visible = false
	ui_layer.add_child(crafting_ui)


func _spawn_life_skill_stations() -> void:
	# Spawn test life skill stations in the world

	# Fishing spot - near a "water" area
	var fishing_spot := FishingSpot.new()
	fishing_spot.global_position = Vector3(15, 0, 10)
	fishing_spot.minigame_ui = fishing_minigame
	fishing_spot.inventory = player_inventory
	world.add_child(fishing_spot)
	life_skill_stations.append(fishing_spot)

	# Mine nodes - scattered around rocky area
	for i in 3:
		var mine := MineNode.new()
		mine.ore_type = ["copper", "iron", "gold"][i]
		mine.global_position = Vector3(-15 + i * 5, 0, -15)
		mine.minigame_ui = mining_minigame
		mine.inventory = player_inventory
		world.add_child(mine)
		life_skill_stations.append(mine)

	# Tree nodes - forest area
	for i in 4:
		var tree := TreeNode.new()
		tree.wood_type = ["oak", "oak", "birch", "mahogany"][i]
		tree.global_position = Vector3(20 + randf_range(-5, 5), 0, -10 + i * 5)
		tree.minigame_ui = chopping_minigame
		tree.inventory = player_inventory
		world.add_child(tree)
		life_skill_stations.append(tree)

	# Camp area stations - crafting hub
	var camp_center := Vector3(-20, 0, 15)

	# Campfire for cooking
	var campfire := Campfire.new()
	campfire.global_position = camp_center
	campfire.minigame_ui = cooking_ui
	campfire.inventory = player_inventory
	world.add_child(campfire)
	life_skill_stations.append(campfire)

	# Furnace for smelting
	var furnace := Furnace.new()
	furnace.global_position = camp_center + Vector3(4, 0, 0)
	furnace.minigame_ui = smelting_ui
	furnace.inventory = player_inventory
	world.add_child(furnace)
	life_skill_stations.append(furnace)

	# Anvil for forging
	var anvil := AnvilStation.new()
	anvil.global_position = camp_center + Vector3(4, 0, 3)
	anvil.minigame_ui = anvil_ui
	anvil.inventory = player_inventory
	world.add_child(anvil)
	life_skill_stations.append(anvil)

	# Crafting bench for woodworking
	var bench := CraftingBench.new()
	bench.global_position = camp_center + Vector3(-3, 0, 2)
	bench.minigame_ui = crafting_ui
	bench.inventory = player_inventory
	world.add_child(bench)
	life_skill_stations.append(bench)


func _spawn_test_enemies() -> void:
	# Spawn a mix of enemy types
	var enemy_scenes: Array[String] = [
		"res://scenes/enemies/skeleton_minion.tscn",
		"res://scenes/enemies/skeleton_warrior.tscn",
		"res://scenes/enemies/skeleton_mage.tscn",
		"res://scenes/enemies/skeleton_rogue.tscn",
	]

	# Spawn 3 minions
	for i in 3:
		_spawn_enemy_at_position(enemy_scenes[0], Vector3(
			randf_range(-15, 15),
			0.5,
			randf_range(-15, 15)
		))

	# Spawn 2 warriors
	for i in 2:
		_spawn_enemy_at_position(enemy_scenes[1], Vector3(
			randf_range(-20, 20),
			0.5,
			randf_range(-20, 20)
		))

	# Spawn 1 mage
	_spawn_enemy_at_position(enemy_scenes[2], Vector3(
		randf_range(-25, 25),
		0.5,
		randf_range(-25, 25)
	))

	# Spawn 1 rogue
	_spawn_enemy_at_position(enemy_scenes[3], Vector3(
		randf_range(-20, 20),
		0.5,
		randf_range(-20, 20)
	))


func _spawn_enemy_at_position(scene_path: String, pos: Vector3) -> void:
	var enemy: EnemyBase = null

	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path)
		enemy = scene.instantiate()
	else:
		# Fallback to creating a basic enemy programmatically
		enemy = _create_fallback_enemy()

	if enemy:
		# Add health bar BEFORE adding to scene tree so _ready() can find it
		if not enemy.has_node("HealthBar3D"):
			var health_bar := HealthBar3D.new()
			health_bar.name = "HealthBar3D"
			health_bar.position = Vector3(0, 2.2, 0)
			health_bar.bar_width = 1.2
			health_bar.max_value = enemy.max_health if "max_health" in enemy else 100
			health_bar.current_value = health_bar.max_value
			enemy.add_child(health_bar)

		entities.add_child(enemy)
		enemy.global_position = pos


func spawn_boss() -> void:
	## Spawn a skeleton boss enemy. Call this for boss encounters.
	var boss_path := "res://scenes/enemies/skeleton_boss.tscn"
	if ResourceLoader.exists(boss_path):
		var boss_scene: PackedScene = load(boss_path)
		var boss: EnemyBase = boss_scene.instantiate()

		# Add health bar BEFORE adding to scene tree
		var health_bar := HealthBar3D.new()
		health_bar.name = "HealthBar3D"
		health_bar.position = Vector3(0, 4.5, 0)
		health_bar.bar_width = 2.5
		health_bar.max_value = boss.max_health
		health_bar.current_value = boss.max_health
		boss.add_child(health_bar)

		entities.add_child(boss)
		boss.global_position = Vector3(0, 0.5, -30)

		EventBus.boss_spawned.emit(boss)


func _create_fallback_enemy() -> EnemyBase:
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

	# Add AnimationPlayer
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	enemy_node.add_child(anim_player)

	# Add AnimationController
	var anim_controller := AnimationController.new()
	anim_controller.name = "AnimationController"
	enemy_node.add_child(anim_controller)

	# Add NavigationAgent3D for pathfinding
	var nav_agent := NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	enemy_node.add_child(nav_agent)

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
