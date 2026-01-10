extends Player
class_name Warrior
## Warrior class implementation.
## Melee-focused with strong AoE and defensive abilities.

# Ability definitions
const CLEAVE_COOLDOWN := 4.0
const CLEAVE_DAMAGE := 45
const CLEAVE_RANGE := 8.0
const CLEAVE_ANGLE := deg_to_rad(108.0)  # 108 degrees

const WHIRLWIND_COOLDOWN := 6.0
const WHIRLWIND_DAMAGE := 35
const WHIRLWIND_RADIUS := 3.5
const WHIRLWIND_DASH_DISTANCE := 10.0
const WHIRLWIND_DURATION := 0.5

const PARRY_COOLDOWN := 5.0
const PARRY_DAMAGE := 50
const PARRY_RADIUS := 4.0
const PARRY_DURATION := 0.4

const HEROIC_LEAP_COOLDOWN := 10.0
const HEROIC_LEAP_DAMAGE := 50
const HEROIC_LEAP_RANGE := 20.0
const HEROIC_LEAP_RADIUS := 4.0
const HEROIC_LEAP_STUN := 0.8
const HEROIC_LEAP_DURATION := 0.5

const SUNDER_COOLDOWN := 5.0
const SUNDER_DAMAGE := 40
const SUNDER_RANGE := 16.0

# Ability state
var is_whirlwinding: bool = false
var is_parrying: bool = false
var is_leaping: bool = false
var leap_start_pos: Vector3 = Vector3.ZERO
var leap_target_pos: Vector3 = Vector3.ZERO
var leap_time: float = 0.0


func _ready() -> void:
	super._ready()

	# Set ability cooldowns
	ability_cooldowns = {
		"q": 0.0,
		"f": 0.0,
		"e": 0.0,
		"r": 0.0,
		"c": 0.0
	}


func _physics_process(delta: float) -> void:
	# Handle heroic leap movement
	if is_leaping:
		_update_heroic_leap(delta)
		return

	super._physics_process(delta)


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


func use_ability_q() -> void:
	## Cleave - Cone AoE attack
	if ability_cooldowns["q"] > 0:
		return

	ability_cooldowns["q"] = CLEAVE_COOLDOWN

	# Get direction based on mouse position or facing
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Find enemies in cone
	var enemies_hit: Array[Node3D] = []
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0
		var distance := to_enemy.length()

		if distance <= CLEAVE_RANGE:
			var angle := direction.angle_to(to_enemy.normalized())
			if angle <= CLEAVE_ANGLE / 2:
				enemies_hit.append(enemy)

	# Deal damage
	for enemy in enemies_hit:
		enemy.take_damage(CLEAVE_DAMAGE, self)

	# Play effects
	AudioManager.play_sound_3d("cleave", global_position)
	# Effect:("cleave", global_position + Vector3.UP * 0.5, model.rotation.y)
	# Ability:("cleave", self)


func use_ability_f() -> void:
	## Whirlwind - Spin attack with dash
	if ability_cooldowns["f"] > 0 or is_whirlwinding:
		return

	ability_cooldowns["f"] = WHIRLWIND_COOLDOWN
	is_whirlwinding = true

	# Get dash direction
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()

	# Hit all enemies in radius immediately
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= WHIRLWIND_RADIUS:
			enemy.take_damage(WHIRLWIND_DAMAGE, self)

	# Dash forward
	var dash_target := global_position + direction * WHIRLWIND_DASH_DISTANCE
	dash_target = GameManager.clamp_position_to_bounds(dash_target)

	# Play effects
	AudioManager.play_sound_3d("whirlwind", global_position)
	# Effect:("whirlwind", global_position + Vector3.UP, model.rotation.y)
	# Ability:("whirlwind", self)

	# Animate dash
	var tween := create_tween()
	tween.tween_property(self, "global_position", dash_target, WHIRLWIND_DURATION)
	tween.tween_callback(func(): is_whirlwinding = false)


func use_ability_e() -> void:
	## Parry - Defensive spin with counter damage
	if ability_cooldowns["e"] > 0 or is_parrying:
		return

	ability_cooldowns["e"] = PARRY_COOLDOWN
	is_parrying = true

	# Play effects
	AudioManager.play_sound_3d("parry", global_position)
	# Effect:("parry", global_position + Vector3.UP, 0.0)
	# Ability:("parry", self)

	# Spin animation
	var spin_tween := create_tween()
	spin_tween.tween_property(model, "rotation:y", model.rotation.y + TAU * 2, PARRY_DURATION)

	# After parry ends, deal counter damage
	await get_tree().create_timer(PARRY_DURATION).timeout
	is_parrying = false

	# Damage nearby enemies
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= PARRY_RADIUS:
			enemy.take_damage(PARRY_DAMAGE, self)


func use_ability_r() -> void:
	## Heroic Leap - Jump to target location with AoE damage
	if ability_cooldowns["r"] > 0 or is_leaping:
		return

	# Get target position
	var target_pos := global_position
	if camera:
		target_pos = camera.get_mouse_world_position()

	var to_target := target_pos - global_position
	to_target.y = 0
	var distance := to_target.length()

	# Clamp to max range
	if distance > HEROIC_LEAP_RANGE:
		target_pos = global_position + to_target.normalized() * HEROIC_LEAP_RANGE

	target_pos = GameManager.clamp_position_to_bounds(target_pos)

	ability_cooldowns["r"] = HEROIC_LEAP_COOLDOWN
	is_leaping = true
	leap_start_pos = global_position
	leap_target_pos = target_pos
	leap_time = 0.0

	# Face target
	if to_target.length() > 0.5:
		model.rotation.y = atan2(to_target.x, to_target.z)

	# Play effects
	AudioManager.play_sound_3d("heroic_leap", global_position)
	# Effect:("leap_trail", global_position + Vector3.UP, 0.0)
	# Ability:("heroic_leap", self)


func _update_heroic_leap(delta: float) -> void:
	leap_time += delta
	var t := leap_time / HEROIC_LEAP_DURATION

	if t >= 1.0:
		# Land
		global_position = leap_target_pos
		is_leaping = false

		# AoE damage on landing
		for enemy in GameManager.enemies:
			if not enemy.is_alive:
				continue

			var distance := global_position.distance_to(enemy.global_position)
			if distance <= HEROIC_LEAP_RADIUS:
				enemy.take_damage(HEROIC_LEAP_DAMAGE, self)
				enemy.apply_stun(HEROIC_LEAP_STUN)

		# Ground slam effect
		# Effect:("ground_slam", global_position, 0.0)
		GameManager.add_screen_shake(0.4)
	else:
		# Arc movement
		var horizontal := leap_start_pos.lerp(leap_target_pos, t)
		var arc_height := sin(t * PI) * 5.0  # Arc up to 5 units
		global_position = Vector3(horizontal.x, leap_start_pos.y + arc_height, horizontal.z)


func use_ability_c() -> void:
	## Sunder - Ground spike wave
	if ability_cooldowns["c"] > 0:
		return

	ability_cooldowns["c"] = SUNDER_COOLDOWN

	# Get direction
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Play effects
	AudioManager.play_sound_3d("sunder", global_position)
	# Effect:("sunder", global_position, model.rotation.y)
	# Ability:("sunder", self)

	# Damage enemies in line
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0
		var distance := to_enemy.length()

		if distance <= SUNDER_RANGE:
			# Check if enemy is in the line (narrow cone)
			var angle := direction.angle_to(to_enemy.normalized())
			if angle <= deg_to_rad(20.0):  # 40 degree total width
				enemy.take_damage(SUNDER_DAMAGE, self)


func take_damage(amount: int, source: Node3D = null) -> void:
	# Parry blocks damage
	if is_parrying:
		# Riposte effect
		# Effect:("riposte", global_position + Vector3.UP, 0.0)
		return

	super.take_damage(amount, source)
