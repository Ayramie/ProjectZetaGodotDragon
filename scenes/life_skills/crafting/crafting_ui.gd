extends Control
class_name CraftingUI
## Crafting UI for wood-based items.
## Recipe selection with progress bar.

signal crafting_complete(recipe_id: String, result_id: String)
signal crafting_cancelled()

enum State { IDLE, MENU, CRAFTING, COMPLETE }

# UI nodes - created programmatically
var recipe_panel: PanelContainer
var recipe_list: VBoxContainer
var crafting_panel: PanelContainer
var progress_bar: ProgressBar
var crafting_label: Label
var result_panel: PanelContainer
var result_label: Label

var state: State = State.IDLE
var inventory: Inventory = null

# Current crafting state
var current_recipe: Dictionary = {}
var craft_timer: float = 0.0
var craft_time: float = 2.0


func _ready() -> void:
	_build_ui()
	visible = false
	recipe_panel.visible = false
	crafting_panel.visible = false
	result_panel.visible = false


func _build_ui() -> void:
	# Full screen anchor
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Recipe panel with scroll
	recipe_panel = PanelContainer.new()
	recipe_panel.set_anchors_preset(Control.PRESET_CENTER)
	recipe_panel.custom_minimum_size = Vector2(450, 400)
	recipe_panel.position = -recipe_panel.custom_minimum_size / 2
	add_child(recipe_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	recipe_panel.add_child(scroll)

	var recipe_vbox := VBoxContainer.new()
	recipe_vbox.add_theme_constant_override("separation", 10)
	recipe_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipe_vbox)

	var title := Label.new()
	title.text = "Crafting Bench"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	recipe_vbox.add_child(title)

	recipe_list = VBoxContainer.new()
	recipe_list.add_theme_constant_override("separation", 5)
	recipe_vbox.add_child(recipe_list)

	# Crafting panel
	crafting_panel = PanelContainer.new()
	crafting_panel.set_anchors_preset(Control.PRESET_CENTER)
	crafting_panel.custom_minimum_size = Vector2(400, 180)
	crafting_panel.position = -crafting_panel.custom_minimum_size / 2
	add_child(crafting_panel)

	var craft_vbox := VBoxContainer.new()
	craft_vbox.add_theme_constant_override("separation", 15)
	crafting_panel.add_child(craft_vbox)

	crafting_label = Label.new()
	crafting_label.text = "Crafting..."
	crafting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crafting_label.add_theme_font_size_override("font_size", 20)
	craft_vbox.add_child(crafting_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(350, 30)
	progress_bar.max_value = 100.0
	craft_vbox.add_child(progress_bar)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(cancel)
	craft_vbox.add_child(cancel_btn)

	# Result panel
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(300, 100)
	result_panel.position = -result_panel.custom_minimum_size / 2
	add_child(result_panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 22)
	result_panel.add_child(result_label)


func start_crafting(inv: Inventory) -> void:
	inventory = inv
	visible = true
	state = State.MENU
	_build_recipe_list()
	recipe_panel.visible = true
	crafting_panel.visible = false


func _build_recipe_list() -> void:
	# Clear existing items
	for child in recipe_list.get_children():
		child.queue_free()

	# Get all crafting recipes
	var recipes: Array = RecipeDatabase.get_recipes(RecipeDatabase.RecipeType.CRAFTING)

	for recipe in recipes:
		_add_recipe_button(recipe)

	# Add cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(cancel)
	recipe_list.add_child(cancel_btn)


func _add_recipe_button(recipe: Dictionary) -> void:
	var container := VBoxContainer.new()

	# Recipe name
	var name_label := Label.new()
	name_label.text = recipe.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 16)
	container.add_child(name_label)

	# Materials list
	var materials_text := "Requires: "
	var can_craft := true
	for i in recipe.materials.size():
		var material: Dictionary = recipe.materials[i]
		var mat_def: Dictionary = ItemDatabase.get_item(material.id)
		var mat_name: String = mat_def.get("name", material.id)
		var have: int = inventory.count_item(material.id)
		var need: int = material.amount

		if i > 0:
			materials_text += ", "

		if have >= need:
			materials_text += "%s %d/%d" % [mat_name, have, need]
		else:
			materials_text += "[color=red]%s %d/%d[/color]" % [mat_name, have, need]
			can_craft = false

	var materials_label := RichTextLabel.new()
	materials_label.bbcode_enabled = true
	materials_label.text = materials_text
	materials_label.fit_content = true
	materials_label.custom_minimum_size.y = 20
	container.add_child(materials_label)

	# Craft button
	var btn := Button.new()
	btn.text = "Craft" if can_craft else "Cannot Craft"
	btn.disabled = not can_craft
	if can_craft:
		btn.pressed.connect(_on_recipe_selected.bind(recipe))
	container.add_child(btn)

	# Separator
	var sep := HSeparator.new()
	container.add_child(sep)

	recipe_list.add_child(container)


func _on_recipe_selected(recipe: Dictionary) -> void:
	# Deduct materials
	for material in recipe.materials:
		if not inventory.remove_item_by_id(material.id, material.amount):
			EventBus.show_message.emit("Not enough materials!", Color.RED, 2.0)
			return

	current_recipe = recipe
	craft_timer = 0.0
	craft_time = recipe.get("craft_time", 2.0)

	recipe_panel.visible = false
	crafting_panel.visible = true
	state = State.CRAFTING

	crafting_label.text = "Crafting %s..." % recipe.get("name", "item")


func _process(delta: float) -> void:
	if state != State.CRAFTING:
		return

	craft_timer += delta
	progress_bar.value = (craft_timer / craft_time) * 100.0

	if craft_timer >= craft_time:
		_complete_crafting()


func _complete_crafting() -> void:
	state = State.COMPLETE
	crafting_panel.visible = false

	# Add result to inventory
	var result_id: String = current_recipe.get("result_id", "")
	var result_amount: int = current_recipe.get("result_amount", 1)
	inventory.add_item(result_id, result_amount)

	var result_def: Dictionary = ItemDatabase.get_item(result_id)
	var result_name: String = result_def.get("name", result_id)

	result_label.text = "Crafted %s!" % result_name
	result_panel.visible = true

	AudioManager.play_sound("craft_complete") if AudioManager.has_method("play_sound") else null

	crafting_complete.emit(current_recipe.id, result_id)

	await get_tree().create_timer(2.0).timeout
	_end_crafting()


func _end_crafting() -> void:
	state = State.IDLE
	visible = false
	recipe_panel.visible = false
	crafting_panel.visible = false
	result_panel.visible = false


func cancel() -> void:
	if state == State.CRAFTING:
		# Refund materials if cancelled during crafting
		for material in current_recipe.materials:
			inventory.add_item(material.id, material.amount)

	if state != State.IDLE:
		state = State.IDLE
		visible = false
		crafting_cancelled.emit()
