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
	var player := GameManager.player
	if not player or not player.has_node("Inventory"):
		return {}

	var inventory = player.get_node("Inventory")
	return {
		"slots": _serialize_item_array(inventory.slots),
		"equipment": _serialize_equipment(inventory.equipment),
		"hotbar": inventory.hotbar.duplicate(),
		"gold": inventory.gold
	}


func _serialize_item_array(items: Array) -> Array:
	var result := []
	for item in items:
		if item:
			result.append({
				"id": item.definition_id,
				"quantity": item.quantity
			})
		else:
			result.append(null)
	return result


func _serialize_equipment(equipment: Dictionary) -> Dictionary:
	var result := {}
	for slot in equipment:
		if equipment[slot]:
			result[slot] = {
				"id": equipment[slot].definition_id,
				"quantity": equipment[slot].quantity
			}
		else:
			result[slot] = null
	return result


func _get_quest_data() -> Dictionary:
	# Quest data would be gathered from a quest manager
	return {
		"active": [],
		"completed": []
	}


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

	# Player data will be applied after player is spawned
	# Inventory data will be applied after inventory is created
