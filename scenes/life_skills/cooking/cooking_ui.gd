extends Control
class_name CookingUI
## Cooking UI with auto-progress.
## Converts raw fish to cooked food.

signal cooking_complete(results: Dictionary)
signal cooking_cancelled()

enum State { IDLE, SELECTING, COOKING, COMPLETE }

# UI nodes - created programmatically
var selection_panel: PanelContainer
var selection_list: VBoxContainer
var cooking_panel: PanelContainer
var progress_bar: ProgressBar
var status_label: Label
var item_label: Label
var result_panel: PanelContainer
var result_label: Label

var state: State = State.IDLE
var inventory: Inventory = null

# Current cooking state
var current_fish_id: String = ""
var current_recipe: Dictionary = {}
var items_to_cook: int = 0
var items_cooked: int = 0
var cook_timer: float = 0.0
var cook_time: float = 3.0

# Fish types that can be cooked
const COOKABLE_FISH := [
	"fish_small_trout",
	"fish_bass",
	"fish_golden_carp",
	"fish_rainbow_trout",
	"fish_legendary_koi"
]


func _ready() -> void:
	_build_ui()
	visible = false
	selection_panel.visible = false
	cooking_panel.visible = false
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
	sel_title.text = "Cooking - Select Fish"
	sel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel_title.add_theme_font_size_override("font_size", 20)
	sel_vbox.add_child(sel_title)

	selection_list = VBoxContainer.new()
	selection_list.add_theme_constant_override("separation", 8)
	sel_vbox.add_child(selection_list)

	# Cooking panel
	cooking_panel = PanelContainer.new()
	cooking_panel.set_anchors_preset(Control.PRESET_CENTER)
	cooking_panel.custom_minimum_size = Vector2(400, 200)
	cooking_panel.position = -cooking_panel.custom_minimum_size / 2
	add_child(cooking_panel)

	var cook_vbox := VBoxContainer.new()
	cook_vbox.add_theme_constant_override("separation", 15)
	cooking_panel.add_child(cook_vbox)

	item_label = Label.new()
	item_label.text = "Cooking..."
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 20)
	cook_vbox.add_child(item_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(350, 30)
	progress_bar.max_value = 100.0
	cook_vbox.add_child(progress_bar)

	status_label = Label.new()
	status_label.text = "Cooking... 0 / 0"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cook_vbox.add_child(status_label)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(cancel)
	cook_vbox.add_child(cancel_btn)

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


func start_cooking(inv: Inventory) -> void:
	inventory = inv
	visible = true
	state = State.SELECTING
	_build_selection_list()
	selection_panel.visible = true
	cooking_panel.visible = false


func _build_selection_list() -> void:
	# Clear existing items
	for child in selection_list.get_children():
		child.queue_free()

	# Check each cookable fish type
	var has_any := false
	for fish_id in COOKABLE_FISH:
		var count := inventory.count_item(fish_id)
		if count > 0:
			has_any = true
			_add_selection_button(fish_id, count)

	if not has_any:
		var label := Label.new()
		label.text = "No fish to cook!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_list.add_child(label)

	# Add cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(cancel)
	selection_list.add_child(cancel_btn)


func _add_selection_button(fish_id: String, count: int) -> void:
	var item_def: Dictionary = ItemDatabase.get_item(fish_id)
	var fish_name: String = item_def.get("name", fish_id)

	# Find the cooking recipe for this fish
	var recipe := _find_cooking_recipe(fish_id)
	if recipe.is_empty():
		return

	var result_def: Dictionary = ItemDatabase.get_item(recipe.result_id)
	var result_name: String = result_def.get("name", recipe.result_id)

	var btn := Button.new()
	btn.text = "%s x%d → %s" % [fish_name, count, result_name]
	btn.pressed.connect(_on_fish_selected.bind(fish_id, recipe, count))
	selection_list.add_child(btn)


func _find_cooking_recipe(fish_id: String) -> Dictionary:
	var recipes: Array = RecipeDatabase.get_recipes(RecipeDatabase.RecipeType.COOKING)
	for recipe in recipes:
		for material in recipe.materials:
			if material.id == fish_id:
				return recipe
	return {}


func _on_fish_selected(fish_id: String, recipe: Dictionary, count: int) -> void:
	current_fish_id = fish_id
	current_recipe = recipe
	items_to_cook = count
	items_cooked = 0
	cook_timer = 0.0
	cook_time = recipe.get("craft_time", 3.0)

	selection_panel.visible = false
	cooking_panel.visible = true
	state = State.COOKING

	var fish_def: Dictionary = ItemDatabase.get_item(fish_id)
	item_label.text = "Cooking %s..." % fish_def.get("name", fish_id)
	_update_status()


func _process(delta: float) -> void:
	if state != State.COOKING:
		return

	cook_timer += delta
	progress_bar.value = (cook_timer / cook_time) * 100.0

	if cook_timer >= cook_time:
		_cook_one_item()


func _cook_one_item() -> void:
	# Remove raw fish
	if not inventory.remove_item_by_id(current_fish_id, 1):
		_finish_cooking()
		return

	# Add cooked result
	inventory.add_item(current_recipe.result_id, current_recipe.get("result_amount", 1))

	items_cooked += 1
	cook_timer = 0.0

	AudioManager.play_sound("cooking_done") if AudioManager.has_method("play_sound") else null

	# Check if done
	if items_cooked >= items_to_cook or inventory.count_item(current_fish_id) == 0:
		_finish_cooking()
	else:
		_update_status()


func _update_status() -> void:
	status_label.text = "Cooking... %d / %d" % [items_cooked, items_to_cook]


func _finish_cooking() -> void:
	state = State.COMPLETE
	cooking_panel.visible = false

	var result_def: Dictionary = ItemDatabase.get_item(current_recipe.result_id)
	var result_name: String = result_def.get("name", current_recipe.result_id)

	result_label.text = "Cooked %d %s!" % [items_cooked, result_name]
	result_panel.visible = true

	var results := {
		"item_id": current_recipe.result_id,
		"count": items_cooked
	}
	cooking_complete.emit(results)

	await get_tree().create_timer(2.0).timeout
	_end_cooking()


func _end_cooking() -> void:
	state = State.IDLE
	visible = false
	selection_panel.visible = false
	cooking_panel.visible = false
	result_panel.visible = false


func cancel() -> void:
	if state != State.IDLE:
		state = State.IDLE
		visible = false
		cooking_cancelled.emit()
