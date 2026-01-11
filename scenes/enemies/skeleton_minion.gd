extends EnemyBase
class_name SkeletonMinion
## Weak, fast skeleton - cannon fodder enemy.
## Low HP, low damage, but quick and numerous.

# Loot table
const LOOT_TABLE := [
	{"item_id": "bone_fragment", "chance": 0.4, "min": 1, "max": 2},
	{"item_id": "gold", "chance": 0.8, "min": 5, "max": 15},
]

func _ready() -> void:
	# Override stats for minion
	max_health = 40
	move_speed = 4.5
	attack_damage = 8
	attack_range = 1.8
	attack_cooldown_max = 1.5
	aggro_range = 10.0

	super._ready()

	# Set display name
	name = "Skeleton Minion"


func _drop_loot() -> void:
	_process_loot_table(LOOT_TABLE)
