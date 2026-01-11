extends CharacterBody3D
class_name EnemyBase
## Base enemy class with AI, pathfinding, and combat.

signal health_changed(new_health: int, max_health: int)
signal died(killer: Node3D)

# Stats
@export var max_health: int = 100
@export var move_speed: float = 3.0
@export var attack_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown_max: float = 2.0
@export var aggro_range: float = 12.0

# Current state
var health: int = 100
var is_alive: bool = true
var is_aggro: bool = false
var attack_cooldown: float = 0.0
var stun_time: float = 0.0
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0

# Movement
var target_position: Vector3 = Vector3.ZERO
const GRAVITY: float = 30.0

# References
@onready var model: Node3D = $Model if has_node("Model") else null
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
var health_bar: HealthBar3D = null
@onready var aggro_area: Area3D = $AggroRange if has_node("AggroRange") else null

# Animation controller
var anim_controller: AnimationController = null

# Target (player)
var target: Node3D = null


func _ready() -> void:
	health = max_health

	# Add to enemies group for projectile collision detection
	add_to_group("enemies")

	# Register with game manager
	GameManager.register_enemy(self)

	# Setup navigation
	if navigation_agent:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = attack_range * 0.9

	# Setup aggro area
	if aggro_area:
		aggro_area.body_entered.connect(_on_aggro_body_entered)

	# Find and setup health bar (use get_node_or_null for dynamic script attachment)
	health_bar = get_node_or_null("HealthBar3D") as HealthBar3D
	if health_bar:
		health_bar.max_value = max_health
		health_bar.set_value(health)

	# Setup animation controller
	anim_controller = get_node_or_null("AnimationController") as AnimationController
	if anim_controller and model:
		# Use the new setup_for_model that handles AnimationPlayer creation
		anim_controller.setup_for_model(model)


func _exit_tree() -> void:
	GameManager.unregister_enemy(self)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Update stun
	if stun_time > 0:
		stun_time -= delta
		return

	# Update slow
	if slow_duration > 0:
		slow_duration -= delta
		if slow_duration <= 0:
			slow_multiplier = 1.0

	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Get player reference
	if not target:
		target = GameManager.player

	if not target or not target.is_alive:
		_idle_behavior(delta)
		return

	# Check aggro range
	var distance_to_player := global_position.distance_to(target.global_position)
	if distance_to_player <= aggro_range:
		is_aggro = true

	if is_aggro:
		_aggro_behavior(delta, distance_to_player)

	# Update health bar to face camera
	_update_health_bar()

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	move_and_slide()


func _idle_behavior(delta: float) -> void:
	# Just stand still or wander
	velocity.x = move_toward(velocity.x, 0, move_speed * delta)
	velocity.z = move_toward(velocity.z, 0, move_speed * delta)

	# Play idle animation
	if anim_controller:
		anim_controller.play_idle()


func _aggro_behavior(delta: float, distance_to_player: float) -> void:
	if distance_to_player <= attack_range:
		# In attack range - try to attack
		_try_attack()
		velocity.x = 0
		velocity.z = 0

		# Face player
		_face_target(target.global_position)
	else:
		# Move toward player
		_move_toward_target(target.global_position, delta)

		# Play run animation while moving
		if anim_controller:
			anim_controller.play_run()


func _move_toward_target(target_pos: Vector3, delta: float) -> void:
	if navigation_agent:
		navigation_agent.target_position = target_pos

		if not navigation_agent.is_navigation_finished():
			var next_pos := navigation_agent.get_next_path_position()
			var direction := (next_pos - global_position).normalized()
			direction.y = 0

			var current_speed := move_speed * slow_multiplier
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed

			# Face movement direction
			_face_target(next_pos)
	else:
		# Simple direct movement
		var direction := (target_pos - global_position).normalized()
		direction.y = 0

		var current_speed := move_speed * slow_multiplier
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		_face_target(target_pos)


func _face_target(target_pos: Vector3) -> void:
	if model:
		var to_target := target_pos - global_position
		to_target.y = 0
		if to_target.length() > 0.1:
			model.rotation.y = atan2(to_target.x, to_target.z)


func _try_attack() -> void:
	if attack_cooldown > 0 or stun_time > 0:
		return

	if not target or not target.is_alive:
		return

	attack_cooldown = attack_cooldown_max

	# Deal damage
	target.take_damage(attack_damage, self)

	# Play attack animation/sound
	if anim_controller:
		anim_controller.play_attack_melee()
	AudioManager.play_sound_3d("enemy_attack", global_position)


func take_damage(amount: int, source: Node3D = null) -> void:
	if not is_alive:
		return

	health = max(0, health - amount)
	health_changed.emit(health, max_health)

	# Update health bar
	if health_bar and health_bar is HealthBar3D:
		health_bar.set_value(health)

	# Aggro on damage
	is_aggro = true
	if source:
		target = source

	# Visual feedback
	_flash_damage()
	if anim_controller:
		anim_controller.play_hit()

	# Spawn damage number
	var is_crit := amount > 30
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_damage_number(global_position + Vector3.UP * 2, amount, is_crit, false)
		spawner.spawn_particles("hit", global_position + Vector3.UP, 5)

	# Notify
	EventBus.enemy_damaged.emit(self, amount, source)

	if health <= 0:
		die(source)


func _flash_damage() -> void:
	# Flash red briefly
	if model:
		# This would set a shader parameter or modulate
		# For now, just a placeholder
		pass


func die(killer: Node3D = null) -> void:
	if not is_alive:
		return

	is_alive = false
	velocity = Vector3.ZERO

	died.emit(killer)
	EventBus.enemy_killed.emit(self, killer)

	# Play death animation
	if anim_controller:
		anim_controller.play_death()

	# Play death effects
	AudioManager.play_sound_3d("enemy_death", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("death", global_position + Vector3.UP, 20)

	# Drop loot
	_drop_loot()

	# Queue respawn
	var respawn_data := {
		"type": get_class(),
		"position": global_position
	}
	GameManager.queue_enemy_respawn(respawn_data, 10.0)

	# Wait for death animation then remove
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _drop_loot() -> void:
	## Override in subclasses for specific loot tables.
	## Base implementation drops common loot.
	var loot_table := [
		{"item_id": "bone_fragment", "chance": 0.2, "min": 1, "max": 1},
		{"item_id": "gold", "chance": 0.5, "min": 3, "max": 10},
	]
	_process_loot_table(loot_table)


func _process_loot_table(loot_table: Array) -> void:
	## Processes a loot table and drops items based on chance.
	for entry in loot_table:
		if randf() <= entry.chance:
			var amount := randi_range(entry.min, entry.max)
			if entry.item_id == "gold":
				_give_gold(amount)
			else:
				_give_item(entry.item_id, amount)


func _give_gold(amount: int) -> void:
	## Adds gold to player inventory and shows floating text.
	if GameManager.inventory:
		GameManager.inventory.add_gold(amount)

		# Show floating gold number
		var spawner := get_node_or_null("/root/EffectSpawner")
		if spawner:
			spawner.spawn_damage_number(global_position + Vector3.UP * 1.5, amount, false, false)

		EventBus.show_message.emit("+" + str(amount) + " Gold", Color(1.0, 0.85, 0.3), 2.0)


func _give_item(item_id: String, amount: int) -> void:
	## Adds item to player inventory and shows notification.
	if GameManager.inventory:
		var overflow: int = GameManager.inventory.add_item(item_id, amount)
		var added: int = amount - overflow

		if added > 0:
			# Get item name for display
			var item_def: Dictionary = ItemDatabase.get_item(item_id)
			var item_name: String = item_def.get("name", item_id.replace("_", " ").capitalize())

			EventBus.show_message.emit("+" + str(added) + " " + item_name, Color.WHITE, 2.0)
			EventBus.item_picked_up.emit(item_id, added)


func apply_stun(duration: float) -> void:
	stun_time = max(stun_time, duration)
	velocity = Vector3.ZERO


func apply_slow(multiplier: float, duration: float) -> void:
	slow_multiplier = multiplier
	slow_duration = duration


func _update_health_bar() -> void:
	# Billboard mode is handled by the HealthBar3D material
	# No manual look_at needed
	pass


func _on_aggro_body_entered(body: Node3D) -> void:
	if body is Player:
		is_aggro = true
		target = body
