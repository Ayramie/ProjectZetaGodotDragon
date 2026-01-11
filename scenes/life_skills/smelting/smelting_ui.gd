extends Control
class_name SmeltingUI
## Smelting UI with auto-progress.
## Converts ore to metal bars.

signal smelting_complete(results: Dictionary)
signal smelting_cancelled()

enum State { IDLE, SELECTING, SMELTING, COMPLETE }

# UI nodes - created programmatically
var selection_panel: PanelContainer
var selection_list: VBoxContainer
var smelting_panel: PanelContainer
var progress_bar: ProgressBar
var status_label: Label
var item_label: Label
var result_panel: PanelContainer
var result_label: Label

var state: State = State.IDLE
var inventory: Inventory = null

# Current smelting state
var current_ore_id: String = ""
var current_recipe: Dictionary = {}
var items_to_smelt: int = 0
var items_smelted: int = 0
var smelt_timer: float = 0.0
var smelt_time: float = 3.0

# Ore types that can be smelted
const SMELTABLE_ORE := [
	"ore_copper",
	"ore_iron",
	"ore_gold"
]


func _ready() -> void:
	_build_ui()
	visible = false
	selection_panel.visible = false
	smelting_panel.visible = false
	result_panel.visible = false


func _build_ui() -> void:
	# Full screen anchor
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Selection panel
	selection_panel = PanelContainer.new()
	selection_panel.set_anchors_preset(Control.PRESET_CENTER)
	selection_panel.custom_minimum_size = Vector2(400, 350)
	selection_panel.position = -selection_panel.custom_minimum_size / 2
	add_child(selection_panel)

	var sel_vbox := VBoxContainer.new()
	sel_vbox.add_theme_constant_override("separation", 10)
	selection_panel.add_child(sel_vbox)

	var sel_title := Label.new()
	sel_title.text = "Smelting - Select Ore"
	sel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel_title.add_theme_font_size_override("font_size", 20)
	sel_vbox.add_child(sel_title)

	selection_list = VBoxContainer.new()
	selection_list.add_theme_constant_override("separation", 8)
	sel_vbox.add_child(selection_list)

	# Smelting panel
	smelting_panel = PanelContainer.new()
	smelting_panel.set_anchors_preset(Control.PRESET_CENTER)
	smelting_panel.custom_minimum_size = Vector2(400, 200)
	smelting_panel.position = -smelting_panel.custom_minimum_size / 2
	add_child(smelting_panel)

	var smelt_vbox := VBoxContainer.new()
	smelt_vbox.add_theme_constant_override("separation", 15)
	smelting_panel.add_child(smelt_vbox)

	item_label = Label.new()
	item_label.text = "Smelting..."
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 20)
	smelt_vbox.add_child(item_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(350, 30)
	progress_bar.max_value = 100.0
	smelt_vbox.add_child(progress_bar)

	status_label = Label.new()
	status_label.text = "Smelting... 0 / 0"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	smelt_vbox.add_child(status_label)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(cancel)
	smelt_vbox.add_child(cancel_btn)

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


func start_smelting(inv: Inventory) -> void:
	inventory = inv
	visible = true
	state = State.SELECTING
	_build_selection_list()
	selection_panel.visible = true
	smelting_panel.visible = false


func _build_selection_list() -> void:
	# Clear existing items
	for child in selection_list.get_children():
		child.queue_free()

	# Check each smeltable ore type
	var has_any := false
	for ore_id in SMELTABLE_ORE:
		var count := inventory.count_item(ore_id)
		if count > 0:
			has_any = true
			_add_selection_button(ore_id, count)

	if not has_any:
		var label := Label.new()
		label.text = "No ore to smelt!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_list.add_child(label)

	# Add cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(cancel)
	selection_list.add_child(cancel_btn)


func _add_selection_button(ore_id: String, count: int) -> void:
	var item_def: Dictionary = ItemDatabase.get_item(ore_id)
	var ore_name: String = item_def.get("name", ore_id)

	# Find the smelting recipe for this ore
	var recipe := _find_smelting_recipe(ore_id)
	if recipe.is_empty():
		return

	var result_def: Dictionary = ItemDatabase.get_item(recipe.result_id)
	var result_name: String = result_def.get("name", recipe.result_id)

	var btn := Button.new()
	btn.text = "%s x%d → %s" % [ore_name, count, result_name]
	btn.pressed.connect(_on_ore_selected.bind(ore_id, recipe, count))
	selection_list.add_child(btn)


func _find_smelting_recipe(ore_id: String) -> Dictionary:
	var recipes: Array = RecipeDatabase.get_recipes(RecipeDatabase.RecipeType.SMELTING)
	for recipe in recipes:
		for material in recipe.materials:
			if material.id == ore_id:
				return recipe
	return {}


func _on_ore_selected(ore_id: String, recipe: Dictionary, count: int) -> void:
	current_ore_id = ore_id
	current_recipe = recipe
	items_to_smelt = count
	items_smelted = 0
	smelt_timer = 0.0
	smelt_time = recipe.get("craft_time", 3.0)

	selection_panel.visible = false
	smelting_panel.visible = true
	state = State.SMELTING

	var ore_def: Dictionary = ItemDatabase.get_item(ore_id)
	item_label.text = "Smelting %s..." % ore_def.get("name", ore_id)
	_update_status()


func _process(delta: float) -> void:
	if state != State.SMELTING:
		return

	smelt_timer += delta
	progress_bar.value = (smelt_timer / smelt_time) * 100.0

	if smelt_timer >= smelt_time:
		_smelt_one_item()


func _smelt_one_item() -> void:
	# Remove ore
	if not inventory.remove_item_by_id(current_ore_id, 1):
		_finish_smelting()
		return

	# Add bar result
	inventory.add_item(current_recipe.result_id, current_recipe.get("result_amount", 1))

	items_smelted += 1
	smelt_timer = 0.0

	AudioManager.play_sound("smelting_done") if AudioManager.has_method("play_sound") else null

	# Check if done
	if items_smelted >= items_to_smelt or inventory.count_item(current_ore_id) == 0:
		_finish_smelting()
	else:
		_update_status()


func _update_status() -> void:
	status_label.text = "Smelting... %d / %d" % [items_smelted, items_to_smelt]


func _finish_smelting() -> void:
	state = State.COMPLETE
	smelting_panel.visible = false

	var result_def: Dictionary = ItemDatabase.get_item(current_recipe.result_id)
	var result_name: String = result_def.get("name", current_recipe.result_id)

	result_label.text = "Smelted %d %s!" % [items_smelted, result_name]
	result_panel.visible = true

	var results := {
		"item_id": current_recipe.result_id,
		"count": items_smelted
	}
	smelting_complete.emit(results)

	await get_tree().create_timer(2.0).timeout
	_end_smelting()


func _end_smelting() -> void:
	state = State.IDLE
	visible = false
	selection_panel.visible = false
	smelting_panel.visible = false
	result_panel.visible = false


func cancel() -> void:
	if state != State.IDLE:
		state = State.IDLE
		visible = false
		smelting_cancelled.emit()
