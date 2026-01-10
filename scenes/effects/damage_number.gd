extends Node3D
class_name DamageNumber
## Floating damage number that rises and fades.

var damage_amount: int = 0
var is_critical: bool = false
var is_heal: bool = false

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 1.0
var elapsed: float = 0.0

@onready var label: Label3D = $Label3D


func _ready() -> void:
	# Set text and color
	label.text = str(damage_amount)

	if is_heal:
		label.modulate = Color(0.2, 1.0, 0.2)  # Green for heals
	elif is_critical:
		label.modulate = Color(1.0, 0.8, 0.0)  # Yellow/gold for crits
		label.font_size = 48
	else:
		label.modulate = Color(1.0, 1.0, 1.0)  # White for normal

	# Random horizontal velocity
	velocity = Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1))


func _process(delta: float) -> void:
	elapsed += delta

	# Move upward
	global_position += velocity * delta
	velocity.y -= 5.0 * delta  # Gravity

	# Fade out
	var alpha: float = 1.0 - (elapsed / lifetime)
	label.modulate.a = alpha

	# Billboard toward camera
	var cam := get_viewport().get_camera_3d()
	if cam:
		look_at(cam.global_position, Vector3.UP)

	# Remove when done
	if elapsed >= lifetime:
		queue_free()


static func create(parent: Node, pos: Vector3, amount: int, critical: bool = false, heal: bool = false) -> DamageNumber:
	var scene := preload("res://scenes/effects/damage_number.tscn")
	var dmg_instance: DamageNumber = scene.instantiate()
	dmg_instance.damage_amount = amount
	dmg_instance.is_critical = critical
	dmg_instance.is_heal = heal
	parent.add_child(dmg_instance)
	dmg_instance.global_position = pos
	return dmg_instance
