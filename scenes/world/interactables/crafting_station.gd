extends Interactable
class_name CraftingStation
## Base class for crafting stations (forge, anvil, cooking pot, etc.)

signal crafting_started(recipe: Dictionary)
signal crafting_completed(recipe: Dictionary)
signal crafting_failed(reason: String)

@export var station_type: RecipeDatabase.RecipeType = RecipeDatabase.RecipeType.CRAFTING
@export var station_name: String = "Crafting Table"

var available_recipes: Array = []
var current_recipe: Dictionary = {}
var is_crafting: bool = false
var craft_timer: float = 0.0


func _ready() -> void:
	one_time_use = false
	interaction_text = "Press F to use " + station_name
	super._ready()

	# Get available recipes for this station type
	available_recipes = RecipeDatabase.get_recipes_by_type(station_type)


func _process(delta: float) -> void:
	super._process(delta)

	# Update crafting timer
	if is_crafting and craft_timer > 0:
		craft_timer -= delta
		if craft_timer <= 0:
			_complete_crafting()


func interact(player: Node3D) -> void:
	# Open crafting UI
	_open_crafting_ui()
	interacted.emit(player)


func _open_crafting_ui() -> void:
	# This would open a crafting UI panel
	# For now, show available recipes as messages
	EventBus.show_message.emit("Opening " + station_name + "...", Color.WHITE, 1.0)

	# Emit signal for UI to handle
	# In a full implementation, this would trigger a crafting panel


func can_craft(recipe: Dictionary) -> bool:
	## Check if player has all required materials.
	if not GameManager.inventory:
		return false

	var ingredients: Array = recipe.get("ingredients", [])
	for ingredient in ingredients:
		var item_id: String = ingredient.id
		var amount: int = ingredient.amount
		if not GameManager.inventory.has_item(item_id, amount):
			return false

	return true


func start_crafting(recipe: Dictionary) -> bool:
	## Start crafting a recipe.
	if is_crafting:
		crafting_failed.emit("Already crafting")
		return false

	if not can_craft(recipe):
		crafting_failed.emit("Missing materials")
		return false

	# Consume ingredients
	var ingredients: Array = recipe.get("ingredients", [])
	for ingredient in ingredients:
		GameManager.inventory.remove_item_by_id(ingredient.id, ingredient.amount)

	# Start crafting
	current_recipe = recipe
	is_crafting = true
	craft_timer = recipe.get("craft_time", 1.0)

	crafting_started.emit(recipe)
	_play_crafting_effect()

	return true


func _complete_crafting() -> void:
	if current_recipe.is_empty():
		return

	is_crafting = false

	# Add result to inventory
	var result_id: String = current_recipe.get("result", "")
	var result_amount: int = current_recipe.get("result_amount", 1)

	if not result_id.is_empty() and GameManager.inventory:
		var overflow: int = GameManager.inventory.add_item(result_id, result_amount)

		if overflow == 0:
			var item_def: Dictionary = ItemDatabase.get_item(result_id)
			var item_name: String = item_def.get("name", result_id.replace("_", " ").capitalize())
			EventBus.show_message.emit("Crafted: " + item_name, Color.GREEN, 2.0)
			crafting_completed.emit(current_recipe)
		else:
			# Return some ingredients if inventory full
			EventBus.show_message.emit("Inventory full!", Color.RED, 2.0)
			crafting_failed.emit("Inventory full")

	_play_completion_effect()
	current_recipe = {}


func _play_crafting_effect() -> void:
	AudioManager.play_sound_3d("crafting_start", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP, 8)


func _play_completion_effect() -> void:
	AudioManager.play_sound_3d("crafting_complete", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP, 15)


func get_available_recipes() -> Array:
	## Returns recipes the player can currently craft.
	var craftable: Array = []
	for recipe in available_recipes:
		if can_craft(recipe):
			craftable.append(recipe)
	return craftable


func get_all_recipes() -> Array:
	## Returns all recipes for this station.
	return available_recipes
