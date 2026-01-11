extends EnemyBase
class_name SkeletonMage
## Ranged magic-casting skeleton.
## Low HP, ranged attacks, can cast spells.

# Ranged attack settings
const PROJECTILE_SPEED := 12.0
const PREFERRED_RANGE := 10.0

# Special ability: Dark bolt barrage
const BARRAGE_COOLDOWN := 10.0
const BARRAGE_COUNT := 5
const BARRAGE_DAMAGE := 8

var barrage_timer: float = 0.0

# Loot table
const LOOT_TABLE := [
	{"item_id": "bone_fragment", "chance": 0.5, "min": 1, "max": 2},
	{"item_id": "gold", "chance": 0.9, "min": 20, "max": 40},
	{"item_id": "mana_potion_small", "chance": 0.15, "min": 1, "max": 1},
]

func _ready() -> void:
	# Override stats for mage
	max_health = 60
	move_speed = 3.0
	attack_damage = 12
	attack_range = 12.0  # Ranged
	attack_cooldown_max = 2.0
	aggro_range = 16.0

	super._ready()

	name = "Skeleton Mage"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if barrage_timer > 0:
		barrage_timer -= delta


func _aggro_behavior(delta: float, distance_to_player: float) -> void:
	# Mage tries to keep distance
	if distance_to_player < PREFERRED_RANGE * 0.5:
		# Too close, back away
		_retreat_from_target(delta)
	elif distance_to_player <= attack_range:
		# Good range, attack
		_try_attack()
		velocity.x = 0
		velocity.z = 0
		_face_target(target.global_position)
	else:
		# Move closer but not too close
		var ideal_pos := target.global_position + (global_position - target.global_position).normalized() * PREFERRED_RANGE
		_move_toward_target(ideal_pos, delta)

		if anim_controller:
			anim_controller.play_run()


func _retreat_from_target(delta: float) -> void:
	if not target:
		return

	var away_dir := (global_position - target.global_position).normalized()
	away_dir.y = 0

	velocity.x = away_dir.x * move_speed
	velocity.z = away_dir.z * move_speed

	_face_target(target.global_position)

	if anim_controller:
		anim_controller.play_run()


func _try_attack() -> void:
	if attack_cooldown > 0 or stun_time > 0:
		return

	if not target or not target.is_alive:
		return

	# Try barrage if available
	if barrage_timer <= 0 and randf() < 0.25:
		_cast_barrage()
		return

	# Normal ranged attack
	_shoot_dark_bolt()


func _shoot_dark_bolt() -> void:
	attack_cooldown = attack_cooldown_max

	var direction := (target.global_position - global_position).normalized()
	direction.y = 0

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "magic_bolt",
			"position": global_position + Vector3.UP * 1.5,
			"direction": direction,
			"speed": PROJECTILE_SPEED,
			"damage": attack_damage,
			"source": self
		})
		spawner.spawn_particles("magic", global_position + Vector3.UP * 1.5, 8)

	AudioManager.play_sound_3d("spell_cast", global_position)

	if anim_controller:
		anim_controller.play_attack_melee()


func _cast_barrage() -> void:
	barrage_timer = BARRAGE_COOLDOWN
	attack_cooldown = attack_cooldown_max * 2

	# Shoot multiple bolts in spread
	var base_dir := (target.global_position - global_position).normalized()
	base_dir.y = 0

	var spawner := get_node_or_null("/root/EffectSpawner")

	for i in BARRAGE_COUNT:
		var angle := deg_to_rad(-20 + i * 10)  # Spread from -20 to +20 degrees
		var rotated_dir := Vector3(
			base_dir.x * cos(angle) - base_dir.z * sin(angle),
			0,
			base_dir.x * sin(angle) + base_dir.z * cos(angle)
		)

		if spawner:
			spawner.spawn_projectile({
				"type": "magic_bolt",
				"position": global_position + Vector3.UP * 1.5,
				"direction": rotated_dir,
				"speed": PROJECTILE_SPEED * 0.8,
				"damage": BARRAGE_DAMAGE,
				"source": self
			})

	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP * 1.5, 15)

	AudioManager.play_sound_3d("spell_cast", global_position)


func _drop_loot() -> void:
	_process_loot_table(LOOT_TABLE)
