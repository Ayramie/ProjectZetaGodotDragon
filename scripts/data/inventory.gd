extends RefCounted
class_name Inventory
## Inventory system with slots, equipment, and hotbar.

signal inventory_changed()
signal equipment_changed(slot: String)
signal hotbar_changed()
signal gold_changed(amount: int)

const SLOT_COUNT: int = 24
const HOTBAR_COUNT: int = 5

# Inventory slots (array of ItemStack or null)
var slots: Array = []

# Equipment slots
var equipment: Dictionary = {
	"weapon": null,
	"helmet": null,
	"chest": null,
	"gloves": null,
	"boots": null,
	"ring": null,
	"amulet": null
}

# Hotbar references (item IDs mapped to hotbar slots)
var hotbar: Array = []

# Currency
var gold: int = 0

# Item cooldowns
var item_cooldowns: Dictionary = {}


func _init() -> void:
	# Initialize empty slots
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = null

	hotbar.resize(HOTBAR_COUNT)
	for i in HOTBAR_COUNT:
		hotbar[i] = null


func add_item(item_id: String, quantity: int = 1) -> int:
	## Adds item to inventory. Returns overflow quantity.
	var item_def: Dictionary = ItemDatabase.get_item(item_id)
	if item_def.is_empty():
		return quantity

	var remaining := quantity

	# Try to stack with existing items first
	if item_def.get("stackable", false):
		for i in SLOT_COUNT:
			if remaining <= 0:
				break

			var stack: ItemStack = slots[i]
			if stack and stack.item_id == item_id:
				var max_stack: int = item_def.get("max_stack", 99)
				var can_add := max_stack - stack.quantity
				var to_add: int = mini(can_add, remaining)
				stack.quantity += to_add
				remaining -= to_add

	# Add to empty slots
	while remaining > 0:
		var empty_slot := _find_empty_slot()
		if empty_slot < 0:
			break

		var max_stack: int = item_def.get("max_stack", 99) if item_def.get("stackable", false) else 1
		var to_add: int = mini(max_stack, remaining)

		slots[empty_slot] = ItemStack.new(item_id, to_add)
		remaining -= to_add

	if remaining < quantity:
		inventory_changed.emit()
		EventBus.inventory_changed.emit()

	return remaining


func remove_item(slot_index: int, quantity: int = 1) -> bool:
	## Removes items from a specific slot. Returns true if successful.
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false

	var stack: ItemStack = slots[slot_index]
	if not stack:
		return false

	if stack.quantity <= quantity:
		slots[slot_index] = null
	else:
		stack.quantity -= quantity

	inventory_changed.emit()
	EventBus.inventory_changed.emit()
	return true


func remove_item_by_id(item_id: String, quantity: int = 1) -> bool:
	## Removes items by ID from any slots. Returns true if all were removed.
	var remaining := quantity

	for i in SLOT_COUNT:
		if remaining <= 0:
			break

		var stack: ItemStack = slots[i]
		if stack and stack.item_id == item_id:
			var to_remove: int = mini(stack.quantity, remaining)
			stack.quantity -= to_remove
			remaining -= to_remove

			if stack.quantity <= 0:
				slots[i] = null

	if remaining < quantity:
		inventory_changed.emit()
		EventBus.inventory_changed.emit()

	return remaining == 0


func count_item(item_id: String) -> int:
	## Counts total quantity of an item across all slots.
	var total := 0
	for stack in slots:
		if stack and stack.item_id == item_id:
			total += stack.quantity
	return total


func has_item(item_id: String, quantity: int = 1) -> bool:
	## Checks if inventory has at least quantity of item.
	return count_item(item_id) >= quantity


func equip_item(slot_index: int, player: Node3D = null) -> bool:
	## Equips item from inventory slot to equipment slot.
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false

	var stack: ItemStack = slots[slot_index]
	if not stack:
		return false

	var item_def: Dictionary = ItemDatabase.get_item(stack.item_id)
	if item_def.is_empty():
		return false

	var equip_slot: int = item_def.get("equip_slot", ItemDatabase.EquipSlot.NONE)
	if equip_slot == ItemDatabase.EquipSlot.NONE:
		return false

	# Check class restriction
	var restrictions: Array = item_def.get("class_restriction", [])
	if not restrictions.is_empty():
		var class_name_lower := GameManager.get_class_name_string().to_lower()
		if class_name_lower not in restrictions:
			return false

	var slot_name := _equip_slot_to_string(equip_slot)

	# Swap with existing equipment
	var old_equipment: ItemStack = equipment[slot_name]
	equipment[slot_name] = stack
	slots[slot_index] = old_equipment

	inventory_changed.emit()
	equipment_changed.emit(slot_name)
	EventBus.equipment_changed.emit(slot_name, stack.item_id)

	AudioManager.play_sound("equip")
	return true


func unequip_item(slot_name: String) -> bool:
	## Unequips item from equipment slot to inventory.
	if not equipment.has(slot_name):
		return false

	var stack: ItemStack = equipment[slot_name]
	if not stack:
		return false

	var empty_slot := _find_empty_slot()
	if empty_slot < 0:
		return false  # No room in inventory

	slots[empty_slot] = stack
	equipment[slot_name] = null

	inventory_changed.emit()
	equipment_changed.emit(slot_name)
	EventBus.equipment_changed.emit(slot_name, "")

	AudioManager.play_sound("unequip")
	return true


func assign_to_hotbar(inv_slot: int, hotbar_slot: int) -> bool:
	## Assigns an item to a hotbar slot.
	if inv_slot < 0 or inv_slot >= SLOT_COUNT:
		return false
	if hotbar_slot < 0 or hotbar_slot >= HOTBAR_COUNT:
		return false

	var stack: ItemStack = slots[inv_slot]
	if not stack:
		return false

	var item_def: Dictionary = ItemDatabase.get_item(stack.item_id)
	if item_def.get("type") != ItemDatabase.ItemType.CONSUMABLE:
		return false

	hotbar[hotbar_slot] = {
		"item_id": stack.item_id,
		"inventory_slot": inv_slot
	}

	hotbar_changed.emit()
	EventBus.hotbar_changed.emit()
	return true


func use_hotbar_item(hotbar_slot: int, player: Node3D) -> bool:
	## Uses item from hotbar slot.
	if hotbar_slot < 0 or hotbar_slot >= HOTBAR_COUNT:
		return false

	var hotbar_entry: Dictionary = hotbar[hotbar_slot]
	if not hotbar_entry:
		return false

	var item_id: String = hotbar_entry.item_id
	var item_def: Dictionary = ItemDatabase.get_item(item_id)
	if item_def.is_empty():
		return false

	# Check cooldown
	if item_cooldowns.has(item_id) and item_cooldowns[item_id] > 0:
		return false

	# Use the item
	var success := _use_consumable(item_id, item_def, player)
	if success:
		# Apply cooldown
		var cooldown: float = item_def.get("cooldown", 1.0)
		item_cooldowns[item_id] = cooldown

		# Consume item (unless infinite)
		if not item_def.get("infinite", false):
			remove_item_by_id(item_id, 1)
			# Clear hotbar if item is depleted
			if not has_item(item_id):
				hotbar[hotbar_slot] = null
				hotbar_changed.emit()

		EventBus.item_used.emit(item_id)

	return success


func _use_consumable(item_id: String, item_def: Dictionary, player: Node3D) -> bool:
	## Applies consumable effect to player.
	if not player:
		return false

	# Heal
	var heal_amount: int = item_def.get("heal_amount", 0)
	if heal_amount > 0:
		player.heal(heal_amount)
		AudioManager.play_sound("potion_drink")

	# Buff
	var buff_type: String = item_def.get("buff_type", "")
	if buff_type != "":
		var multiplier: float = item_def.get("buff_multiplier", 1.0)
		var duration: float = item_def.get("buff_duration", 10.0)
		player.apply_buff(buff_type, multiplier, duration)

	return true


func update_cooldowns(delta: float) -> void:
	## Updates item cooldowns.
	for item_id in item_cooldowns.keys():
		item_cooldowns[item_id] -= delta
		if item_cooldowns[item_id] <= 0:
			item_cooldowns.erase(item_id)


func get_cooldown(item_id: String) -> float:
	## Gets remaining cooldown for an item.
	return item_cooldowns.get(item_id, 0.0)


func get_cooldown_percent(item_id: String) -> float:
	## Gets cooldown as a percentage (0.0 to 1.0).
	var remaining: float = item_cooldowns.get(item_id, 0.0)
	if remaining <= 0:
		return 0.0

	var item_def: Dictionary = ItemDatabase.get_item(item_id)
	var max_cooldown: float = item_def.get("cooldown", 1.0)
	return remaining / max_cooldown


func get_equipment_stats() -> Dictionary:
	## Calculates total stats from all equipped items.
	var stats := {
		"damage": 0,
		"defense": 0,
		"max_health": 0,
		"attack_speed": 0,
		"magic_power": 0,
		"move_speed": 0
	}

	for slot in equipment:
		var stack: ItemStack = equipment[slot]
		if stack:
			var item_def: Dictionary = ItemDatabase.get_item(stack.item_id)
			stats.damage += item_def.get("damage", 0)
			stats.defense += item_def.get("defense", 0)
			stats.max_health += item_def.get("max_health", 0)
			stats.attack_speed += item_def.get("attack_speed", 0)
			stats.magic_power += item_def.get("magic_power", 0)
			stats.move_speed += item_def.get("move_speed", 0)

	return stats


func swap_slots(index_a: int, index_b: int) -> void:
	## Swaps two inventory slots.
	if index_a < 0 or index_a >= SLOT_COUNT:
		return
	if index_b < 0 or index_b >= SLOT_COUNT:
		return

	var temp: ItemStack = slots[index_a]
	slots[index_a] = slots[index_b]
	slots[index_b] = temp

	inventory_changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	EventBus.gold_changed.emit(gold)


func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		EventBus.gold_changed.emit(gold)
		return true
	return false


func give_starter_items(p_class: String) -> void:
	## Gives starting items based on class.
	match p_class.to_lower():
		"warrior":
			add_item("iron_sword", 1)
			equip_item(0)
			add_item("leather_vest", 1)
			equip_item(0)
		"mage":
			add_item("apprentice_staff", 1)
			equip_item(0)
			add_item("leather_vest", 1)
			equip_item(0)
		"hunter":
			add_item("wooden_bow", 1)
			equip_item(0)
			add_item("leather_vest", 1)
			equip_item(0)
		"adventurer":
			add_item("iron_sword", 1)
			equip_item(0)
			add_item("leather_vest", 1)
			equip_item(0)

	# Everyone gets potions
	add_item("health_potion_small", 5)
	add_item("infinite_health_potion", 1)

	# Assign potions to hotbar
	assign_to_hotbar(0, 0)


func _find_empty_slot() -> int:
	for i in SLOT_COUNT:
		if slots[i] == null:
			return i
	return -1


func _equip_slot_to_string(slot: int) -> String:
	match slot:
		ItemDatabase.EquipSlot.WEAPON: return "weapon"
		ItemDatabase.EquipSlot.HELMET: return "helmet"
		ItemDatabase.EquipSlot.CHEST: return "chest"
		ItemDatabase.EquipSlot.GLOVES: return "gloves"
		ItemDatabase.EquipSlot.BOOTS: return "boots"
		ItemDatabase.EquipSlot.RING: return "ring"
		ItemDatabase.EquipSlot.AMULET: return "amulet"
	return ""
