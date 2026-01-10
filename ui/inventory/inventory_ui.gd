extends Control
class_name InventoryUI
## Inventory UI panel with item slots and equipment display.

signal closed()

const SLOT_SIZE := Vector2(50, 50)
const SLOT_PADDING := 5

@onready var inventory_grid: GridContainer = $Panel/HBox/InventorySection/InventoryGrid
@onready var equipment_section: VBoxContainer = $Panel/HBox/EquipmentSection
@onready var item_tooltip: PanelContainer = $ItemTooltip
@onready var tooltip_name: Label = $ItemTooltip/VBox/ItemName
@onready var tooltip_type: Label = $ItemTooltip/VBox/ItemType
@onready var tooltip_stats: Label = $ItemTooltip/VBox/ItemStats
@onready var tooltip_desc: Label = $ItemTooltip/VBox/ItemDesc

var inventory: Inventory = null
var slot_buttons: Array[Button] = []
var equip_buttons: Dictionary = {}
var hovered_slot: int = -1
var selected_slot: int = -1


func _ready() -> void:
	visible = false
	item_tooltip.visible = false
	_create_inventory_slots()
	_create_equipment_slots()


func _input(event: InputEvent) -> void:
	# Only handle input when visible
	if not visible:
		return

	# Update tooltip position
	if item_tooltip.visible:
		item_tooltip.global_position = get_global_mouse_position() + Vector2(15, 15)


func open(inv: Inventory) -> void:
	inventory = inv
	visible = true
	_refresh_all()

	# Connect to inventory changes
	if inventory and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
		inventory.equipment_changed.connect(_on_equipment_changed)


func close() -> void:
	visible = false
	item_tooltip.visible = false
	selected_slot = -1
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	elif inventory:
		open(inventory)


func set_inventory(inv: Inventory) -> void:
	inventory = inv


func _create_inventory_slots() -> void:
	# Create 24 inventory slot buttons (6 columns x 4 rows)
	inventory_grid.columns = 6

	for i in Inventory.SLOT_COUNT:
		var slot := _create_slot_button(i)
		inventory_grid.add_child(slot)
		slot_buttons.append(slot)


func _create_equipment_slots() -> void:
	# Create equipment slot buttons
	var equip_slots := ["weapon", "helmet", "chest", "gloves", "boots", "ring", "amulet"]
	var equip_labels := ["Weapon", "Helmet", "Chest", "Gloves", "Boots", "Ring", "Amulet"]

	for i in equip_slots.size():
		var hbox := HBoxContainer.new()

		var label := Label.new()
		label.text = equip_labels[i]
		label.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(label)

		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.set_meta("equip_slot", equip_slots[i])
		slot.pressed.connect(_on_equip_slot_pressed.bind(equip_slots[i]))
		slot.mouse_entered.connect(_on_equip_slot_hover.bind(equip_slots[i]))
		slot.mouse_exited.connect(_on_slot_unhover)
		hbox.add_child(slot)

		equipment_section.add_child(hbox)
		equip_buttons[equip_slots[i]] = slot


func _create_slot_button(index: int) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.set_meta("slot_index", index)
	slot.pressed.connect(_on_slot_pressed.bind(index))
	slot.mouse_entered.connect(_on_slot_hover.bind(index))
	slot.mouse_exited.connect(_on_slot_unhover)
	return slot


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_equipment()


func _refresh_inventory() -> void:
	if not inventory:
		return

	for i in slot_buttons.size():
		var slot_btn := slot_buttons[i]
		var stack: ItemStack = inventory.slots[i]

		if stack:
			var item_def: Dictionary = ItemDatabase.get_item(stack.item_id)
			slot_btn.text = item_def.get("name", stack.item_id).substr(0, 3)
			if stack.quantity > 1:
				slot_btn.text += "\n" + str(stack.quantity)

			# Color based on rarity
			var rarity: int = item_def.get("rarity", 0)
			slot_btn.modulate = _get_rarity_color(rarity)
		else:
			slot_btn.text = ""
			slot_btn.modulate = Color.WHITE


func _refresh_equipment() -> void:
	if not inventory:
		return

	for slot_name in equip_buttons:
		var slot_btn: Button = equip_buttons[slot_name]
		var stack: ItemStack = inventory.equipment[slot_name]

		if stack:
			var item_def: Dictionary = ItemDatabase.get_item(stack.item_id)
			slot_btn.text = item_def.get("name", stack.item_id).substr(0, 3)

			var rarity: int = item_def.get("rarity", 0)
			slot_btn.modulate = _get_rarity_color(rarity)
		else:
			slot_btn.text = ""
			slot_btn.modulate = Color.GRAY


func _on_slot_pressed(index: int) -> void:
	if not inventory:
		return

	var stack: ItemStack = inventory.slots[index]
	if not stack:
		# If we have a selected slot, swap
		if selected_slot >= 0 and selected_slot != index:
			inventory.swap_slots(selected_slot, index)
			selected_slot = -1
		return

	# If clicking same slot, try to equip
	if selected_slot == index:
		inventory.equip_item(index)
		selected_slot = -1
	else:
		# Select this slot
		selected_slot = index

	_refresh_all()


func _on_equip_slot_pressed(slot_name: String) -> void:
	if not inventory:
		return

	# Unequip to inventory
	inventory.unequip_item(slot_name)
	_refresh_all()


func _on_slot_hover(index: int) -> void:
	hovered_slot = index

	if not inventory:
		return

	var stack: ItemStack = inventory.slots[index]
	if stack:
		_show_tooltip(stack.item_id)
	else:
		item_tooltip.visible = false


func _on_equip_slot_hover(slot_name: String) -> void:
	if not inventory:
		return

	var stack: ItemStack = inventory.equipment[slot_name]
	if stack:
		_show_tooltip(stack.item_id)
	else:
		item_tooltip.visible = false


func _on_slot_unhover() -> void:
	hovered_slot = -1
	item_tooltip.visible = false


func _show_tooltip(item_id: String) -> void:
	var item_def: Dictionary = ItemDatabase.get_item(item_id)
	if item_def.is_empty():
		item_tooltip.visible = false
		return

	tooltip_name.text = item_def.get("name", item_id)
	tooltip_name.modulate = _get_rarity_color(item_def.get("rarity", 0))

	# Type
	var type_str := ""
	match item_def.get("type", 0):
		ItemDatabase.ItemType.WEAPON: type_str = "Weapon"
		ItemDatabase.ItemType.ARMOR: type_str = "Armor"
		ItemDatabase.ItemType.CONSUMABLE: type_str = "Consumable"
		ItemDatabase.ItemType.MATERIAL: type_str = "Material"
		ItemDatabase.ItemType.QUEST: type_str = "Quest Item"
	tooltip_type.text = type_str

	# Stats
	var stats_text := ""
	if item_def.has("damage") and item_def.damage > 0:
		stats_text += "Damage: %d\n" % item_def.damage
	if item_def.has("defense") and item_def.defense > 0:
		stats_text += "Defense: %d\n" % item_def.defense
	if item_def.has("max_health") and item_def.max_health > 0:
		stats_text += "Health: +%d\n" % item_def.max_health
	if item_def.has("heal_amount") and item_def.heal_amount > 0:
		stats_text += "Heals: %d HP\n" % item_def.heal_amount
	tooltip_stats.text = stats_text.strip_edges()
	tooltip_stats.visible = stats_text.length() > 0

	# Description
	tooltip_desc.text = item_def.get("description", "")
	tooltip_desc.visible = tooltip_desc.text.length() > 0

	item_tooltip.visible = true

	# Position tooltip near mouse
	item_tooltip.global_position = get_global_mouse_position() + Vector2(15, 15)


func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color.WHITE        # Common
		1: return Color.GREEN        # Uncommon
		2: return Color.BLUE         # Rare
		3: return Color.PURPLE       # Epic
		4: return Color.ORANGE       # Legendary
		_: return Color.WHITE


func _on_inventory_changed() -> void:
	_refresh_inventory()


func _on_equipment_changed(_slot: String) -> void:
	_refresh_equipment()
