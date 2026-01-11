extends EnemyBase
class_name SkeletonBoss
## Powerful skeleton boss enemy.
## High HP, multiple attack patterns, summons minions.

enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }

# Special abilities
const SLAM_COOLDOWN := 8.0
const SLAM_DAMAGE := 40
const SLAM_RADIUS := 5.0

const SUMMON_COOLDOWN := 15.0
const SUMMON_COUNT := 3

const SPIN_COOLDOWN := 12.0
const SPIN_DAMAGE := 25
const SPIN_RADIUS := 4.0

var current_phase: BossPhase = BossPhase.PHASE_1
var slam_timer: float = 0.0
var summon_timer: float = 0.0
var spin_timer: float = 0.0
var is_performing_ability: bool = false

# Loot table (guaranteed good drops)
const LOOT_TABLE := [
	{"item_id": "bone_fragment", "chance": 1.0, "min": 5, "max": 10},
	{"item_id": "gold", "chance": 1.0, "min": 100, "max": 200},
	{"item_id": "health_potion_large", "chance": 0.5, "min": 1, "max": 2},
	{"item_id": "iron_sword", "chance": 0.2, "min": 1, "max": 1},
	{"item_id": "steel_sword", "chance": 0.1, "min": 1, "max": 1},
]

func _ready() -> void:
	# Override stats for boss
	max_health = 500
	move_speed = 2.0
	attack_damage = 30
	attack_range = 3.0
	attack_cooldown_max = 2.0
	aggro_range = 20.0

	super._ready()

	name = "Skeleton Lord"


func _physics_process(delta: float) -> void:
	if is_performing_ability:
		return

	super._physics_process(delta)

	# Update ability timers
	slam_timer = max(0, slam_timer - delta)
	summon_timer = max(0, summon_timer - delta)
	spin_timer = max(0, spin_timer - delta)

	# Update phase based on health
	_update_phase()


func _update_phase() -> void:
	var health_percent := float(health) / float(max_health)

	if health_percent <= 0.3:
		current_phase = BossPhase.PHASE_3
	elif health_percent <= 0.6:
		current_phase = BossPhase.PHASE_2
	else:
		current_phase = BossPhase.PHASE_1


func _try_attack() -> void:
	if attack_cooldown > 0 or stun_time > 0 or is_performing_ability:
		return

	if not target or not target.is_alive:
		return

	var distance := global_position.distance_to(target.global_position)

	# Choose ability based on phase and situation
	match current_phase:
		BossPhase.PHASE_3:
			# Aggressive phase - more abilities
			if spin_timer <= 0 and distance <= SPIN_RADIUS:
				_spin_attack()
				return
			elif summon_timer <= 0:
				_summon_minions()
				return
			elif slam_timer <= 0:
				_ground_slam()
				return
		BossPhase.PHASE_2:
			if summon_timer <= 0 and randf() < 0.3:
				_summon_minions()
				return
			elif slam_timer <= 0 and randf() < 0.4:
				_ground_slam()
				return
		BossPhase.PHASE_1:
			if slam_timer <= 0 and randf() < 0.2:
				_ground_slam()
				return

	# Normal attack
	super._try_attack()


func _ground_slam() -> void:
	slam_timer = SLAM_COOLDOWN
	is_performing_ability = true
	attack_cooldown = attack_cooldown_max * 2

	# Wind up
	AudioManager.play_sound_3d("boss_windup", global_position)

	await get_tree().create_timer(0.5).timeout

	if not is_alive:
		is_performing_ability = false
		return

	# Slam
	AudioManager.play_sound_3d("ground_slam", global_position)
	GameManager.add_screen_shake(0.5)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("hit", global_position, 30)
		spawner.spawn_particles("fire", global_position, 20)

	# Damage nearby players
	if target and target.is_alive:
		var distance := global_position.distance_to(target.global_position)
		if distance <= SLAM_RADIUS:
			target.take_damage(SLAM_DAMAGE, self)

	is_performing_ability = false


func _summon_minions() -> void:
	summon_timer = SUMMON_COOLDOWN
	is_performing_ability = true

	AudioManager.play_sound_3d("boss_summon", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP * 2, 25)

	await get_tree().create_timer(0.8).timeout

	if not is_alive:
		is_performing_ability = false
		return

	# Spawn minions around boss
	var minion_scene_path := "res://scenes/enemies/skeleton_minion.tscn"
	if ResourceLoader.exists(minion_scene_path):
		var minion_scene: PackedScene = load(minion_scene_path)

		for i in SUMMON_COUNT:
			var angle := (TAU / SUMMON_COUNT) * i
			var spawn_offset := Vector3(cos(angle), 0, sin(angle)) * 3.0
			var spawn_pos := global_position + spawn_offset
			spawn_pos = GameManager.clamp_position_to_bounds(spawn_pos)

			var minion := minion_scene.instantiate()
			get_tree().current_scene.add_child(minion)
			minion.global_position = spawn_pos

			if spawner:
				spawner.spawn_particles("magic", spawn_pos + Vector3.UP, 10)

	is_performing_ability = false


func _spin_attack() -> void:
	spin_timer = SPIN_COOLDOWN
	is_performing_ability = true
	attack_cooldown = attack_cooldown_max * 2

	AudioManager.play_sound_3d("whirlwind", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP, 25)

	# Spin animation
	if model:
		var tween := create_tween()
		tween.tween_property(model, "rotation:y", model.rotation.y + TAU * 3, 0.6)

	# Damage in radius
	if target and target.is_alive:
		var distance := global_position.distance_to(target.global_position)
		if distance <= SPIN_RADIUS:
			target.take_damage(SPIN_DAMAGE, self)

	await get_tree().create_timer(0.6).timeout
	is_performing_ability = false


func die(killer: Node3D = null) -> void:
	# Boss death is more dramatic
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("death", global_position + Vector3.UP, 50)
		spawner.spawn_particles("fire", global_position + Vector3.UP, 30)
		spawner.spawn_particles("magic", global_position + Vector3.UP * 2, 25)

	GameManager.add_screen_shake(0.8)
	AudioManager.play_sound_3d("boss_death", global_position)

	# Announce boss defeat
	EventBus.show_message.emit("SKELETON LORD DEFEATED!", Color.GOLD, 4.0)

	super.die(killer)


func _drop_loot() -> void:
	_process_loot_table(LOOT_TABLE)
