extends Control
class_name ShopUI
## Shop UI for buying and selling items.

signal shop_closed()

enum Tab { BUY, SELL }

var shop_panel: PanelContainer = null
var tab_container: TabContainer = null
var buy_scroll: ScrollContainer = null
var sell_scroll: ScrollContainer = null
var buy_list: VBoxContainer = null
var sell_list: VBoxContainer = null
var gold_label: Label = null
var shop_name_label: Label = null

var current_shop_id: String = ""
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
	shop_panel = PanelContainer.new()
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.custom_minimum_size = Vector2(650, 500)
	shop_panel.position = -shop_panel.custom_minimum_size / 2
	add_child(shop_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	shop_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# Header
	var header := HBoxContainer.new()
	shop_name_label = Label.new()
	shop_name_label.text = "Shop"
	shop_name_label.add_theme_font_size_override("font_size", 24)
	header.add_child(shop_name_label)
	header.add_spacer(false)
	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(gold_label)
	main_vbox.add_child(header)

	# Tab container
	tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(600, 380)
	main_vbox.add_child(tab_container)

	# Buy tab
	buy_scroll = ScrollContainer.new()
	buy_scroll.name = "Buy"
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	buy_list = VBoxContainer.new()
	buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_list.add_theme_constant_override("separation", 5)
	buy_scroll.add_child(buy_list)
	tab_container.add_child(buy_scroll)

	# Sell tab
	sell_scroll = ScrollContainer.new()
	sell_scroll.name = "Sell"
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sell_list = VBoxContainer.new()
	sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_list.add_theme_constant_override("separation", 5)
	sell_scroll.add_child(sell_list)
	tab_container.add_child(sell_scroll)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	main_vbox.add_child(close_btn)


func open(shop_id: String, inv: Inventory, shop_name: String = "") -> void:
	current_shop_id = shop_id
	inventory = inv
	is_open = true
	visible = true

	# Set shop name
	if shop_name.is_empty():
		shop_name_label.text = shop_id.replace("_", " ").capitalize()
	else:
		shop_name_label.text = shop_name

	_refresh_gold()
	_populate_buy_tab()
	_populate_sell_tab()

	GameManager.set_game_state(GameManager.GameState.PAUSED)
	EventBus.shop_opened.emit(shop_id)


func _refresh_gold() -> void:
	if inventory:
		gold_label.text = "Gold: %d" % inventory.gold


func _populate_buy_tab() -> void:
	# Clear existing items
	for child in buy_list.get_children():
		child.queue_free()

	var shop_items := ShopDatabase.get_shop(current_shop_id)
	if shop_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "This shop has nothing for sale."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		buy_list.add_child(empty_label)
		return

	for shop_item in shop_items:
		if not ShopDatabase.can_buy(current_shop_id, shop_item.item_id):
			continue  # Skip out of stock items
		_add_buy_item(shop_item)


func _add_buy_item(shop_item: Dictionary) -> void:
	var item_def := ItemDatabase.get_item(shop_item.item_id)
	if item_def.is_empty():
		return

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# Item name
	var name_label := Label.new()
	name_label.text = item_def.get("name", shop_item.item_id.replace("_", " ").capitalize())
	name_label.custom_minimum_size = Vector2(250, 0)
	hbox.add_child(name_label)

	# Price
	var price_label := Label.new()
	var price: int = shop_item.get("buy_price", 0)
	price_label.text = "%d gold" % price
	price_label.custom_minimum_size = Vector2(100, 0)
	if inventory and inventory.gold < price:
		price_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox.add_child(price_label)

	# Stock
	var stock: int = shop_item.get("stock", -1)
	if stock >= 0:
		var stock_label := Label.new()
		stock_label.text = "x%d" % stock
		stock_label.custom_minimum_size = Vector2(50, 0)
		hbox.add_child(stock_label)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.disabled = not inventory or inventory.gold < price
	buy_btn.pressed.connect(_on_buy_pressed.bind(shop_item))
	hbox.add_child(buy_btn)

	buy_list.add_child(hbox)


func _populate_sell_tab() -> void:
	# Clear existing items
	for child in sell_list.get_children():
		child.queue_free()

	if not inventory:
		return

	var has_items := false
	for i in inventory.slots.size():
		var stack: ItemStack = inventory.slots[i]
		if stack:
			_add_sell_item(i, stack)
			has_items = true

	if not has_items:
		var empty_label := Label.new()
		empty_label.text = "You have nothing to sell."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sell_list.add_child(empty_label)


func _add_sell_item(slot_index: int, stack: ItemStack) -> void:
	var item_def := ItemDatabase.get_item(stack.item_id)
	if item_def.is_empty():
		return

	var sell_price := ShopDatabase.get_sell_price(stack.item_id)
	if sell_price <= 0:
		return  # Item cannot be sold

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# Item name and quantity
	var name_label := Label.new()
	name_label.text = "%s x%d" % [item_def.get("name", stack.item_id), stack.quantity]
	name_label.custom_minimum_size = Vector2(250, 0)
	hbox.add_child(name_label)

	# Sell price
	var price_label := Label.new()
	price_label.text = "%d gold each" % sell_price
	price_label.custom_minimum_size = Vector2(120, 0)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox.add_child(price_label)

	# Sell 1 button
	var sell_one_btn := Button.new()
	sell_one_btn.text = "Sell 1"
	sell_one_btn.pressed.connect(_on_sell_pressed.bind(slot_index, 1))
	hbox.add_child(sell_one_btn)

	# Sell all button
	if stack.quantity > 1:
		var sell_all_btn := Button.new()
		sell_all_btn.text = "Sell All"
		sell_all_btn.pressed.connect(_on_sell_pressed.bind(slot_index, stack.quantity))
		hbox.add_child(sell_all_btn)

	sell_list.add_child(hbox)


func _on_buy_pressed(shop_item: Dictionary) -> void:
	if not inventory:
		return

	var price: int = shop_item.get("buy_price", 0)
	if inventory.gold < price:
		EventBus.show_message.emit("Not enough gold!", Color.RED, 2.0)
		return

	# Try to add item to inventory
	var overflow := inventory.add_item(shop_item.item_id, 1)
	if overflow > 0:
		EventBus.show_message.emit("Inventory full!", Color.RED, 2.0)
		return

	# Deduct gold and update stock
	inventory.remove_gold(price)
	ShopDatabase.buy_item(current_shop_id, shop_item.item_id)

	AudioManager.play_sound("buy")
	EventBus.item_purchased.emit(shop_item.item_id, price)

	# Refresh UI
	_refresh_gold()
	_populate_buy_tab()
	_populate_sell_tab()


func _on_sell_pressed(slot_index: int, quantity: int) -> void:
	if not inventory:
		return

	var stack: ItemStack = inventory.slots[slot_index]
	if not stack:
		return

	var sell_price := ShopDatabase.get_sell_price(stack.item_id)
	var total := sell_price * quantity

	# Remove items and add gold
	inventory.remove_item(slot_index, quantity)
	inventory.add_gold(total)

	AudioManager.play_sound("sell")
	EventBus.item_sold.emit(stack.item_id, total)

	# Refresh UI
	_refresh_gold()
	_populate_sell_tab()


func close() -> void:
	is_open = false
	visible = false
	current_shop_id = ""
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	EventBus.shop_closed.emit()
	shop_closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
