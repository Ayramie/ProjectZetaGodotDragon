extends RefCounted
class_name BankStorage
## Extended storage system for banking items and gold.
## Separate from player inventory, persists across scenes.

signal bank_changed()

const BANK_SLOT_COUNT: int = 48

var slots: Array = []
var gold: int = 0


func _init() -> void:
	slots.resize(BANK_SLOT_COUNT)
	for i in BANK_SLOT_COUNT:
		slots[i] = null


func deposit_item(inventory: Inventory, inv_slot: int) -> bool:
	## Move an item from player inventory to bank.
	## Returns true if successful.
	var stack: ItemStack = inventory.slots[inv_slot]
	if not stack:
		return false

	# Try to stack with existing items first
	for i in BANK_SLOT_COUNT:
		var bank_stack: ItemStack = slots[i]
		if bank_stack and bank_stack.item_id == stack.item_id:
			var item_def := ItemDatabase.get_item(stack.item_id)
			var max_stack: int = item_def.get("max_stack", 99)
			var can_add := max_stack - bank_stack.quantity
			if can_add > 0:
				var to_add := mini(can_add, stack.quantity)
				bank_stack.quantity += to_add
				stack.quantity -= to_add

				if stack.quantity <= 0:
					inventory.slots[inv_slot] = null
					inventory.inventory_changed.emit()
					bank_changed.emit()
					return true

	# Find empty slot
	var bank_slot := _find_empty_slot()
	if bank_slot < 0:
		return false  # Bank full

	# Move entire stack to bank
	slots[bank_slot] = stack
	inventory.slots[inv_slot] = null
	inventory.inventory_changed.emit()
	bank_changed.emit()
	return true


func withdraw_item(bank_slot: int, inventory: Inventory) -> bool:
	## Move an item from bank to player inventory.
	## Returns true if successful.
	var stack: ItemStack = slots[bank_slot]
	if not stack:
		return false

	# Try to add to inventory
	var overflow := inventory.add_item(stack.item_id, stack.quantity)
	if overflow == stack.quantity:
		return false  # Couldn't add any

	# Update or remove bank stack
	if overflow > 0:
		stack.quantity = overflow
	else:
		slots[bank_slot] = null

	bank_changed.emit()
	return true


func deposit_gold(inventory: Inventory, amount: int) -> bool:
	## Move gold from player inventory to bank.
	if amount <= 0:
		return false
	if inventory.gold < amount:
		return false

	inventory.remove_gold(amount)
	gold += amount
	bank_changed.emit()
	return true


func withdraw_gold(inventory: Inventory, amount: int) -> bool:
	## Move gold from bank to player inventory.
	if amount <= 0:
		return false
	if gold < amount:
		return false

	gold -= amount
	inventory.add_gold(amount)
	bank_changed.emit()
	return true


func _find_empty_slot() -> int:
	for i in BANK_SLOT_COUNT:
		if slots[i] == null:
			return i
	return -1


func get_total_items() -> int:
	## Get total number of items stored.
	var total := 0
	for slot in slots:
		if slot:
			total += slot.quantity
	return total


func get_save_data() -> Dictionary:
	## Get bank data for saving.
	var slot_data := []
	for slot in slots:
		if slot and slot is ItemStack:
			slot_data.append({
				"id": slot.item_id,
				"quantity": slot.quantity
			})
		else:
			slot_data.append(null)

	return {
		"slots": slot_data,
		"gold": gold
	}


func load_save_data(data: Dictionary) -> void:
	## Load bank data from save.
	if data.has("gold"):
		gold = data.gold

	if data.has("slots"):
		var slot_data: Array = data.slots
		for i in mini(slot_data.size(), BANK_SLOT_COUNT):
			if slot_data[i] and slot_data[i] is Dictionary:
				slots[i] = ItemStack.new(slot_data[i].id, slot_data[i].quantity)
			else:
				slots[i] = null

	bank_changed.emit()
