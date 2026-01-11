extends Interactable
class_name Door
## Door that can be opened/closed, optionally locked.

@export var is_locked: bool = false
@export var required_key: String = ""
@export var auto_close: bool = false
@export var auto_close_delay: float = 3.0
@export var destination_scene: String = ""  # For scene transitions
@export var destination_spawn: String = ""  # Spawn point name in destination

var is_open: bool = false
var auto_close_timer: float = 0.0

@onready var door_model: Node3D = $Model/Door if has_node("Model/Door") else null
@onready var door_collider: StaticBody3D = $DoorCollider if has_node("DoorCollider") else null


func _ready() -> void:
	one_time_use = false
	interaction_text = _get_interaction_text()
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)

	# Auto close timer
	if auto_close and is_open and auto_close_timer > 0:
		auto_close_timer -= delta
		if auto_close_timer <= 0:
			close()


func _get_interaction_text() -> String:
	if is_locked:
		return "Locked - Requires " + required_key.replace("_", " ")
	elif is_open:
		return "Press F to close"
	else:
		return "Press F to open"


func interact(player: Node3D) -> void:
	# Check if locked
	if is_locked:
		if not _try_unlock(player):
			EventBus.show_message.emit("This door is locked!", Color.RED, 2.0)
			AudioManager.play_sound_3d("locked", global_position)
			return

	# Toggle door state
	if is_open:
		close()
	else:
		open()

	interacted.emit(player)


func _try_unlock(player: Node3D) -> bool:
	if required_key.is_empty():
		return false

	# Check if player has key in inventory
	if GameManager.inventory and GameManager.inventory.has_item(required_key):
		GameManager.inventory.remove_item_by_id(required_key, 1)
		EventBus.show_message.emit("Used " + required_key.replace("_", " "), Color.YELLOW, 2.0)
		is_locked = false
		interaction_text = _get_interaction_text()
		return true

	return false


func open() -> void:
	if is_open:
		return

	is_open = true
	interaction_text = _get_interaction_text()

	# Check for scene transition
	if not destination_scene.is_empty():
		_transition_to_scene()
		return

	# Play open animation
	_animate_open()

	# Disable collision
	if door_collider:
		door_collider.set_collision_layer_value(1, false)

	AudioManager.play_sound_3d("door_open", global_position)

	# Start auto close timer
	if auto_close:
		auto_close_timer = auto_close_delay


func close() -> void:
	if not is_open:
		return

	is_open = false
	interaction_text = _get_interaction_text()

	# Play close animation
	_animate_close()

	# Enable collision
	if door_collider:
		door_collider.set_collision_layer_value(1, true)

	AudioManager.play_sound_3d("door_close", global_position)


func _animate_open() -> void:
	if door_model:
		var tween := create_tween()
		tween.tween_property(door_model, "rotation_degrees:y", 90, 0.3)


func _animate_close() -> void:
	if door_model:
		var tween := create_tween()
		tween.tween_property(door_model, "rotation_degrees:y", 0, 0.3)


func _transition_to_scene() -> void:
	# Save spawn point for destination
	if not destination_spawn.is_empty():
		SaveManager.set_spawn_point(destination_spawn)

	# Transition to new scene
	get_tree().change_scene_to_file(destination_scene)


func lock(key_id: String = "") -> void:
	is_locked = true
	required_key = key_id
	interaction_text = _get_interaction_text()


func unlock() -> void:
	is_locked = false
	required_key = ""
	interaction_text = _get_interaction_text()
