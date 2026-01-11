extends StaticBody3D
class_name InteractableBase
## Base class for all interactable objects in the world.
## Handles proximity detection, interaction prompts, and player validation.

signal interaction_started()
signal interaction_ended()

@export var interaction_range: float = 2.5
@export var prompt_text: String = "Press F to interact"
@export var prompt_offset: Vector3 = Vector3(0, 2.5, 0)

var player: Player = null
var is_player_nearby: bool = false
var is_active: bool = false
var hud: HUD = null

# Area3D for detection
var detection_area: Area3D = null


func _ready() -> void:
	_setup_collision()
	_setup_detection_area()

	# Find HUD reference
	await get_tree().process_frame
	hud = get_node_or_null("/root/Main/UI/HUD")


func _setup_collision() -> void:
	# Add collision shape so player can't walk through
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.5, 1.0)
	collision.shape = box
	collision.position.y = 0.75
	add_child(collision)


func _setup_detection_area() -> void:
	detection_area = Area3D.new()
	detection_area.name = "DetectionArea"

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_range
	collision.shape = sphere

	detection_area.add_child(collision)
	add_child(detection_area)

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player = body
		is_player_nearby = true
		_show_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_nearby = false
		player = null
		_hide_prompt()

		# Cancel interaction if player leaves while active
		if is_active:
			_cancel_interaction()


func _input(event: InputEvent) -> void:
	if not is_player_nearby or is_active:
		return

	if event.is_action_pressed("interact"):
		_start_interaction()


func _show_prompt() -> void:
	if hud and hud.has_method("show_interaction_prompt"):
		hud.show_interaction_prompt(prompt_text)


func _hide_prompt() -> void:
	if hud and hud.has_method("hide_interaction_prompt"):
		hud.hide_interaction_prompt()


func _start_interaction() -> void:
	## Override in subclass to implement specific behavior.
	is_active = true
	_hide_prompt()
	interaction_started.emit()


func _end_interaction() -> void:
	## Call when interaction completes normally.
	is_active = false
	if is_player_nearby:
		_show_prompt()
	interaction_ended.emit()


func _cancel_interaction() -> void:
	## Called when player leaves range during interaction.
	is_active = false
	interaction_ended.emit()


func get_player() -> Player:
	return player


func is_player_in_range() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= interaction_range
