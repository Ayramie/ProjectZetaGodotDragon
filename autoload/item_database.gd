extends Node
## Item database singleton.
## Contains all item definitions and provides lookup functions.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }
enum ItemType { CONSUMABLE, WEAPON, ARMOR, ACCESSORY, MATERIAL, QUEST }
enum EquipSlot { NONE = -1, WEAPON, HELMET, CHEST, GLOVES, BOOTS, RING, AMULET }

# Rarity colors
const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.67, 0.67, 0.67),
	Rarity.UNCOMMON: Color(0.27, 1.0, 0.27),
	Rarity.RARE: Color(0.27, 0.53, 1.0),
	Rarity.EPIC: Color(0.67, 0.27, 1.0)
}

# All items dictionary
var items: Dictionary = {}


func _ready() -> void:
	_register_all_items()


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_rarity_color(rarity: Rarity) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func get_rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
	return "Unknown"


func get_items_by_type(type: ItemType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items.values():
		if item.type == type:
			result.append(item)
	return result


func _register_all_items() -> void:
	# === CONSUMABLES ===
	_register_item({
		"id": "health_potion_small",
		"name": "Small Health Potion",
		"description": "Restores 50 health.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.COMMON,
		"icon": "potion_red",
		"stackable": true,
		"max_stack": 20,
		"value": 25,
		"cooldown": 1.0,
		"heal_amount": 50
	})

	_register_item({
		"id": "health_potion_large",
		"name": "Large Health Potion",
		"description": "Restores 120 health.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.UNCOMMON,
		"icon": "potion_red_large",
		"stackable": true,
		"max_stack": 20,
		"value": 75,
		"cooldown": 1.0,
		"heal_amount": 120
	})

	_register_item({
		"id": "infinite_health_potion",
		"name": "Infinite Health Potion",
		"description": "Restores 100 health. Never runs out!",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.EPIC,
		"icon": "potion_red_infinite",
		"stackable": false,
		"value": 500,
		"cooldown": 10.0,
		"heal_amount": 100,
		"infinite": true
	})

	_register_item({
		"id": "speed_potion",
		"name": "Speed Potion",
		"description": "Increases movement speed by 50% for 10 seconds.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.UNCOMMON,
		"icon": "potion_blue",
		"stackable": true,
		"max_stack": 10,
		"value": 50,
		"cooldown": 30.0,
		"buff_type": "speed",
		"buff_multiplier": 1.5,
		"buff_duration": 10.0
	})

	_register_item({
		"id": "damage_potion",
		"name": "Damage Potion",
		"description": "Increases damage by 25% for 15 seconds.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.RARE,
		"icon": "potion_orange",
		"stackable": true,
		"max_stack": 10,
		"value": 100,
		"cooldown": 45.0,
		"buff_type": "damage",
		"buff_multiplier": 1.25,
		"buff_duration": 15.0
	})

	_register_item({
		"id": "defense_potion",
		"name": "Defense Potion",
		"description": "Reduces damage taken by 30% for 12 seconds.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.RARE,
		"icon": "potion_green",
		"stackable": true,
		"max_stack": 10,
		"value": 100,
		"cooldown": 45.0,
		"buff_type": "defense",
		"buff_multiplier": 0.7,
		"buff_duration": 12.0
	})

	# === WARRIOR WEAPONS ===
	_register_item({
		"id": "iron_sword",
		"name": "Iron Sword",
		"description": "A sturdy iron sword.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "sword_iron",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["warrior", "adventurer"],
		"value": 100,
		"damage": 10,
		"attack_speed": 5
	})

	_register_item({
		"id": "steel_sword",
		"name": "Steel Sword",
		"description": "A sharp steel blade.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"icon": "sword_steel",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["warrior", "adventurer"],
		"value": 250,
		"damage": 18,
		"attack_speed": 5
	})

	_register_item({
		"id": "bone_cleaver",
		"name": "Bone Cleaver",
		"description": "A massive blade made from monster bones.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.RARE,
		"icon": "sword_bone",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["warrior", "adventurer"],
		"value": 500,
		"damage": 28,
		"attack_speed": 3
	})

	_register_item({
		"id": "copper_shortsword",
		"name": "Copper Shortsword",
		"description": "A short sword forged from copper.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "sword_copper",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["warrior", "adventurer"],
		"value": 75,
		"damage": 7,
		"attack_speed": 8
	})

	_register_item({
		"id": "iron_longsword",
		"name": "Iron Longsword",
		"description": "A long iron blade with extended reach.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"icon": "sword_iron_long",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["warrior", "adventurer"],
		"value": 300,
		"damage": 12,
		"attack_speed": 5
	})

	# === MAGE WEAPONS ===
	_register_item({
		"id": "apprentice_staff",
		"name": "Apprentice Staff",
		"description": "A basic staff for novice mages.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "staff_wood",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["mage", "adventurer"],
		"value": 100,
		"damage": 8,
		"magic_power": 10
	})

	_register_item({
		"id": "crystal_staff",
		"name": "Crystal Staff",
		"description": "A staff topped with a magical crystal.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"icon": "staff_crystal",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["mage", "adventurer"],
		"value": 300,
		"damage": 12,
		"magic_power": 20
	})

	_register_item({
		"id": "dark_scepter",
		"name": "Dark Scepter",
		"description": "A scepter imbued with dark energy.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.RARE,
		"icon": "staff_dark",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["mage", "adventurer"],
		"value": 600,
		"damage": 18,
		"magic_power": 35
	})

	_register_item({
		"id": "short_staff",
		"name": "Short Staff",
		"description": "A compact staff crafted from oak wood.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "staff_short",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["mage", "adventurer"],
		"value": 80,
		"damage": 8,
		"magic_power": 15
	})

	_register_item({
		"id": "gold_scepter",
		"name": "Gold Scepter",
		"description": "A magnificent golden scepter radiating power.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.RARE,
		"icon": "staff_gold",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["mage", "adventurer"],
		"value": 800,
		"damage": 10,
		"magic_power": 30
	})

	# === HUNTER WEAPONS ===
	_register_item({
		"id": "wooden_bow",
		"name": "Wooden Bow",
		"description": "A simple wooden hunting bow.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "bow_wood",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["hunter", "adventurer"],
		"value": 80,
		"damage": 8,
		"attack_speed": 8
	})

	_register_item({
		"id": "hunters_crossbow",
		"name": "Hunter's Crossbow",
		"description": "A powerful crossbow for skilled hunters.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"icon": "crossbow",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["hunter", "adventurer"],
		"value": 250,
		"damage": 15,
		"attack_speed": 5
	})

	_register_item({
		"id": "shadow_repeater",
		"name": "Shadow Repeater",
		"description": "A rapid-fire crossbow shrouded in shadow.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.RARE,
		"icon": "crossbow_shadow",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["hunter", "adventurer"],
		"value": 550,
		"damage": 12,
		"attack_speed": 12
	})

	_register_item({
		"id": "oak_shortbow",
		"name": "Oak Shortbow",
		"description": "A light bow crafted from oak wood.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "bow_oak",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["hunter", "adventurer"],
		"value": 60,
		"damage": 6,
		"attack_speed": 8
	})

	_register_item({
		"id": "copper_dagger",
		"name": "Copper Dagger",
		"description": "A quick copper dagger for swift strikes.",
		"type": ItemType.WEAPON,
		"rarity": Rarity.COMMON,
		"icon": "dagger_copper",
		"equip_slot": EquipSlot.WEAPON,
		"class_restriction": ["hunter", "adventurer"],
		"value": 50,
		"damage": 4,
		"attack_speed": 15
	})

	# === ARMOR - HELMETS ===
	_register_item({
		"id": "leather_cap",
		"name": "Leather Cap",
		"description": "A simple leather cap.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.COMMON,
		"icon": "helmet_leather",
		"equip_slot": EquipSlot.HELMET,
		"value": 50,
		"defense": 3
	})

	_register_item({
		"id": "chainmail_helm",
		"name": "Chainmail Helm",
		"description": "A sturdy chainmail helmet.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"icon": "helmet_chain",
		"equip_slot": EquipSlot.HELMET,
		"value": 150,
		"defense": 8
	})

	_register_item({
		"id": "skull_helm",
		"name": "Skull Helm",
		"description": "A helm fashioned from a monster skull.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.RARE,
		"icon": "helmet_skull",
		"equip_slot": EquipSlot.HELMET,
		"value": 400,
		"defense": 15,
		"max_health": 25
	})

	# === ARMOR - CHEST ===
	_register_item({
		"id": "leather_vest",
		"name": "Leather Vest",
		"description": "A basic leather vest.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.COMMON,
		"icon": "chest_leather",
		"equip_slot": EquipSlot.CHEST,
		"value": 75,
		"defense": 5
	})

	_register_item({
		"id": "chainmail_vest",
		"name": "Chainmail Vest",
		"description": "A protective chainmail vest.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"icon": "chest_chain",
		"equip_slot": EquipSlot.CHEST,
		"value": 200,
		"defense": 12
	})

	_register_item({
		"id": "bone_plate",
		"name": "Bone Plate Armor",
		"description": "Heavy armor crafted from monster bones.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.RARE,
		"icon": "chest_bone",
		"equip_slot": EquipSlot.CHEST,
		"value": 500,
		"defense": 22,
		"max_health": 50
	})

	# === ARMOR - GLOVES ===
	_register_item({
		"id": "leather_gloves",
		"name": "Leather Gloves",
		"description": "Simple leather gloves.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.COMMON,
		"icon": "gloves_leather",
		"equip_slot": EquipSlot.GLOVES,
		"value": 40,
		"defense": 2
	})

	_register_item({
		"id": "chain_gauntlets",
		"name": "Chain Gauntlets",
		"description": "Reinforced chain gauntlets.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"icon": "gloves_chain",
		"equip_slot": EquipSlot.GLOVES,
		"value": 120,
		"defense": 6,
		"attack_speed": 2
	})

	# === ARMOR - BOOTS ===
	_register_item({
		"id": "leather_boots",
		"name": "Leather Boots",
		"description": "Comfortable leather boots.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.COMMON,
		"icon": "boots_leather",
		"equip_slot": EquipSlot.BOOTS,
		"value": 45,
		"defense": 2
	})

	_register_item({
		"id": "swift_boots",
		"name": "Swift Boots",
		"description": "Lightweight boots for quick movement.",
		"type": ItemType.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"icon": "boots_swift",
		"equip_slot": EquipSlot.BOOTS,
		"value": 180,
		"defense": 4,
		"move_speed": 1
	})

	# === ACCESSORIES - RINGS ===
	_register_item({
		"id": "copper_ring",
		"name": "Copper Ring",
		"description": "A simple copper ring.",
		"type": ItemType.ACCESSORY,
		"rarity": Rarity.COMMON,
		"icon": "ring_copper",
		"equip_slot": EquipSlot.RING,
		"value": 30,
		"max_health": 10
	})

	_register_item({
		"id": "silver_ring",
		"name": "Silver Ring",
		"description": "A polished silver ring.",
		"type": ItemType.ACCESSORY,
		"rarity": Rarity.UNCOMMON,
		"icon": "ring_silver",
		"equip_slot": EquipSlot.RING,
		"value": 100,
		"max_health": 25,
		"magic_power": 5
	})

	_register_item({
		"id": "bone_ring",
		"name": "Bone Ring",
		"description": "A ring carved from monster bone.",
		"type": ItemType.ACCESSORY,
		"rarity": Rarity.RARE,
		"icon": "ring_bone",
		"equip_slot": EquipSlot.RING,
		"value": 300,
		"damage": 5,
		"max_health": 30
	})

	# === ACCESSORIES - AMULETS ===
	_register_item({
		"id": "wooden_charm",
		"name": "Wooden Charm",
		"description": "A simple wooden charm.",
		"type": ItemType.ACCESSORY,
		"rarity": Rarity.COMMON,
		"icon": "amulet_wood",
		"equip_slot": EquipSlot.AMULET,
		"value": 35,
		"defense": 2
	})

	_register_item({
		"id": "skull_pendant",
		"name": "Skull Pendant",
		"description": "A pendant with a tiny skull.",
		"type": ItemType.ACCESSORY,
		"rarity": Rarity.RARE,
		"icon": "amulet_skull",
		"equip_slot": EquipSlot.AMULET,
		"value": 350,
		"damage": 8,
		"defense": 5
	})

	# === MATERIALS - FISH ===
	_register_item({
		"id": "fish_small_trout",
		"name": "Small Trout",
		"description": "A small freshwater trout.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.COMMON,
		"icon": "fish_trout",
		"stackable": true,
		"max_stack": 99,
		"value": 5
	})

	_register_item({
		"id": "fish_bass",
		"name": "Bass",
		"description": "A common bass fish.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.COMMON,
		"icon": "fish_bass",
		"stackable": true,
		"max_stack": 99,
		"value": 8
	})

	_register_item({
		"id": "fish_golden_carp",
		"name": "Golden Carp",
		"description": "A rare golden carp.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.UNCOMMON,
		"icon": "fish_gold",
		"stackable": true,
		"max_stack": 99,
		"value": 25
	})

	_register_item({
		"id": "fish_rainbow_trout",
		"name": "Rainbow Trout",
		"description": "A beautiful rainbow-colored trout.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.RARE,
		"icon": "fish_rainbow",
		"stackable": true,
		"max_stack": 99,
		"value": 50
	})

	_register_item({
		"id": "fish_legendary_koi",
		"name": "Legendary Koi",
		"description": "An extremely rare legendary koi fish.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.EPIC,
		"icon": "fish_koi",
		"stackable": true,
		"max_stack": 99,
		"value": 200
	})

	# === MATERIALS - ORE ===
	_register_item({
		"id": "ore_copper",
		"name": "Copper Ore",
		"description": "Raw copper ore from the mines.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.COMMON,
		"icon": "ore_copper",
		"stackable": true,
		"max_stack": 99,
		"value": 10
	})

	_register_item({
		"id": "ore_iron",
		"name": "Iron Ore",
		"description": "Raw iron ore from the mines.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.UNCOMMON,
		"icon": "ore_iron",
		"stackable": true,
		"max_stack": 99,
		"value": 25
	})

	_register_item({
		"id": "ore_gold",
		"name": "Gold Ore",
		"description": "Precious gold ore from deep in the mines.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.RARE,
		"icon": "ore_gold",
		"stackable": true,
		"max_stack": 99,
		"value": 75
	})

	# === MATERIALS - BARS ===
	_register_item({
		"id": "bar_copper",
		"name": "Copper Bar",
		"description": "A smelted copper bar.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.COMMON,
		"icon": "bar_copper",
		"stackable": true,
		"max_stack": 99,
		"value": 25
	})

	_register_item({
		"id": "bar_iron",
		"name": "Iron Bar",
		"description": "A smelted iron bar.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.UNCOMMON,
		"icon": "bar_iron",
		"stackable": true,
		"max_stack": 99,
		"value": 60
	})

	_register_item({
		"id": "bar_gold",
		"name": "Gold Bar",
		"description": "A smelted gold bar.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.RARE,
		"icon": "bar_gold",
		"stackable": true,
		"max_stack": 99,
		"value": 175
	})

	# === MATERIALS - WOOD ===
	_register_item({
		"id": "wood_oak",
		"name": "Oak Wood",
		"description": "Sturdy oak wood from the forest.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.COMMON,
		"icon": "wood_oak",
		"stackable": true,
		"max_stack": 99,
		"value": 8
	})

	_register_item({
		"id": "wood_birch",
		"name": "Birch Wood",
		"description": "Light birch wood with a pale color.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.UNCOMMON,
		"icon": "wood_birch",
		"stackable": true,
		"max_stack": 99,
		"value": 15
	})

	_register_item({
		"id": "wood_mahogany",
		"name": "Mahogany Wood",
		"description": "Rich, dark mahogany wood.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.RARE,
		"icon": "wood_mahogany",
		"stackable": true,
		"max_stack": 99,
		"value": 40
	})

	# === MATERIALS - OTHER ===
	_register_item({
		"id": "bone_fragment",
		"name": "Bone Fragment",
		"description": "A fragment of monster bone.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.COMMON,
		"icon": "bone",
		"stackable": true,
		"max_stack": 99,
		"value": 5
	})

	_register_item({
		"id": "dark_essence",
		"name": "Dark Essence",
		"description": "A swirling orb of dark energy.",
		"type": ItemType.MATERIAL,
		"rarity": Rarity.RARE,
		"icon": "essence_dark",
		"stackable": true,
		"max_stack": 99,
		"value": 100
	})

	_register_item({
		"id": "skeleton_key",
		"name": "Skeleton Key",
		"description": "A mysterious key found on skeletons.",
		"type": ItemType.QUEST,
		"rarity": Rarity.UNCOMMON,
		"icon": "key",
		"stackable": true,
		"max_stack": 10,
		"value": 50
	})

	# === COOKED FOOD ===
	_register_item({
		"id": "grilled_trout",
		"name": "Grilled Trout",
		"description": "A delicious grilled trout. Restores 30 health.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.COMMON,
		"icon": "food_fish",
		"stackable": true,
		"max_stack": 20,
		"value": 15,
		"cooldown": 1.0,
		"heal_amount": 30
	})

	_register_item({
		"id": "grilled_bass",
		"name": "Grilled Bass",
		"description": "A tasty grilled bass. Restores 40 health.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.COMMON,
		"icon": "food_fish",
		"stackable": true,
		"max_stack": 20,
		"value": 20,
		"cooldown": 1.0,
		"heal_amount": 40
	})

	_register_item({
		"id": "golden_carp_fillet",
		"name": "Golden Carp Fillet",
		"description": "A gourmet golden carp fillet. Restores 60 health.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.UNCOMMON,
		"icon": "food_fish_gold",
		"stackable": true,
		"max_stack": 20,
		"value": 50,
		"cooldown": 1.0,
		"heal_amount": 60
	})

	_register_item({
		"id": "rainbow_trout_steak",
		"name": "Rainbow Trout Steak",
		"description": "A premium rainbow trout steak. Restores 100 health.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.RARE,
		"icon": "food_steak",
		"stackable": true,
		"max_stack": 20,
		"value": 100,
		"cooldown": 1.0,
		"heal_amount": 100
	})

	_register_item({
		"id": "legendary_koi_feast",
		"name": "Legendary Koi Feast",
		"description": "An exquisite koi feast. Restores 150 health and grants 10% damage for 30s.",
		"type": ItemType.CONSUMABLE,
		"rarity": Rarity.EPIC,
		"icon": "food_feast",
		"stackable": true,
		"max_stack": 10,
		"value": 400,
		"cooldown": 1.0,
		"heal_amount": 150,
		"buff_type": "damage",
		"buff_multiplier": 1.1,
		"buff_duration": 30.0
	})


func _register_item(item_data: Dictionary) -> void:
	# Set defaults for optional fields
	if not item_data.has("stackable"):
		item_data["stackable"] = false
	if not item_data.has("max_stack"):
		item_data["max_stack"] = 1 if not item_data["stackable"] else 99
	if not item_data.has("value"):
		item_data["value"] = 0
	if not item_data.has("damage"):
		item_data["damage"] = 0
	if not item_data.has("defense"):
		item_data["defense"] = 0
	if not item_data.has("max_health"):
		item_data["max_health"] = 0
	if not item_data.has("attack_speed"):
		item_data["attack_speed"] = 0
	if not item_data.has("magic_power"):
		item_data["magic_power"] = 0
	if not item_data.has("move_speed"):
		item_data["move_speed"] = 0
	if not item_data.has("equip_slot"):
		item_data["equip_slot"] = EquipSlot.NONE
	if not item_data.has("class_restriction"):
		item_data["class_restriction"] = []

	items[item_data["id"]] = item_data
