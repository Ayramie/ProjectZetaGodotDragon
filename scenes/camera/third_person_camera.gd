extends Node3D
class_name ThirdPersonCamera
## Third-person isometric camera with locked pitch and 360° yaw rotation.
## Designed to match the original TileGame3D camera behavior.

signal camera_rotated(yaw: float)

# Camera settings
@export var target: Node3D
@export var distance: float = 30.0
@export var min_distance: float = 10.0
@export var max_distance: float = 60.0
@export var pitch: float = 0.9  # ~51 degrees, locked
@export var target_offset: Vector3 = Vector3(0, 1.5, 0)

# Rotation
var yaw: float = 0.0
var target_yaw: float = 0.0

# Smoothing
@export var position_smoothing: float = 10.0
@export var rotation_smoothing: float = 8.0

# Input
@export var mouse_sensitivity: float = 0.005
@export var scroll_sensitivity: float = 2.0
var is_rotating: bool = false

# Screen shake
var shake_offset: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# Connect to screen shake events
	EventBus.screen_shake.connect(_on_screen_shake)

	# Initialize camera position
	if target:
		_update_camera_position(1.0)


func _input(event: InputEvent) -> void:
	# Right-click to rotate camera
	if event.is_action_pressed("camera_rotate"):
		is_rotating = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("camera_rotate"):
		is_rotating = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Mouse motion for rotation
	if event is InputEventMouseMotion and is_rotating:
		target_yaw -= event.relative.x * mouse_sensitivity

	# Scroll wheel for zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(min_distance, distance - scroll_sensitivity)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(max_distance, distance + scroll_sensitivity)


func _process(delta: float) -> void:
	if not target:
		return

	_update_rotation(delta)
	_update_camera_position(delta)
	_update_screen_shake(delta)


func _update_rotation(delta: float) -> void:
	# Smoothly interpolate yaw
	yaw = lerp_angle(yaw, target_yaw, rotation_smoothing * delta)
	camera_rotated.emit(yaw)


func _update_camera_position(delta: float) -> void:
	# Calculate camera position in spherical coordinates
	var target_pos := target.global_position + target_offset

	# Calculate offset from target based on yaw and pitch
	var offset := Vector3.ZERO
	offset.x = sin(yaw) * cos(pitch) * distance
	offset.y = sin(pitch) * distance
	offset.z = cos(yaw) * cos(pitch) * distance

	# Smooth position
	var desired_pos := target_pos + offset
	camera.global_position = camera.global_position.lerp(desired_pos, position_smoothing * delta)

	# Always look at target
	camera.look_at(target_pos, Vector3.UP)

	# Apply shake
	camera.global_position += shake_offset


func _update_screen_shake(delta: float) -> void:
	var intensity: float = GameManager.screen_shake_intensity
	if intensity > 0.01:
		shake_offset = Vector3(
			randf_range(-1, 1) * intensity,
			randf_range(-1, 1) * intensity * 0.5,
			randf_range(-1, 1) * intensity
		)
	else:
		shake_offset = Vector3.ZERO


func _on_screen_shake(intensity: float) -> void:
	# Intensity is handled in _update_screen_shake via GameManager
	pass


func set_target(new_target: Node3D) -> void:
	target = new_target


func get_forward_direction() -> Vector3:
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	return forward.normalized()


func get_right_direction() -> Vector3:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return right.normalized()


func screen_to_world(screen_pos: Vector2) -> Vector3:
	## Converts screen position to world position on the ground plane (y=0).
	if not camera:
		return Vector3.ZERO

	var from := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)

	# Intersect with ground plane (y = 0)
	if abs(direction.y) < 0.001:
		return Vector3.ZERO

	var t := -from.y / direction.y
	if t < 0:
		return Vector3.ZERO

	return from + direction * t


func get_mouse_world_position() -> Vector3:
	## Gets the world position of the mouse cursor on the ground plane.
	var mouse_pos := get_viewport().get_mouse_position()
	return screen_to_world(mouse_pos)
