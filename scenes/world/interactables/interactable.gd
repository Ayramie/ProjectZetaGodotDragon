extends Area3D
class_name Interactable
## Base class for all interactable objects in the world.
## Handles player proximity detection and interaction prompts.

signal interacted(player: Node3D)
signal interaction_available(is_available: bool)

@export var interaction_text: String = "Press F to interact"
@export var interaction_range: float = 2.5
@export var one_time_use: bool = false
@export var interaction_cooldown: float = 0.5

var can_interact: bool = true
var is_player_nearby: bool = false
var cooldown_timer: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null


func _ready() -> void:
	# Setup collision for player detection
	collision_layer = 0
	collision_mask = 2  # Player layer

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create collision shape if not present
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = interaction_range
		collision_shape.shape = sphere
		add_child(collision_shape)


func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_interact = true


func _input(event: InputEvent) -> void:
	if not is_player_nearby or not can_interact:
		return

	if event.is_action_pressed("interact"):
		_do_interact()


func _do_interact() -> void:
	if not can_interact:
		return

	var player := GameManager.player
	if not player:
		return

	# Verify player is still in range
	var distance := global_position.distance_to(player.global_position)
	if distance > interaction_range * 1.5:
		return

	# Trigger interaction
	interact(player)

	# Handle cooldown/one-time use
	if one_time_use:
		can_interact = false
		interaction_available.emit(false)
	else:
		can_interact = false
		cooldown_timer = interaction_cooldown


func interact(player: Node3D) -> void:
	## Override in subclasses to implement specific interaction behavior.
	interacted.emit(player)
	AudioManager.play_sound_3d("interact", global_position)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		is_player_nearby = true
		if can_interact:
			interaction_available.emit(true)
			EventBus.show_message.emit(interaction_text, Color.WHITE, 0.0)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_nearby = false
		interaction_available.emit(false)


func set_interactable(value: bool) -> void:
	can_interact = value
	if is_player_nearby:
		interaction_available.emit(value)
