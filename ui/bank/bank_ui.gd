extends Control
class_name BankUI
## Bank UI for depositing/withdrawing items and gold.

signal bank_closed()

var bank_panel: PanelContainer = null
var bank_grid: GridContainer = null
var inventory_grid: GridContainer = null
var bank_gold_label: Label = null
var inventory_gold_label: Label = null
var gold_amount_input: SpinBox = null

var bank_storage: BankStorage = null
var inventory: Inventory = null
var is_open: bool = false


func _ready() -> void:
	_build_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	add_child(bg)

	# Main panel
	bank_panel = PanelContainer.new()
	bank_panel.set_anchors_preset(Control.PRESET_CENTER)
	bank_panel.custom_minimum_size = Vector2(850, 550)
	bank_panel.position = -bank_panel.custom_minimum_size / 2
	add_child(bank_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	bank_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "Bank Storage"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Grids container
	var grids_hbox := HBoxContainer.new()
	grids_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(grids_hbox)

	# Bank side
	var bank_vbox := VBoxContainer.new()
	bank_vbox.add_theme_constant_override("separation", 8)

	var bank_header := HBoxContainer.new()
	var bank_label := Label.new()
	bank_label.text = "Bank"
	bank_label.add_theme_font_size_override("font_size", 18)
	bank_header.add_child(bank_label)
	bank_header.add_spacer(false)
	bank_gold_label = Label.new()
	bank_gold_label.text = "Gold: 0"
	bank_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	bank_header.add_child(bank_gold_label)
	bank_vbox.add_child(bank_header)

	var bank_scroll := ScrollContainer.new()
	bank_scroll.custom_minimum_size = Vector2(380, 350)
	bank_grid = GridContainer.new()
	bank_grid.columns = 8
	bank_grid.add_theme_constant_override("h_separation", 4)
	bank_grid.add_theme_constant_override("v_separation", 4)
	bank_scroll.add_child(bank_grid)
	bank_vbox.add_child(bank_scroll)
	grids_hbox.add_child(bank_vbox)

	# Separator
	var sep := VSeparator.new()
	grids_hbox.add_child(sep)

	# Inventory side
	var inv_vbox := VBoxContainer.new()
	inv_vbox.add_theme_constant_override("separation", 8)

	var inv_header := HBoxContainer.new()
	var inv_label := Label.new()
	inv_label.text = "Inventory"
	inv_label.add_theme_font_size_override("font_size", 18)
	inv_header.add_child(inv_label)
	inv_header.add_spacer(false)
	inventory_gold_label = Label.new()
	inventory_gold_label.text = "Gold: 0"
	inventory_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	inv_header.add_child(inventory_gold_label)
	inv_vbox.add_child(inv_header)

	var inv_scroll := ScrollContainer.new()
	inv_scroll.custom_minimum_size = Vector2(300, 350)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 4)
	inventory_grid.add_theme_constant_override("v_separation", 4)
	inv_scroll.add_child(inventory_grid)
	inv_vbox.add_child(inv_scroll)
	grids_hbox.add_child(inv_vbox)

	# Gold transfer controls
	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 10)
	gold_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var gold_label := Label.new()
	gold_label.text = "Gold amount:"
	gold_hbox.add_child(gold_label)

	gold_amount_input = SpinBox.new()
	gold_amount_input.min_value = 0
	gold_amount_input.max_value = 999999
	gold_amount_input.value = 100
	gold_amount_input.custom_minimum_size = Vector2(120, 0)
	gold_hbox.add_child(gold_amount_input)

	var deposit_btn := Button.new()
	deposit_btn.text = "Deposit Gold"
	deposit_btn.pressed.connect(_on_deposit_gold)
	gold_hbox.add_child(deposit_btn)

	var withdraw_btn := Button.new()
	withdraw_btn.text = "Withdraw Gold"
	withdraw_btn.pressed.connect(_on_withdraw_gold)
	gold_hbox.add_child(withdraw_btn)

	main_vbox.add_child(gold_hbox)

	# Help text
	var help := Label.new()
	help.text = "Click items to transfer between bank and inventory"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(help)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	main_vbox.add_child(close_btn)


func open(bank: BankStorage, inv: Inventory) -> void:
	bank_storage = bank
	inventory = inv
	is_open = true
	visible = true
	_refresh_all()
	GameManager.set_game_state(GameManager.GameState.PAUSED)
	EventBus.bank_opened.emit()


func _refresh_all() -> void:
	_refresh_bank_grid()
	_refresh_inventory_grid()
	_refresh_gold_labels()


func _refresh_bank_grid() -> void:
	# Clear existing buttons
	for child in bank_grid.get_children():
		child.queue_free()

	# Create slot buttons
	for i in bank_storage.slots.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(42, 42)
		btn.tooltip_text = ""

		var stack: ItemStack = bank_storage.slots[i]
		if stack:
			var item_def := ItemDatabase.get_item(stack.item_id)
			var item_name: String = item_def.get("name", stack.item_id)
			btn.text = item_name.substr(0, 2).to_upper()
			btn.tooltip_text = "%s x%d\nClick to withdraw" % [item_name, stack.quantity]
			btn.pressed.connect(_on_bank_slot_pressed.bind(i))
		else:
			btn.text = ""
			btn.disabled = true

		bank_grid.add_child(btn)


func _refresh_inventory_grid() -> void:
	# Clear existing buttons
	for child in inventory_grid.get_children():
		child.queue_free()

	if not inventory:
		return

	# Create slot buttons
	for i in inventory.slots.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(42, 42)
		btn.tooltip_text = ""

		var stack: ItemStack = inventory.slots[i]
		if stack:
			var item_def := ItemDatabase.get_item(stack.item_id)
			var item_name: String = item_def.get("name", stack.item_id)
			btn.text = item_name.substr(0, 2).to_upper()
			btn.tooltip_text = "%s x%d\nClick to deposit" % [item_name, stack.quantity]
			btn.pressed.connect(_on_inventory_slot_pressed.bind(i))
		else:
			btn.text = ""
			btn.disabled = true

		inventory_grid.add_child(btn)


func _refresh_gold_labels() -> void:
	if bank_storage:
		bank_gold_label.text = "Gold: %d" % bank_storage.gold
	if inventory:
		inventory_gold_label.text = "Gold: %d" % inventory.gold


func _on_bank_slot_pressed(slot: int) -> void:
	if bank_storage.withdraw_item(slot, inventory):
		AudioManager.play_sound("item_move")
		_refresh_all()
	else:
		EventBus.show_message.emit("Inventory full!", Color.RED, 1.5)


func _on_inventory_slot_pressed(slot: int) -> void:
	if bank_storage.deposit_item(inventory, slot):
		AudioManager.play_sound("item_move")
		_refresh_all()
	else:
		EventBus.show_message.emit("Bank full!", Color.RED, 1.5)


func _on_deposit_gold() -> void:
	var amount := int(gold_amount_input.value)
	if bank_storage.deposit_gold(inventory, amount):
		AudioManager.play_sound("coins")
		_refresh_gold_labels()
	else:
		EventBus.show_message.emit("Not enough gold!", Color.RED, 1.5)


func _on_withdraw_gold() -> void:
	var amount := int(gold_amount_input.value)
	if bank_storage.withdraw_gold(inventory, amount):
		AudioManager.play_sound("coins")
		_refresh_gold_labels()
	else:
		EventBus.show_message.emit("Not enough gold in bank!", Color.RED, 1.5)


func close() -> void:
	is_open = false
	visible = false
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	EventBus.bank_closed.emit()
	bank_closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
