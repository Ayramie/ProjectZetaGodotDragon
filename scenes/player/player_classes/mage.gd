extends Player
class_name Mage
## Mage class implementation.
## Ranged magic damage dealer with crowd control abilities.

# Ability definitions
const BLIZZARD_COOLDOWN := 8.0
const BLIZZARD_DAMAGE := 10  # Per tick
const BLIZZARD_RADIUS := 5.0
const BLIZZARD_DURATION := 4.0
const BLIZZARD_SLOW := 0.5

const FLAME_WAVE_COOLDOWN := 6.0
const FLAME_WAVE_DAMAGE := 35
const FLAME_WAVE_RANGE := 8.0
const FLAME_WAVE_ANGLE := deg_to_rad(108.0)

const FROST_NOVA_COOLDOWN := 8.0
const FROST_NOVA_DAMAGE := 25
const FROST_NOVA_RADIUS := 6.0
const FROST_NOVA_FREEZE := 2.5

const FROZEN_ORB_COOLDOWN := 10.0
const FROZEN_ORB_DAMAGE := 15  # Per tick
const FROZEN_ORB_EXPLOSION := 40
const FROZEN_ORB_SPEED := 8.0
const FROZEN_ORB_RANGE := 25.0

const BLINK_COOLDOWN := 5.0
const BLINK_DISTANCE := 6.0

# Mage uses ranged auto-attacks
var auto_attack_projectile_speed := 15.0

# Active zones
var active_blizzards: Array = []


func _ready() -> void:
	super._ready()

	# Override attack range for ranged
	attack_range = 15.0

	ability_cooldowns = {
		"q": 0.0,
		"f": 0.0,
		"e": 0.0,
		"r": 0.0,
		"c": 0.0
	}


func _setup_indicators() -> void:
	if not indicator_manager:
		return

	# Q - Blizzard: Circle indicator at target location
	indicator_manager.create_indicator("q", {
		"type": AbilityIndicator.IndicatorType.CIRCLE,
		"radius": BLIZZARD_RADIUS,
		"color_type": "ice"
	})

	# F - Flame Wave: Cone indicator
	indicator_manager.create_indicator("f", {
		"type": AbilityIndicator.IndicatorType.CONE,
		"radius": FLAME_WAVE_RANGE,
		"angle": 108.0,
		"color_type": "fire"
	})

	# E - Frost Nova: Ring around self
	indicator_manager.create_indicator("e", {
		"type": AbilityIndicator.IndicatorType.RING,
		"radius": FROST_NOVA_RADIUS,
		"color_type": "ice"
	})

	# R - Frozen Orb: Line indicator showing direction
	indicator_manager.create_indicator("r", {
		"type": AbilityIndicator.IndicatorType.LINE,
		"length": FROZEN_ORB_RANGE,
		"width": 1.5,
		"color_type": "ice"
	})


func _input(event: InputEvent) -> void:
	if not is_alive:
		return

	# Abilities with indicators (show on press, use on release)
	if event.is_action_pressed("ability_q"):
		if ability_cooldowns["q"] <= 0 and indicator_manager:
			indicator_manager.show_indicator("q")
	elif event.is_action_released("ability_q"):
		if indicator_manager and indicator_manager.get_aiming_ability() == "q":
			indicator_manager.hide_indicator("q")
			use_ability_q()

	elif event.is_action_pressed("ability_f"):
		if ability_cooldowns["f"] <= 0 and indicator_manager:
			indicator_manager.show_indicator("f")
	elif event.is_action_released("ability_f"):
		if indicator_manager and indicator_manager.get_aiming_ability() == "f":
			indicator_manager.hide_indicator("f")
			use_ability_f()

	elif event.is_action_pressed("ability_e"):
		if ability_cooldowns["e"] <= 0 and indicator_manager:
			indicator_manager.show_indicator("e")
	elif event.is_action_released("ability_e"):
		if indicator_manager and indicator_manager.get_aiming_ability() == "e":
			indicator_manager.hide_indicator("e")
			use_ability_e()

	elif event.is_action_pressed("ability_r"):
		if ability_cooldowns["r"] <= 0 and indicator_manager:
			indicator_manager.show_indicator("r")
	elif event.is_action_released("ability_r"):
		if indicator_manager and indicator_manager.get_aiming_ability() == "r":
			indicator_manager.hide_indicator("r")
			use_ability_r()

	# Instant abilities (no indicator)
	elif event.is_action_pressed("ability_c"):
		use_ability_c()


func perform_auto_attack() -> void:
	## Override to shoot magic projectile instead of melee.
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	attack_cooldown = attack_cooldown_max

	# Face target
	var to_target := target_enemy.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.1:
		model.rotation.y = atan2(to_target.x, to_target.z)

	# Spawn magic bolt projectile
	var direction := to_target.normalized()
	_spawn_magic_bolt(global_position + Vector3.UP, direction, attack_damage + _get_damage_bonus())

	AudioManager.play_sound_3d("spell_cast", global_position)

	is_attacking = true
	await get_tree().create_timer(0.3).timeout
	is_attacking = false


func _spawn_magic_bolt(start_pos: Vector3, direction: Vector3, damage: int) -> void:
	## Spawns a magic bolt projectile.
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "magic_bolt",
			"position": start_pos,
			"direction": direction,
			"speed": auto_attack_projectile_speed,
			"damage": damage,
			"source": self
		})


func use_ability_q() -> void:
	## Blizzard - Ground AoE that slows and damages.
	if ability_cooldowns["q"] > 0:
		return

	ability_cooldowns["q"] = BLIZZARD_COOLDOWN

	# Get target position
	var target_pos := global_position
	if camera:
		target_pos = camera.get_mouse_world_position()

	# Play effects
	AudioManager.play_sound_3d("blizzard", target_pos)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("ice", target_pos, 25)

	# Start blizzard zone
	_start_blizzard(target_pos)


func _start_blizzard(position: Vector3) -> void:
	var blizzard := {
		"position": position,
		"remaining": BLIZZARD_DURATION,
		"tick_timer": 0.0
	}
	active_blizzards.append(blizzard)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Update blizzards
	_update_blizzards(delta)


func _update_blizzards(delta: float) -> void:
	var expired: Array = []

	for blizzard in active_blizzards:
		blizzard.remaining -= delta
		blizzard.tick_timer += delta

		# Tick damage every 0.5 seconds
		if blizzard.tick_timer >= 0.5:
			blizzard.tick_timer = 0.0

			# Spawn ice particles each tick
			var spawner := get_node_or_null("/root/EffectSpawner")
			if spawner:
				spawner.spawn_particles("ice", blizzard.position + Vector3.UP, 8)

			for enemy in GameManager.enemies:
				if not enemy.is_alive:
					continue

				var distance := blizzard.position.distance_to(enemy.global_position)
				if distance <= BLIZZARD_RADIUS:
					enemy.take_damage(BLIZZARD_DAMAGE, self)
					enemy.apply_slow(BLIZZARD_SLOW, 1.0)

		if blizzard.remaining <= 0:
			expired.append(blizzard)

	for blizzard in expired:
		active_blizzards.erase(blizzard)


func use_ability_f() -> void:
	## Flame Wave - Cone fire attack.
	if ability_cooldowns["f"] > 0:
		return

	ability_cooldowns["f"] = FLAME_WAVE_COOLDOWN

	# Get direction
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Find enemies in cone
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0
		var distance := to_enemy.length()

		if distance <= FLAME_WAVE_RANGE:
			var angle := direction.angle_to(to_enemy.normalized())
			if angle <= FLAME_WAVE_ANGLE / 2:
				enemy.take_damage(FLAME_WAVE_DAMAGE, self)

	# Play effects
	AudioManager.play_sound_3d("flame_wave", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + direction * 3 + Vector3.UP, 20)


func use_ability_e() -> void:
	## Frost Nova - AoE freeze around self.
	if ability_cooldowns["e"] > 0:
		return

	ability_cooldowns["e"] = FROST_NOVA_COOLDOWN

	# Freeze all nearby enemies
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= FROST_NOVA_RADIUS:
			enemy.take_damage(FROST_NOVA_DAMAGE, self)
			enemy.apply_stun(FROST_NOVA_FREEZE)

	# Play effects
	AudioManager.play_sound_3d("frost_nova", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("ice", global_position, 30)


func use_ability_r() -> void:
	## Frozen Orb - Traveling projectile that damages in path and explodes.
	if ability_cooldowns["r"] > 0:
		return

	ability_cooldowns["r"] = FROZEN_ORB_COOLDOWN

	# Get direction
	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Spawn frozen orb projectile
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "frozen_orb",
			"position": global_position + Vector3.UP,
			"direction": direction,
			"speed": FROZEN_ORB_SPEED,
			"damage": FROZEN_ORB_DAMAGE,
			"tick_damage": FROZEN_ORB_DAMAGE,
			"explosion_damage": FROZEN_ORB_EXPLOSION,
			"max_range": FROZEN_ORB_RANGE,
			"source": self
		})

	AudioManager.play_sound_3d("spell_cast", global_position)
	# Ability:("frozen_orb", self)


func use_ability_c() -> void:
	## Blink - Short teleport backwards.
	if ability_cooldowns["c"] > 0:
		return

	ability_cooldowns["c"] = BLINK_COOLDOWN

	# Calculate backstep position
	var back_direction := -model.global_transform.basis.z.normalized()
	var target_pos := global_position + back_direction * BLINK_DISTANCE
	target_pos = GameManager.clamp_position_to_bounds(target_pos)

	# Teleport
	global_position = target_pos

	# Play effects
	AudioManager.play_sound_3d("blink", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position, 15)
