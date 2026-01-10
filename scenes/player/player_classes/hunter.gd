extends Player
class_name Hunter
## Hunter class implementation.
## Fast ranged damage dealer with traps and mobility.

# Ability definitions
const ARROW_WAVE_COOLDOWN := 6.0
const ARROW_WAVE_DAMAGE := 20
const ARROW_WAVE_COUNT := 8
const ARROW_WAVE_SPREAD := deg_to_rad(90.0)

const SPIN_DASH_COOLDOWN := 8.0
const SPIN_DASH_DAMAGE := 25
const SPIN_DASH_DISTANCE := 10.0
const SPIN_DASH_ARROWS := 12

const SHOTGUN_COOLDOWN := 5.0
const SHOTGUN_DAMAGE := 40
const SHOTGUN_COUNT := 6
const SHOTGUN_SPREAD := deg_to_rad(72.0)

const TRAP_COOLDOWN := 12.0
const TRAP_DAMAGE := 60
const TRAP_ARM_TIME := 1.0
const TRAP_RADIUS := 3.0

const GIANT_ARROW_COOLDOWN := 10.0
const GIANT_ARROW_DAMAGE := 50
const GIANT_ARROW_SPEED := 20.0

# Hunter uses ranged auto-attacks
var auto_attack_projectile_speed := 18.0

# Active traps
var active_traps: Array = []

# Spin dash state
var is_spin_dashing: bool = false


func _ready() -> void:
	super._ready()

	# Override attack range for ranged
	attack_range = 18.0

	ability_cooldowns = {
		"q": 0.0,
		"f": 0.0,
		"e": 0.0,
		"r": 0.0,
		"c": 0.0
	}


func _input(event: InputEvent) -> void:
	if not is_alive:
		return

	if event.is_action_pressed("ability_q"):
		use_ability_q()
	elif event.is_action_pressed("ability_f"):
		use_ability_f()
	elif event.is_action_pressed("ability_e"):
		use_ability_e()
	elif event.is_action_pressed("ability_r"):
		use_ability_r()
	elif event.is_action_pressed("ability_c"):
		use_ability_c()


func perform_auto_attack() -> void:
	## Override to shoot arrow instead of melee.
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	attack_cooldown = attack_cooldown_max

	# Face target
	var to_target := target_enemy.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.1:
		model.rotation.y = atan2(to_target.x, to_target.z)

	# Spawn arrow projectile
	var direction := to_target.normalized()
	_spawn_arrow(global_position + Vector3.UP, direction, attack_damage + _get_damage_bonus())

	AudioManager.play_sound_3d("bow_shoot", global_position)

	is_attacking = true
	await get_tree().create_timer(0.2).timeout
	is_attacking = false


func _spawn_arrow(start_pos: Vector3, direction: Vector3, damage: int, is_giant: bool = false) -> void:
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "giant_arrow" if is_giant else "arrow",
			"position": start_pos,
			"direction": direction,
			"speed": auto_attack_projectile_speed if not is_giant else GIANT_ARROW_SPEED,
			"damage": damage,
			"piercing": is_giant,
			"source": self
		})


func use_ability_q() -> void:
	## Arrow Wave - Fan of arrows.
	if ability_cooldowns["q"] > 0:
		return

	ability_cooldowns["q"] = ARROW_WAVE_COOLDOWN

	# Get center direction
	var center_direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			center_direction = to_mouse.normalized()
			model.rotation.y = atan2(center_direction.x, center_direction.z)

	# Spawn arrows in a fan pattern
	var angle_step := ARROW_WAVE_SPREAD / (ARROW_WAVE_COUNT - 1)
	var start_angle := -ARROW_WAVE_SPREAD / 2

	for i in ARROW_WAVE_COUNT:
		var angle := start_angle + angle_step * i
		var rotated_dir := Vector3(
			center_direction.x * cos(angle) - center_direction.z * sin(angle),
			0,
			center_direction.x * sin(angle) + center_direction.z * cos(angle)
		)
		_spawn_arrow(global_position + Vector3.UP, rotated_dir, ARROW_WAVE_DAMAGE)

	AudioManager.play_sound_3d("arrow_wave", global_position)
	# Ability:("arrow_wave", self)


func use_ability_f() -> void:
	## Spin Dash - Dash forward while shooting arrows in all directions.
	if ability_cooldowns["f"] > 0 or is_spin_dashing:
		return

	ability_cooldowns["f"] = SPIN_DASH_COOLDOWN
	is_spin_dashing = true

	# Get dash direction
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Shoot arrows in circle
	var angle_step := TAU / SPIN_DASH_ARROWS
	for i in SPIN_DASH_ARROWS:
		var angle := angle_step * i
		var arrow_dir := Vector3(cos(angle), 0, sin(angle))
		_spawn_arrow(global_position + Vector3.UP, arrow_dir, SPIN_DASH_DAMAGE)

	# Dash
	var dash_target := global_position + direction * SPIN_DASH_DISTANCE
	dash_target = GameManager.clamp_position_to_bounds(dash_target)

	var tween := create_tween()
	tween.tween_property(self, "global_position", dash_target, 0.3)
	tween.parallel().tween_property(model, "rotation:y", model.rotation.y + TAU * 2, 0.3)
	tween.tween_callback(func(): is_spin_dashing = false)

	AudioManager.play_sound_3d("arrow_wave", global_position)
	# Ability:("spin_dash", self)


func use_ability_e() -> void:
	## Shotgun - Close range spread of arrows.
	if ability_cooldowns["e"] > 0:
		return

	ability_cooldowns["e"] = SHOTGUN_COOLDOWN

	# Get direction
	var center_direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			center_direction = to_mouse.normalized()
			model.rotation.y = atan2(center_direction.x, center_direction.z)

	# Spawn arrows in tight spread
	var angle_step := SHOTGUN_SPREAD / (SHOTGUN_COUNT - 1)
	var start_angle := -SHOTGUN_SPREAD / 2

	for i in SHOTGUN_COUNT:
		var angle := start_angle + angle_step * i
		var rotated_dir := Vector3(
			center_direction.x * cos(angle) - center_direction.z * sin(angle),
			0,
			center_direction.x * sin(angle) + center_direction.z * cos(angle)
		)
		_spawn_arrow(global_position + Vector3.UP, rotated_dir, SHOTGUN_DAMAGE)

	AudioManager.play_sound_3d("bow_shoot", global_position)
	# Ability:("shotgun", self)


func use_ability_r() -> void:
	## Trap - Place a trap that damages and stuns enemies.
	if ability_cooldowns["r"] > 0:
		return

	ability_cooldowns["r"] = TRAP_COOLDOWN

	# Place trap at target position
	var trap_pos := global_position
	if camera:
		trap_pos = camera.get_mouse_world_position()

	var trap := {
		"position": trap_pos,
		"arm_timer": TRAP_ARM_TIME,
		"is_armed": false
	}
	active_traps.append(trap)

	AudioManager.play_sound_3d("trap_place", trap_pos)
	# Effect:("trap", trap_pos, 0.0)
	# Ability:("trap", self)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Update traps
	_update_traps(delta)


func _update_traps(delta: float) -> void:
	var triggered: Array = []

	for trap in active_traps:
		if not trap.is_armed:
			trap.arm_timer -= delta
			if trap.arm_timer <= 0:
				trap.is_armed = true
			continue

		# Check for enemies
		for enemy in GameManager.enemies:
			if not enemy.is_alive:
				continue

			var distance := trap.position.distance_to(enemy.global_position)
			if distance <= TRAP_RADIUS:
				# Trigger trap
				_trigger_trap(trap)
				triggered.append(trap)
				break

	for trap in triggered:
		active_traps.erase(trap)


func _trigger_trap(trap: Dictionary) -> void:
	# Damage all enemies in radius
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var distance := trap.position.distance_to(enemy.global_position)
		if distance <= TRAP_RADIUS:
			enemy.take_damage(TRAP_DAMAGE, self)
			enemy.apply_stun(1.5)

	AudioManager.play_sound_3d("trap_trigger", trap.position)
	# Effect:("trap_explode", trap.position, 0.0)


func use_ability_c() -> void:
	## Giant Arrow - Piercing projectile.
	if ability_cooldowns["c"] > 0:
		return

	ability_cooldowns["c"] = GIANT_ARROW_COOLDOWN

	# Get direction
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Spawn giant arrow
	_spawn_arrow(global_position + Vector3.UP, direction, GIANT_ARROW_DAMAGE, true)

	AudioManager.play_sound_3d("bow_shoot", global_position)
	# Ability:("giant_arrow", self)
