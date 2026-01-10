extends CharacterBody3D
class_name Player
## Base player controller class.
## Handles movement, combat, abilities, and player state.

signal health_changed(new_health: int, max_health: int)
signal died()
signal target_changed(new_target: Node3D)

# Movement
@export var move_speed: float = 8.0
@export var jump_force: float = 12.0
@export var gravity: float = 30.0

# Combat stats
@export var max_health: int = 500
@export var attack_range: float = 2.5
@export var attack_cooldown_max: float = 0.8
@export var attack_damage: int = 25

# Current state
var health: int = 500
var is_alive: bool = true
var is_grounded: bool = true
var gold: int = 0

# Movement state
var move_target: Vector3 = Vector3.ZERO
var has_move_target: bool = false
var move_target_threshold: float = 0.5

# Combat state
var target_enemy: Node3D = null
var attack_cooldown: float = 0.0
var is_attacking: bool = false

# Ability cooldowns (overridden by subclasses)
var ability_cooldowns: Dictionary = {
	"q": 0.0,
	"f": 0.0,
	"e": 0.0,
	"r": 0.0,
	"c": 0.0
}

# Buff tracking
var buffs: Dictionary = {}

# References
@onready var model: Node3D = $Model if has_node("Model") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var attack_range_area: Area3D = $AttackRange if has_node("AttackRange") else null

# Animation controller (set in _ready)
var anim_controller: AnimationController = null

# Camera reference (set externally)
var camera: Node3D = null

# Ability indicator manager
var indicator_manager: AbilityIndicatorManager = null


func _ready() -> void:
	# Initialize stats from class definition
	var stats: Dictionary = GameManager.get_class_stats()
	max_health = stats.max_health
	health = max_health
	move_speed = stats.move_speed
	attack_range = stats.attack_range
	attack_cooldown_max = stats.attack_cooldown
	attack_damage = stats.attack_damage

	# Register with game manager
	GameManager.register_player(self)

	# Connect to enemy deaths to clear target
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# Setup animation controller
	anim_controller = get_node_or_null("AnimationController") as AnimationController
	if anim_controller:
		# Find AnimationPlayer (might be in model hierarchy)
		var anim_player := _find_animation_player(self)
		if anim_player:
			anim_controller.setup(anim_player)

	# Setup ability indicator manager
	indicator_manager = AbilityIndicatorManager.new()
	indicator_manager.name = "IndicatorManager"
	add_child(indicator_manager)
	# Camera will be set later by set_camera()


func _exit_tree() -> void:
	GameManager.unregister_player()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Update cooldowns
	_update_cooldowns(delta)
	_update_buffs(delta)

	# Handle movement
	_handle_movement(delta)

	# Handle combat
	_handle_combat(delta)

	# Apply gravity and move
	if not is_on_floor():
		velocity.y -= gravity * delta
		is_grounded = false
	else:
		is_grounded = true
		if velocity.y < 0:
			velocity.y = 0

	move_and_slide()

	# Clamp position to world bounds
	global_position = GameManager.clamp_position_to_bounds(global_position)

	# Update animations based on movement
	_update_animations()

	# Update ability indicators
	if indicator_manager:
		indicator_manager.update_indicator_position(global_position)


func _handle_movement(delta: float) -> void:
	var input_dir := Vector3.ZERO

	# WASD input
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	# If WASD input, cancel click-to-move
	if input_dir != Vector3.ZERO:
		has_move_target = false
		input_dir = input_dir.normalized()

		# Get camera-relative directions
		var forward := Vector3.FORWARD
		var right := Vector3.RIGHT

		if camera and camera.has_method("get_forward_direction"):
			forward = camera.get_forward_direction()
			right = camera.get_right_direction()

		# Calculate movement direction (forward is -Z in input, but we want camera forward)
		var move_dir: Vector3 = (forward * -input_dir.z + right * input_dir.x).normalized()

		# Apply movement
		velocity.x = move_dir.x * move_speed * _get_speed_multiplier()
		velocity.z = move_dir.z * move_speed * _get_speed_multiplier()

		# Rotate model to face movement direction
		if move_dir.length_squared() > 0.01 and model:
			var target_rotation := atan2(move_dir.x, move_dir.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_rotation, 10.0 * delta)

	# Click-to-move
	elif has_move_target:
		var to_target := move_target - global_position
		to_target.y = 0
		var distance := to_target.length()

		if distance > move_target_threshold:
			var move_dir := to_target.normalized()
			velocity.x = move_dir.x * move_speed * _get_speed_multiplier()
			velocity.z = move_dir.z * move_speed * _get_speed_multiplier()

			# Rotate to face movement direction
			if model:
				var target_rotation := atan2(move_dir.x, move_dir.z)
				model.rotation.y = lerp_angle(model.rotation.y, target_rotation, 10.0 * delta)
		else:
			has_move_target = false
			velocity.x = 0
			velocity.z = 0
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0, move_speed * 5 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 5 * delta)

	# Jump
	if Input.is_action_just_pressed("jump") and is_grounded:
		velocity.y = jump_force
		is_grounded = false


func _update_animations() -> void:
	if not anim_controller or is_attacking:
		return

	var dominated_speed := Vector2(velocity.x, velocity.z).length()
	if dominated_speed > 0.5:
		anim_controller.play_run()
	else:
		anim_controller.play_idle()


func _handle_combat(delta: float) -> void:
	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Auto-attack if we have a target
	if target_enemy and is_instance_valid(target_enemy) and target_enemy.is_alive:
		var distance := global_position.distance_to(target_enemy.global_position)
		if distance <= attack_range and attack_cooldown <= 0:
			perform_auto_attack()
	else:
		target_enemy = null


func perform_auto_attack() -> void:
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	attack_cooldown = attack_cooldown_max

	# Face target
	var to_target := target_enemy.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.1:
		model.rotation.y = atan2(to_target.x, to_target.z)

	# Deal damage
	var damage := attack_damage + _get_damage_bonus()
	target_enemy.take_damage(damage, self)

	# Play effects
	AudioManager.play_sound_3d("sword_swing", global_position)

	# Trigger animation
	if anim_controller:
		anim_controller.play_attack_melee()

	is_attacking = true
	await get_tree().create_timer(0.3).timeout
	is_attacking = false


func take_damage(amount: int, source: Node3D = null) -> void:
	if not is_alive:
		return

	# Apply defense buff
	var final_damage := int(amount * _get_defense_multiplier())
	health = max(0, health - final_damage)
	health_changed.emit(health, max_health)

	# Spawn damage number
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_damage_number(global_position + Vector3.UP * 2, final_damage, false, false)
		spawner.spawn_particles("hit", global_position + Vector3.UP, 5)

	# Screen shake
	GameManager.add_screen_shake(0.2)

	# Play hurt sound
	AudioManager.play_sound("player_hurt")

	# Signal damage
	EventBus.player_damaged.emit(final_damage, source)

	if health <= 0:
		die()


func heal(amount: int) -> void:
	if not is_alive:
		return

	var old_health := health
	health = min(max_health, health + amount)
	var healed := health - old_health

	if healed > 0:
		health_changed.emit(health, max_health)
		var spawner := get_node_or_null("/root/EffectSpawner")
		if spawner:
			spawner.spawn_damage_number(global_position + Vector3.UP * 2, healed, false, true)
			spawner.spawn_particles("heal", global_position + Vector3.UP, 8)
		EventBus.player_healed.emit(healed)
		AudioManager.play_sound("heal")


func die() -> void:
	if not is_alive:
		return

	is_alive = false
	velocity = Vector3.ZERO
	died.emit()
	EventBus.player_died.emit()

	# Play death animation
	if anim_controller:
		anim_controller.play_death()


func respawn(spawn_position: Vector3) -> void:
	global_position = spawn_position
	health = max_health
	is_alive = true
	health_changed.emit(health, max_health)


func set_move_target(target: Vector3) -> void:
	move_target = target
	has_move_target = true


func set_target_enemy(enemy: Node3D) -> void:
	target_enemy = enemy
	target_changed.emit(enemy)
	EventBus.target_changed.emit(enemy)


func clear_target() -> void:
	target_enemy = null
	target_changed.emit(null)
	EventBus.target_cleared.emit()


func _update_cooldowns(delta: float) -> void:
	for key in ability_cooldowns:
		if ability_cooldowns[key] > 0:
			ability_cooldowns[key] -= delta


func get_ability_cooldown(ability_key: String) -> float:
	return ability_cooldowns.get(ability_key, 0.0)


func get_ability_cooldown_percent(ability_key: String, max_cooldown: float) -> float:
	var remaining: float = ability_cooldowns.get(ability_key, 0.0)
	return remaining / max_cooldown if max_cooldown > 0 else 0.0


# Buff system
func apply_buff(buff_type: String, multiplier: float, duration: float) -> void:
	buffs[buff_type] = {
		"multiplier": multiplier,
		"remaining": duration
	}
	AudioManager.play_sound("buff_apply")


func _update_buffs(delta: float) -> void:
	var expired: Array[String] = []
	for buff_type in buffs:
		buffs[buff_type].remaining -= delta
		if buffs[buff_type].remaining <= 0:
			expired.append(buff_type)

	for buff_type in expired:
		buffs.erase(buff_type)


func _get_speed_multiplier() -> float:
	if buffs.has("speed"):
		return buffs["speed"].multiplier
	return 1.0


func _get_damage_bonus() -> int:
	# Calculate bonus from equipment
	var bonus := 0
	# Equipment damage would be added here
	return bonus


func _get_defense_multiplier() -> float:
	if buffs.has("defense"):
		return buffs["defense"].multiplier
	return 1.0


func _on_enemy_killed(enemy: Node3D, killer: Node3D) -> void:
	if target_enemy == enemy:
		clear_target()


func _find_animation_player(node: Node) -> AnimationPlayer:
	## Recursively find an AnimationPlayer in a node tree.
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


# Virtual methods for subclasses to override
func use_ability_q() -> void:
	pass


func use_ability_f() -> void:
	pass


func use_ability_e() -> void:
	pass


func use_ability_r() -> void:
	pass


func use_ability_c() -> void:
	pass


func set_camera(cam: Node3D) -> void:
	## Set camera reference for movement and ability aiming.
	camera = cam
	if indicator_manager:
		indicator_manager.setup(cam)
	_setup_indicators()


func _setup_indicators() -> void:
	## Virtual method for subclasses to create their ability indicators.
	pass
