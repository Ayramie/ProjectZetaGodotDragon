extends Node3D
class_name TownScene
## Town hub scene - safe area with NPCs, shops, and services.
## Players start here and travel to adventure areas via portals.

@onready var world: Node3D = $World
@onready var entities: Node3D = $Entities
@onready var ui_layer: CanvasLayer = $UI
@onready var spawn_points: Node3D = $World/SpawnPoints

var player: Player = null
var camera: ThirdPersonCamera = null
var player_inventory: Inventory = null

# UI references
var hud: HUD = null
var inventory_ui: InventoryUI = null
var dialogue_ui = null  # DialogueUI - will be created later
var shop_ui = null  # ShopUI - will be created later
var bank_ui = null  # BankUI - will be created later

# Scene paths
var hud_scene_path: String = "res://ui/hud/hud.tscn"
var inventory_ui_path: String = "res://ui/inventory/inventory_ui.tscn"

# Buildings
var buildings: Array[Building] = []
var buildings_container: Node3D = null


func _ready() -> void:
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_start_town()


func _start_town() -> void:
	GameManager.set_game_state(GameManager.GameState.PLAYING)

	# Setup buildings first (so NPCs can be positioned relative to them)
	_setup_buildings()

	# Spawn player
	_spawn_player()

	# Setup camera
	_setup_camera()

	# Setup UI
	_setup_ui()

	# Setup town NPCs and services
	_setup_npcs()
	_setup_crafting_stations()

	EventBus.game_started.emit()


func _spawn_player() -> void:
	# Determine spawn position
	var spawn_name := SaveManager.get_spawn_point()
	if spawn_name.is_empty():
		spawn_name = "default"

	var spawn_pos := Vector3(0, 0.5, 0)
	if spawn_points:
		var spawn_marker := spawn_points.get_node_or_null(spawn_name)
		if spawn_marker:
			spawn_pos = spawn_marker.global_position
		else:
			# Try default spawn
			spawn_marker = spawn_points.get_node_or_null("default")
			if spawn_marker:
				spawn_pos = spawn_marker.global_position

	# Create player based on selected class
	player = _create_player_instance(GameManager.get_class_name_string().to_lower())

	if player:
		entities.add_child(player)
		player.global_position = spawn_pos

		# Register player with GameManager
		GameManager.register_player(player)

		# Handle inventory - check if we already have one from previous scene
		if GameManager.inventory:
			player_inventory = GameManager.inventory
		else:
			# Create new inventory
			player_inventory = Inventory.new()
			GameManager.inventory = player_inventory

		# Initialize bank if needed
		if not GameManager.player_bank:
			GameManager.player_bank = BankStorage.new()

		# Check if we're loading a save
		if SaveManager.has_pending_load():
			SaveManager.apply_player_data(player)
			SaveManager.apply_inventory_data(player_inventory)
		elif SaveManager.has_scene_transition_data():
			# Restore state from scene transition
			SaveManager.apply_scene_transition_data(player)
		else:
			# New game - give starter items
			player_inventory.give_starter_items(GameManager.get_class_name_string())

		# Start tutorial quest if new player
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
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _setup_camera() -> void:
	camera = ThirdPersonCamera.new()
	camera.name = "ThirdPersonCamera"

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 50.0
	cam.near = 0.1
	cam.far = 200.0
	cam.current = true
	camera.add_child(cam)

	add_child(camera)
	camera.target = player

	if player:
		player.set_camera(camera)


func _setup_ui() -> void:
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

	# Create DialogueUI
	dialogue_ui = DialogueUI.new()
	ui_layer.add_child(dialogue_ui)

	# Create ShopUI
	shop_ui = ShopUI.new()
	ui_layer.add_child(shop_ui)

	# Create BankUI
	bank_ui = BankUI.new()
	ui_layer.add_child(bank_ui)


func _setup_buildings() -> void:
	# Create buildings container
	buildings_container = world.get_node_or_null("Buildings")
	if not buildings_container:
		buildings_container = Node3D.new()
		buildings_container.name = "Buildings"
		world.add_child(buildings_container)

	# Clear any existing static buildings from scene
	for child in buildings_container.get_children():
		child.queue_free()

	# Create town buildings
	# General Store - left side of town
	var general_store := GeneralStoreBuilding.new()
	general_store.name = "GeneralStore"
	buildings_container.add_child(general_store)
	general_store.global_position = Vector3(-12, 0, 8)
	buildings.append(general_store)

	# Blacksmith - right side of town
	var blacksmith := BlacksmithBuilding.new()
	blacksmith.name = "Blacksmith"
	buildings_container.add_child(blacksmith)
	blacksmith.global_position = Vector3(12, 0, 8)
	buildings.append(blacksmith)

	# Healer - left back
	var healer := HealerBuilding.new()
	healer.name = "Healer"
	buildings_container.add_child(healer)
	healer.global_position = Vector3(-12, 0, -10)
	buildings.append(healer)

	# Bank - right back
	var bank := BankBuilding.new()
	bank.name = "Bank"
	buildings_container.add_child(bank)
	bank.global_position = Vector3(12, 0, -10)
	buildings.append(bank)

	# Inn - center back
	var inn := InnBuilding.new()
	inn.name = "Inn"
	buildings_container.add_child(inn)
	inn.global_position = Vector3(0, 0, -18)
	buildings.append(inn)

	# Add some small houses for ambiance
	var house_positions := [
		Vector3(-22, 0, 0),
		Vector3(22, 0, 0),
		Vector3(-18, 0, -18),
		Vector3(18, 0, -18),
	]
	for i in house_positions.size():
		var house := SmallHouseBuilding.new()
		house.name = "House%d" % i
		buildings_container.add_child(house)
		house.global_position = house_positions[i]
		# Rotate some houses to add variety
		house.rotation.y = randf() * TAU
		buildings.append(house)


func _setup_npcs() -> void:
	# Create NPCs container if not exists
	var npcs_container := world.get_node_or_null("NPCs")
	if not npcs_container:
		npcs_container = Node3D.new()
		npcs_container.name = "NPCs"
		world.add_child(npcs_container)

	# Create Shopkeeper NPC - in front of General Store building (further south)
	var shopkeeper := ShopkeeperNPC.new()
	shopkeeper.name = "Shopkeeper"
	shopkeeper.npc_name = "Marcus"
	shopkeeper.character_model_path = "res://assets/kaykit/characters/adventurers/Barbarian.glb"
	shopkeeper.shop_id = "general_store"
	shopkeeper.shop_display_name = "Marcus's General Store"
	shopkeeper.greeting = "Welcome, traveler! Browse my wares."
	shopkeeper.wander_radius = 4.0  # Stay near the store
	shopkeeper.wander_speed = 1.2
	shopkeeper.set_shop_ui(shop_ui)
	npcs_container.add_child(shopkeeper)
	shopkeeper.global_position = Vector3(-12, 0, 15)
	shopkeeper.set_home_position(Vector3(-12, 0, 15))  # Set home after positioning

	# Create Healer NPC - in front of Healer building (further south)
	var healer := HealerNPC.new()
	healer.name = "Healer"
	healer.npc_name = "Sister Elena"
	healer.character_model_path = "res://assets/kaykit/characters/adventurers/Mage.glb"
	healer.wander_radius = 3.0  # Stay close to the healing building
	healer.wander_speed = 1.0
	healer.idle_time_min = 3.0  # Healer is more calm, idles longer
	healer.idle_time_max = 8.0
	healer.set_dialogue_ui(dialogue_ui)
	npcs_container.add_child(healer)
	healer.global_position = Vector3(-12, 0, -3)
	healer.set_home_position(Vector3(-12, 0, -3))  # Set home after positioning

	# Create Banker NPC - in front of Bank building (further south)
	var banker := BankerNPC.new()
	banker.name = "Banker"
	banker.npc_name = "Goldsworth"
	banker.character_model_path = "res://assets/kaykit/characters/adventurers/Rogue_Hooded.glb"
	banker.wander_radius = 3.0  # Banker stays close to bank
	banker.wander_speed = 0.8  # Moves slowly, dignified
	banker.idle_time_min = 4.0  # Bankers are patient
	banker.idle_time_max = 10.0
	banker.set_bank_ui(bank_ui)
	npcs_container.add_child(banker)
	banker.global_position = Vector3(12, 0, -3)
	banker.set_home_position(Vector3(12, 0, -3))  # Set home after positioning

	# Create Blacksmith NPC - in front of Blacksmith building (further south)
	var blacksmith := ShopkeeperNPC.new()
	blacksmith.name = "Blacksmith"
	blacksmith.npc_name = "Forge Master Bram"
	blacksmith.character_model_path = "res://assets/kaykit/characters/adventurers/Knight.glb"
	blacksmith.shop_id = "blacksmith"
	blacksmith.shop_display_name = "Bram's Smithy"
	blacksmith.greeting = "Need steel? You've come to the right place."
	blacksmith.wander_radius = 5.0  # Blacksmith moves around more
	blacksmith.wander_speed = 1.4
	blacksmith.idle_time_min = 1.5  # Active worker
	blacksmith.idle_time_max = 4.0
	blacksmith.set_shop_ui(shop_ui)
	npcs_container.add_child(blacksmith)
	blacksmith.global_position = Vector3(12, 0, 15)
	blacksmith.set_home_position(Vector3(12, 0, 15))  # Set home after positioning


func _setup_crafting_stations() -> void:
	# Reuse life skill station classes from main game
	# Place them in a crafting area of the town
	var craft_center := Vector3(15, 0, 0)

	# Check if life skill UIs exist - they might not be loaded yet
	# The stations will work once the UI classes are available
	pass


func _input(event: InputEvent) -> void:
	# Toggle pause
	if event.is_action_pressed("ui_cancel"):
		if inventory_ui and inventory_ui.visible:
			inventory_ui.close()
		else:
			GameManager.toggle_pause()

	# Toggle inventory
	if event.is_action_pressed("toggle_inventory"):
		if inventory_ui:
			if inventory_ui.visible:
				inventory_ui.close()
			else:
				inventory_ui.open(player_inventory)

	# Hotbar items
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


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PAUSED:
			get_tree().paused = true
		GameManager.GameState.PLAYING:
			get_tree().paused = false
		GameManager.GameState.GAME_OVER:
			pass
