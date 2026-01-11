extends Interactable
class_name TreasureChest
## Treasure chest that drops loot when opened.

enum ChestRarity { COMMON, UNCOMMON, RARE, EPIC }

@export var chest_rarity: ChestRarity = ChestRarity.COMMON
@export var is_locked: bool = false
@export var required_key: String = ""

var is_opened: bool = false

# Loot tables by rarity
const LOOT_TABLES := {
	ChestRarity.COMMON: [
		{"item_id": "gold", "chance": 1.0, "min": 10, "max": 30},
		{"item_id": "health_potion_small", "chance": 0.5, "min": 1, "max": 2},
		{"item_id": "bone_fragment", "chance": 0.3, "min": 1, "max": 3},
	],
	ChestRarity.UNCOMMON: [
		{"item_id": "gold", "chance": 1.0, "min": 30, "max": 75},
		{"item_id": "health_potion_small", "chance": 0.7, "min": 1, "max": 3},
		{"item_id": "iron_ore", "chance": 0.4, "min": 1, "max": 2},
		{"item_id": "leather_vest", "chance": 0.15, "min": 1, "max": 1},
	],
	ChestRarity.RARE: [
		{"item_id": "gold", "chance": 1.0, "min": 75, "max": 150},
		{"item_id": "health_potion_large", "chance": 0.8, "min": 1, "max": 2},
		{"item_id": "iron_sword", "chance": 0.3, "min": 1, "max": 1},
		{"item_id": "steel_ore", "chance": 0.3, "min": 1, "max": 2},
	],
	ChestRarity.EPIC: [
		{"item_id": "gold", "chance": 1.0, "min": 150, "max": 300},
		{"item_id": "health_potion_large", "chance": 1.0, "min": 2, "max": 3},
		{"item_id": "steel_sword", "chance": 0.5, "min": 1, "max": 1},
		{"item_id": "mithril_ore", "chance": 0.2, "min": 1, "max": 1},
	],
}


func _ready() -> void:
	one_time_use = true
	interaction_text = _get_interaction_text()
	super._ready()


func _get_interaction_text() -> String:
	if is_locked:
		return "Locked - Requires " + required_key.replace("_", " ")
	return "Press F to open chest"


func interact(player: Node3D) -> void:
	if is_opened:
		return

	# Check if locked
	if is_locked:
		if not _try_unlock(player):
			EventBus.show_message.emit("This chest is locked!", Color.RED, 2.0)
			AudioManager.play_sound_3d("locked", global_position)
			can_interact = true  # Allow retry
			return

	is_opened = true

	# Play open animation/effect
	_play_open_effect()

	# Drop loot
	_drop_loot()

	# Emit signal
	interacted.emit(player)


func _try_unlock(player: Node3D) -> bool:
	if required_key.is_empty():
		return false

	# Check if player has key in inventory
	if GameManager.inventory and GameManager.inventory.has_item(required_key):
		GameManager.inventory.remove_item_by_id(required_key, 1)
		EventBus.show_message.emit("Used " + required_key.replace("_", " "), Color.YELLOW, 2.0)
		is_locked = false
		return true

	return false


func _play_open_effect() -> void:
	AudioManager.play_sound_3d("chest_open", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		# Gold sparkle effect based on rarity
		var particle_count := 10 + chest_rarity * 10
		spawner.spawn_particles("magic", global_position + Vector3.UP * 0.5, particle_count)

	# Animate lid opening (if model has lid)
	var lid := get_node_or_null("Model/Lid")
	if lid:
		var tween := create_tween()
		tween.tween_property(lid, "rotation_degrees:x", -110, 0.3)


func _drop_loot() -> void:
	var loot_table: Array = LOOT_TABLES[chest_rarity]

	for entry in loot_table:
		if randf() <= entry.chance:
			var amount := randi_range(entry.min, entry.max)
			if entry.item_id == "gold":
				_give_gold(amount)
			else:
				_give_item(entry.item_id, amount)


func _give_gold(amount: int) -> void:
	if GameManager.inventory:
		GameManager.inventory.add_gold(amount)

		var spawner := get_node_or_null("/root/EffectSpawner")
		if spawner:
			spawner.spawn_damage_number(global_position + Vector3.UP * 1.5, amount, false, false)

		EventBus.show_message.emit("+" + str(amount) + " Gold", Color(1.0, 0.85, 0.3), 2.0)


func _give_item(item_id: String, amount: int) -> void:
	if GameManager.inventory:
		var overflow: int = GameManager.inventory.add_item(item_id, amount)
		var added: int = amount - overflow

		if added > 0:
			var item_def: Dictionary = ItemDatabase.get_item(item_id)
			var item_name: String = item_def.get("name", item_id.replace("_", " ").capitalize())

			# Color based on rarity
			var color := Color.WHITE
			var item_rarity: int = item_def.get("rarity", 0)
			match item_rarity:
				1: color = Color.GREEN
				2: color = Color.BLUE
				3: color = Color.PURPLE
				4: color = Color.ORANGE

			EventBus.show_message.emit("+" + str(added) + " " + item_name, color, 2.0)
			EventBus.item_picked_up.emit(item_id, added)
