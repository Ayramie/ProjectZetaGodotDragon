extends Node
## Recipe database singleton.
## Contains all crafting, smelting, and anvil recipes.

enum RecipeType { CRAFTING, SMELTING, ANVIL, COOKING }

# All recipes
var recipes: Dictionary = {
	RecipeType.CRAFTING: [],
	RecipeType.SMELTING: [],
	RecipeType.ANVIL: [],
	RecipeType.COOKING: []
}


func _ready() -> void:
	_register_all_recipes()


func get_recipes(type: RecipeType) -> Array:
	return recipes[type]


func get_recipe_by_id(recipe_id: String) -> Dictionary:
	for type in recipes:
		for recipe in recipes[type]:
			if recipe.id == recipe_id:
				return recipe
	return {}


func can_craft(recipe: Dictionary, inventory) -> bool:
	for material in recipe.materials:
		if inventory.count_item(material.id) < material.amount:
			return false
	return true


func _register_all_recipes() -> void:
	# === CRAFTING RECIPES (Wood-based) ===
	recipes[RecipeType.CRAFTING].append({
		"id": "craft_oak_shortbow",
		"name": "Oak Shortbow",
		"result_id": "oak_shortbow",
		"result_amount": 1,
		"materials": [
			{"id": "wood_oak", "amount": 5}
		],
		"craft_time": 2.0,
		"icon": "bow_oak"
	})

	recipes[RecipeType.CRAFTING].append({
		"id": "craft_short_staff",
		"name": "Short Staff",
		"result_id": "short_staff",
		"result_amount": 1,
		"materials": [
			{"id": "wood_oak", "amount": 4}
		],
		"craft_time": 2.0,
		"icon": "staff_short"
	})

	recipes[RecipeType.CRAFTING].append({
		"id": "craft_wooden_bow",
		"name": "Wooden Bow",
		"result_id": "wooden_bow",
		"result_amount": 1,
		"materials": [
			{"id": "wood_birch", "amount": 4}
		],
		"craft_time": 2.5,
		"icon": "bow_wood"
	})

	recipes[RecipeType.CRAFTING].append({
		"id": "craft_apprentice_staff",
		"name": "Apprentice Staff",
		"result_id": "apprentice_staff",
		"result_amount": 1,
		"materials": [
			{"id": "wood_birch", "amount": 3},
			{"id": "wood_oak", "amount": 2}
		],
		"craft_time": 3.0,
		"icon": "staff_wood"
	})

	# === SMELTING RECIPES (Ore to Bar) ===
	recipes[RecipeType.SMELTING].append({
		"id": "smelt_copper",
		"name": "Copper Bar",
		"result_id": "bar_copper",
		"result_amount": 1,
		"materials": [
			{"id": "ore_copper", "amount": 1}
		],
		"craft_time": 3.0,
		"icon": "bar_copper"
	})

	recipes[RecipeType.SMELTING].append({
		"id": "smelt_iron",
		"name": "Iron Bar",
		"result_id": "bar_iron",
		"result_amount": 1,
		"materials": [
			{"id": "ore_iron", "amount": 1}
		],
		"craft_time": 3.0,
		"icon": "bar_iron"
	})

	recipes[RecipeType.SMELTING].append({
		"id": "smelt_gold",
		"name": "Gold Bar",
		"result_id": "bar_gold",
		"result_amount": 1,
		"materials": [
			{"id": "ore_gold", "amount": 1}
		],
		"craft_time": 3.0,
		"icon": "bar_gold"
	})

	# === ANVIL RECIPES (Metal Weapons) ===
	recipes[RecipeType.ANVIL].append({
		"id": "forge_copper_shortsword",
		"name": "Copper Shortsword",
		"result_id": "copper_shortsword",
		"result_amount": 1,
		"materials": [
			{"id": "bar_copper", "amount": 3}
		],
		"craft_time": 4.0,
		"icon": "sword_copper"
	})

	recipes[RecipeType.ANVIL].append({
		"id": "forge_copper_dagger",
		"name": "Copper Dagger",
		"result_id": "copper_dagger",
		"result_amount": 1,
		"materials": [
			{"id": "bar_copper", "amount": 2}
		],
		"craft_time": 3.0,
		"icon": "dagger_copper"
	})

	recipes[RecipeType.ANVIL].append({
		"id": "forge_iron_longsword",
		"name": "Iron Longsword",
		"result_id": "iron_longsword",
		"result_amount": 1,
		"materials": [
			{"id": "bar_iron", "amount": 5}
		],
		"craft_time": 5.0,
		"icon": "sword_iron_long"
	})

	recipes[RecipeType.ANVIL].append({
		"id": "forge_gold_scepter",
		"name": "Gold Scepter",
		"result_id": "gold_scepter",
		"result_amount": 1,
		"materials": [
			{"id": "bar_gold", "amount": 4}
		],
		"craft_time": 6.0,
		"icon": "staff_gold"
	})

	recipes[RecipeType.ANVIL].append({
		"id": "forge_iron_sword",
		"name": "Iron Sword",
		"result_id": "iron_sword",
		"result_amount": 1,
		"materials": [
			{"id": "bar_iron", "amount": 3}
		],
		"craft_time": 4.0,
		"icon": "sword_iron"
	})

	recipes[RecipeType.ANVIL].append({
		"id": "forge_steel_sword",
		"name": "Steel Sword",
		"result_id": "steel_sword",
		"result_amount": 1,
		"materials": [
			{"id": "bar_iron", "amount": 4},
			{"id": "bar_copper", "amount": 2}
		],
		"craft_time": 6.0,
		"icon": "sword_steel"
	})

	# === COOKING RECIPES (Fish to Food) ===
	recipes[RecipeType.COOKING].append({
		"id": "cook_grilled_trout",
		"name": "Grilled Trout",
		"result_id": "grilled_trout",
		"result_amount": 1,
		"materials": [
			{"id": "fish_small_trout", "amount": 1}
		],
		"craft_time": 3.0,
		"icon": "food_fish"
	})

	recipes[RecipeType.COOKING].append({
		"id": "cook_grilled_bass",
		"name": "Grilled Bass",
		"result_id": "grilled_bass",
		"result_amount": 1,
		"materials": [
			{"id": "fish_bass", "amount": 1}
		],
		"craft_time": 3.0,
		"icon": "food_fish"
	})

	recipes[RecipeType.COOKING].append({
		"id": "cook_golden_carp_fillet",
		"name": "Golden Carp Fillet",
		"result_id": "golden_carp_fillet",
		"result_amount": 1,
		"materials": [
			{"id": "fish_golden_carp", "amount": 1}
		],
		"craft_time": 4.0,
		"icon": "food_fish_gold"
	})

	recipes[RecipeType.COOKING].append({
		"id": "cook_rainbow_trout_steak",
		"name": "Rainbow Trout Steak",
		"result_id": "rainbow_trout_steak",
		"result_amount": 1,
		"materials": [
			{"id": "fish_rainbow_trout", "amount": 1}
		],
		"craft_time": 5.0,
		"icon": "food_steak"
	})

	recipes[RecipeType.COOKING].append({
		"id": "cook_legendary_koi_feast",
		"name": "Legendary Koi Feast",
		"result_id": "legendary_koi_feast",
		"result_amount": 1,
		"materials": [
			{"id": "fish_legendary_koi", "amount": 1}
		],
		"craft_time": 8.0,
		"icon": "food_feast"
	})
