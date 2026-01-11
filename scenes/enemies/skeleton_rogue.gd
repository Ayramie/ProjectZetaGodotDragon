extends EnemyBase
class_name SkeletonRogue
## Fast, high-damage skeleton rogue.
## Glass cannon - quick strikes, can dodge, low HP.

# Special abilities
const DASH_COOLDOWN := 6.0
const DASH_DISTANCE := 8.0
const BACKSTAB_MULTIPLIER := 2.0

var dash_timer: float = 0.0
var is_dashing: bool = false

# Loot table
const LOOT_TABLE := [
	{"item_id": "bone_fragment", "chance": 0.5, "min": 1, "max": 2},
	{"item_id": "gold", "chance": 0.95, "min": 25, "max": 50},
	{"item_id": "dagger", "chance": 0.05, "min": 1, "max": 1},
	{"item_id": "speed_potion", "chance": 0.1, "min": 1, "max": 1},
]

func _ready() -> void:
	# Override stats for rogue
	max_health = 50
	move_speed = 6.0  # Very fast
	attack_damage = 22
	attack_range = 2.0
	attack_cooldown_max = 1.0  # Fast attacks
	aggro_range = 14.0

	super._ready()

	name = "Skeleton Rogue"


func _physics_process(delta: float) -> void:
	if is_dashing:
		return

	super._physics_process(delta)

	if dash_timer > 0:
		dash_timer -= delta


func _aggro_behavior(delta: float, distance_to_player: float) -> void:
	# Rogue tries to dash behind player
	if distance_to_player > attack_range * 2 and dash_timer <= 0:
		_dash_to_target()
		return

	super._aggro_behavior(delta, distance_to_player)


func _dash_to_target() -> void:
	if not target or is_dashing:
		return

	dash_timer = DASH_COOLDOWN
	is_dashing = true

	# Calculate position behind player
	var player_facing := Vector3.ZERO
	if target.has_node("Model"):
		var player_model: Node3D = target.get_node("Model")
		player_facing = player_model.global_transform.basis.z.normalized()
	else:
		player_facing = (target.global_position - global_position).normalized()

	# Dash to behind player
	var dash_target := target.global_position + player_facing * 2.0
	dash_target = GameManager.clamp_position_to_bounds(dash_target)

	# Dash effect
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP, 10)

	AudioManager.play_sound_3d("dash", global_position)

	# Tween to position
	var tween := create_tween()
	tween.tween_property(self, "global_position", dash_target, 0.2)
	tween.tween_callback(func():
		is_dashing = false
		if spawner:
			spawner.spawn_particles("magic", global_position + Vector3.UP, 10)
	)


func _try_attack() -> void:
	if attack_cooldown > 0 or stun_time > 0:
		return

	if not target or not target.is_alive:
		return

	attack_cooldown = attack_cooldown_max

	# Check if behind player for backstab
	var to_player := target.global_position - global_position
	to_player.y = 0

	var player_facing := Vector3.ZERO
	if target.has_node("Model"):
		var player_model: Node3D = target.get_node("Model")
		player_facing = player_model.global_transform.basis.z.normalized()

	var dot := to_player.normalized().dot(player_facing)
	var is_backstab := dot > 0.5  # Behind player

	var damage := attack_damage
	if is_backstab:
		damage = int(damage * BACKSTAB_MULTIPLIER)

	target.take_damage(damage, self)

	# Effects
	if is_backstab:
		AudioManager.play_sound_3d("critical_hit", global_position)
		var spawner := get_node_or_null("/root/EffectSpawner")
		if spawner:
			spawner.spawn_particles("hit", target.global_position + Vector3.UP, 15)
	else:
		AudioManager.play_sound_3d("enemy_attack", global_position)

	if anim_controller:
		anim_controller.play_attack_melee()


func take_damage(amount: int, source: Node3D = null) -> void:
	# Chance to dodge
	if randf() < 0.2 and dash_timer <= 0:
		_dodge_attack()
		return

	super.take_damage(amount, source)


func _dodge_attack() -> void:
	dash_timer = DASH_COOLDOWN * 0.5

	# Quick sidestep
	var side_dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var dodge_pos := global_position + side_dir * 3.0
	dodge_pos = GameManager.clamp_position_to_bounds(dodge_pos)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP, 8)

	AudioManager.play_sound_3d("dodge", global_position)

	var tween := create_tween()
	tween.tween_property(self, "global_position", dodge_pos, 0.15)


func _drop_loot() -> void:
	_process_loot_table(LOOT_TABLE)
