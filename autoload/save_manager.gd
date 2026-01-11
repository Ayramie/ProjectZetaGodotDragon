extends Node
## Save manager singleton.
## Handles saving and loading game data.

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "save_data.json"
const SETTINGS_FILE := "settings.json"

signal save_started()
signal save_completed()
signal load_started()
signal load_completed(success: bool)

var current_save_data: Dictionary = {}
var pending_player_data: Dictionary = {}
var spawn_point: String = ""
var scene_transition_data: Dictionary = {}  # Preserves player state between scene changes


func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	# Load settings on startup
	load_settings()


func save_game() -> void:
	save_started.emit()

	# Gather save data
	current_save_data = {
		"version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"timestamp": Time.get_unix_time_from_system(),
		"game_mode": GameManager.current_mode,
		"player_class": GameManager.selected_class,
		"player": _get_player_data(),
		"inventory": _get_inventory_data(),
		"bank": _get_bank_data(),
		"quests": _get_quest_data(),
		"world": _get_world_data()
	}

	# Write to file
	var file := FileAccess.open(SAVE_DIR + SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_save_data, "\t"))
		file.close()
		save_completed.emit()
		EventBus.show_message.emit("Game Saved", Color.GREEN, 2.0)
	else:
		push_error("Failed to save game: " + str(FileAccess.get_open_error()))


func load_game() -> bool:
	load_started.emit()

	if not FileAccess.file_exists(SAVE_DIR + SAVE_FILE):
		load_completed.emit(false)
		return false

	var file := FileAccess.open(SAVE_DIR + SAVE_FILE, FileAccess.READ)
	if not file:
		load_completed.emit(false)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("Failed to parse save file: " + json.get_error_message())
		load_completed.emit(false)
		return false

	current_save_data = json.data

	# Apply loaded data
	_apply_save_data()

	load_completed.emit(true)
	return true


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_DIR + SAVE_FILE)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_DIR + SAVE_FILE):
		DirAccess.remove_absolute(SAVE_DIR + SAVE_FILE)


func save_settings() -> void:
	var settings := {
		"master_volume": AudioManager.master_volume,
		"sfx_volume": AudioManager.sfx_volume,
		"music_volume": AudioManager.music_volume,
		"ui_volume": AudioManager.ui_volume,
		"fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"vsync": DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	}

	var file := FileAccess.open(SAVE_DIR + SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_DIR + SETTINGS_FILE):
		return

	var file := FileAccess.open(SAVE_DIR + SETTINGS_FILE, FileAccess.READ)
	if not file:
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		return

	var settings: Dictionary = json.data

	# Apply settings
	if settings.has("master_volume"):
		AudioManager.set_master_volume(settings.master_volume)
	if settings.has("sfx_volume"):
		AudioManager.set_sfx_volume(settings.sfx_volume)
	if settings.has("music_volume"):
		AudioManager.set_music_volume(settings.music_volume)
	if settings.has("ui_volume"):
		AudioManager.set_ui_volume(settings.ui_volume)
	if settings.has("fullscreen") and settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if settings.has("vsync"):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED
		)


func _get_player_data() -> Dictionary:
	var player := GameManager.player
	if not player:
		return {}

	return {
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"rotation": player.rotation.y,
		"health": player.health if player.has_method("get") else 0,
		"max_health": player.max_health if player.has_method("get") else 0,
		"gold": player.gold if player.has_method("get") else 0
	}


func _get_inventory_data() -> Dictionary:
	var inventory = GameManager.inventory
	if not inventory:
		return {}

	return {
		"slots": _serialize_item_array(inventory.slots),
		"equipment": _serialize_equipment(inventory.equipment),
		"hotbar": _serialize_hotbar(inventory.hotbar),
		"gold": inventory.gold
	}


func _serialize_hotbar(hotbar: Array) -> Array:
	var result := []
	for entry in hotbar:
		if entry and entry is Dictionary:
			result.append(entry.duplicate())
		else:
			result.append(null)
	return result


func _serialize_item_array(items: Array) -> Array:
	var result := []
	for item in items:
		if item and item is ItemStack:
			result.append({
				"id": item.item_id,
				"quantity": item.quantity
			})
		else:
			result.append(null)
	return result


func _serialize_equipment(equipment: Dictionary) -> Dictionary:
	var result := {}
	for slot in equipment:
		if equipment[slot] and equipment[slot] is ItemStack:
			result[slot] = {
				"id": equipment[slot].item_id,
				"quantity": equipment[slot].quantity
			}
		else:
			result[slot] = null
	return result


func _get_bank_data() -> Dictionary:
	if GameManager.player_bank:
		return GameManager.player_bank.get_save_data()
	return {}


func _get_quest_data() -> Dictionary:
	return QuestManager.get_save_data()


func _get_world_data() -> Dictionary:
	# World state data (e.g., opened chests, defeated bosses)
	return {
		"opened_chests": [],
		"defeated_bosses": [],
		"discovered_locations": []
	}


func _apply_save_data() -> void:
	if current_save_data.is_empty():
		return

	# Set game mode and class
	if current_save_data.has("game_mode"):
		GameManager.set_game_mode(current_save_data.game_mode)
	if current_save_data.has("player_class"):
		GameManager.set_player_class(current_save_data.player_class)

	# Store player data for later application
	if current_save_data.has("player"):
		pending_player_data = current_save_data.player

	# Load quest data
	if current_save_data.has("quests"):
		QuestManager.load_save_data(current_save_data.quests)

	# Load bank data
	if current_save_data.has("bank") and not current_save_data.bank.is_empty():
		if not GameManager.player_bank:
			GameManager.player_bank = BankStorage.new()
		GameManager.player_bank.load_save_data(current_save_data.bank)


func apply_player_data(player: Node3D) -> void:
	## Call this after player is spawned to restore player state.
	if pending_player_data.is_empty():
		return

	# Restore position
	if pending_player_data.has("position"):
		var pos: Dictionary = pending_player_data.position
		player.global_position = Vector3(pos.x, pos.y, pos.z)

	# Restore rotation
	if pending_player_data.has("rotation"):
		player.rotation.y = pending_player_data.rotation

	# Restore health
	if pending_player_data.has("health") and "health" in player:
		player.health = pending_player_data.health

	# Restore gold
	if pending_player_data.has("gold") and "gold" in player:
		player.gold = pending_player_data.gold

	pending_player_data = {}


func apply_inventory_data(inventory: RefCounted) -> void:
	## Call this after inventory is created to restore inventory state.
	if not current_save_data.has("inventory"):
		return

	var inv_data: Dictionary = current_save_data.inventory

	# Clear existing inventory
	for i in inventory.slots.size():
		inventory.slots[i] = null
	for slot in inventory.equipment:
		inventory.equipment[slot] = null

	# Restore slots
	if inv_data.has("slots"):
		var slots: Array = inv_data.slots
		for i in mini(slots.size(), inventory.slots.size()):
			if slots[i] and slots[i] is Dictionary:
				inventory.slots[i] = ItemStack.new(slots[i].id, slots[i].quantity)

	# Restore equipment
	if inv_data.has("equipment"):
		var equip: Dictionary = inv_data.equipment
		for slot in equip:
			if equip[slot] and equip[slot] is Dictionary:
				inventory.equipment[slot] = ItemStack.new(equip[slot].id, equip[slot].quantity)

	# Restore hotbar
	if inv_data.has("hotbar"):
		var hotbar: Array = inv_data.hotbar
		for i in mini(hotbar.size(), inventory.hotbar.size()):
			inventory.hotbar[i] = hotbar[i]

	# Restore gold
	if inv_data.has("gold"):
		inventory.gold = inv_data.gold

	inventory.inventory_changed.emit()


func set_spawn_point(point_name: String) -> void:
	## Set spawn point for scene transitions.
	spawn_point = point_name


func get_spawn_point() -> String:
	var point := spawn_point
	spawn_point = ""
	return point


func has_pending_load() -> bool:
	return not pending_player_data.is_empty() or current_save_data.has("inventory")


func prepare_scene_transition() -> void:
	## Call before scene transition to preserve player state.
	## State will be applied to the new player instance in the destination scene.
	if not GameManager.player:
		return

	var player := GameManager.player
	scene_transition_data = {
		"health": player.health,
		"max_health": player.max_health,
	}

	# Preserve inventory reference - it stays in GameManager
	# Gold is stored in inventory, so we don't need to save it separately


func apply_scene_transition_data(player: Node3D) -> void:
	## Call after player spawns in new scene to restore state from transition.
	if scene_transition_data.is_empty():
		return

	# Restore health
	if scene_transition_data.has("health") and "health" in player:
		player.health = scene_transition_data.health
	if scene_transition_data.has("max_health") and "max_health" in player:
		player.max_health = scene_transition_data.max_health

	scene_transition_data = {}


func has_scene_transition_data() -> bool:
	return not scene_transition_data.is_empty()
