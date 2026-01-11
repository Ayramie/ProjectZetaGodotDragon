extends Node
## Main game manager singleton.
## Handles game state, mode selection, class selection, and global game data.

signal game_state_changed(new_state: GameState)
signal game_mode_changed(new_mode: GameMode)
signal class_changed(new_class: PlayerClass)

enum GameState { MENU, LOADING, PLAYING, PAUSED, GAME_OVER }
enum GameMode { ADVENTURE, HORDE }
enum PlayerClass { WARRIOR, MAGE, HUNTER, ADVENTURER }

# Current state
var current_state: GameState = GameState.MENU
var current_mode: GameMode = GameMode.ADVENTURE
var selected_class: PlayerClass = PlayerClass.WARRIOR

# Player reference
var player: Node3D = null

# Inventory reference (set by main.gd)
var inventory: RefCounted = null

# Bank storage (persists across scenes, separate from inventory)
var player_bank: BankStorage = null

# Enemy tracking
var enemies: Array[Node3D] = []
var respawn_queue: Array[Dictionary] = []

# Screen effects
var screen_shake_intensity: float = 0.0
const SCREEN_SHAKE_DECAY: float = 0.9

# Class stats (base values from original game)
const CLASS_STATS: Dictionary = {
	PlayerClass.WARRIOR: {
		"max_health": 500,
		"move_speed": 8.0,
		"attack_range": 2.5,
		"attack_cooldown": 0.8,
		"attack_damage": 25,
		"model": "knight"
	},
	PlayerClass.MAGE: {
		"max_health": 300,
		"move_speed": 7.0,
		"attack_range": 15.0,
		"attack_cooldown": 1.0,
		"attack_damage": 20,
		"model": "mage"
	},
	PlayerClass.HUNTER: {
		"max_health": 400,
		"move_speed": 8.0,
		"attack_range": 18.0,
		"attack_cooldown": 0.6,
		"attack_damage": 15,
		"model": "ranger"
	},
	PlayerClass.ADVENTURER: {
		"max_health": 400,
		"move_speed": 7.5,
		"attack_range": 2.5,
		"attack_cooldown": 0.8,
		"attack_damage": 20,
		"model": "rogue"
	}
}

# World bounds
const WORLD_BOUNDS: Dictionary = {
	GameMode.ADVENTURE: {"min": Vector2(-95, -95), "max": Vector2(95, 95)},
	GameMode.HORDE: {"min": Vector2(-50, -55), "max": Vector2(110, 150)}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# Update screen shake decay
	if screen_shake_intensity > 0.01:
		screen_shake_intensity *= SCREEN_SHAKE_DECAY
	else:
		screen_shake_intensity = 0.0

	# Process respawn queue
	_process_respawn_queue(delta)


func set_game_state(new_state: GameState) -> void:
	if current_state != new_state:
		current_state = new_state
		game_state_changed.emit(new_state)

		match new_state:
			GameState.PAUSED:
				get_tree().paused = true
			GameState.PLAYING:
				get_tree().paused = false
			GameState.GAME_OVER:
				EventBus.game_over.emit()


func set_game_mode(new_mode: GameMode) -> void:
	if current_mode != new_mode:
		current_mode = new_mode
		game_mode_changed.emit(new_mode)


func set_player_class(new_class: PlayerClass) -> void:
	if selected_class != new_class:
		selected_class = new_class
		class_changed.emit(new_class)


func get_class_stats() -> Dictionary:
	return CLASS_STATS[selected_class].duplicate()


func get_class_name_string() -> String:
	match selected_class:
		PlayerClass.WARRIOR: return "Warrior"
		PlayerClass.MAGE: return "Mage"
		PlayerClass.HUNTER: return "Hunter"
		PlayerClass.ADVENTURER: return "Adventurer"
	return "Unknown"


func register_player(p: Node3D) -> void:
	player = p


func unregister_player() -> void:
	player = null


func register_enemy(enemy: Node3D) -> void:
	if enemy not in enemies:
		enemies.append(enemy)


func unregister_enemy(enemy: Node3D) -> void:
	enemies.erase(enemy)


func queue_enemy_respawn(enemy_data: Dictionary, delay: float) -> void:
	respawn_queue.append({
		"data": enemy_data,
		"timer": delay
	})


func _process_respawn_queue(delta: float) -> void:
	var to_spawn: Array[Dictionary] = []

	for entry in respawn_queue:
		entry.timer -= delta
		if entry.timer <= 0:
			to_spawn.append(entry)

	for entry in to_spawn:
		respawn_queue.erase(entry)
		# Signal to spawn enemy - handled by world/level manager
		# spawn_enemy(entry.data)


func add_screen_shake(intensity: float) -> void:
	screen_shake_intensity = min(screen_shake_intensity + intensity, 1.0)
	EventBus.screen_shake.emit(screen_shake_intensity)


func get_world_bounds() -> Dictionary:
	return WORLD_BOUNDS[current_mode]


func is_position_in_bounds(pos: Vector3) -> bool:
	var bounds := get_world_bounds()
	return pos.x >= bounds.min.x and pos.x <= bounds.max.x and \
		   pos.z >= bounds.min.y and pos.z <= bounds.max.y


func clamp_position_to_bounds(pos: Vector3) -> Vector3:
	var bounds := get_world_bounds()
	return Vector3(
		clamp(pos.x, bounds.min.x, bounds.max.x),
		pos.y,
		clamp(pos.z, bounds.min.y, bounds.max.y)
	)


func start_game(mode: GameMode, player_class: PlayerClass) -> void:
	set_game_mode(mode)
	set_player_class(player_class)
	set_game_state(GameState.LOADING)

	# Level loading would be handled here
	EventBus.game_started.emit()
	set_game_state(GameState.PLAYING)


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		set_game_state(GameState.PAUSED)
		EventBus.game_paused.emit()


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		set_game_state(GameState.PLAYING)
		EventBus.game_resumed.emit()


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()


func return_to_menu() -> void:
	enemies.clear()
	respawn_queue.clear()
	player = null
	set_game_state(GameState.MENU)
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
