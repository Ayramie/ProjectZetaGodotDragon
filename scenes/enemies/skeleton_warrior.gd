extends EnemyBase
class_name SkeletonWarrior
## Tanky melee skeleton warrior.
## High HP, moderate damage, slow but powerful attacks.

# Special ability: Shield bash stun
const SHIELD_BASH_COOLDOWN := 8.0
const SHIELD_BASH_DAMAGE := 15
const SHIELD_BASH_STUN := 1.0

var shield_bash_timer: float = 0.0

# Loot table
const LOOT_TABLE := [
	{"item_id": "bone_fragment", "chance": 0.6, "min": 1, "max": 3},
	{"item_id": "iron_ore", "chance": 0.2, "min": 1, "max": 1},
	{"item_id": "gold", "chance": 0.9, "min": 15, "max": 35},
	{"item_id": "health_potion_small", "chance": 0.1, "min": 1, "max": 1},
]

func _ready() -> void:
	# Override stats for warrior
	max_health = 150
	move_speed = 2.5
	attack_damage = 18
	attack_range = 2.2
	attack_cooldown_max = 2.5
	aggro_range = 14.0

	super._ready()

	name = "Skeleton Warrior"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Update shield bash cooldown
	if shield_bash_timer > 0:
		shield_bash_timer -= delta


func _try_attack() -> void:
	if attack_cooldown > 0 or stun_time > 0:
		return

	if not target or not target.is_alive:
		return

	# Try shield bash if available
	if shield_bash_timer <= 0 and randf() < 0.3:
		_shield_bash()
		return

	# Normal attack
	super._try_attack()


func _shield_bash() -> void:
	shield_bash_timer = SHIELD_BASH_COOLDOWN
	attack_cooldown = attack_cooldown_max

	if target and target.has_method("take_damage"):
		target.take_damage(SHIELD_BASH_DAMAGE, self)

		# Stun player
		if target.has_method("apply_stun"):
			target.apply_stun(SHIELD_BASH_STUN)

	# Effects
	AudioManager.play_sound_3d("shield_bash", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("hit", global_position + Vector3.UP, 12)


func _drop_loot() -> void:
	_process_loot_table(LOOT_TABLE)
