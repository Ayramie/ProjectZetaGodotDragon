extends Node
## Shop database singleton - defines shop inventories and prices.
## Each shop has a list of items with buy prices and stock.

# Shop stock: shop_id -> Array of {item_id, buy_price, sell_multiplier, stock}
# stock = -1 means infinite stock
var shops: Dictionary = {}


func _ready() -> void:
	_init_shops()


func _init_shops() -> void:
	# General Store - consumables and basic gear
	shops["general_store"] = [
		{"item_id": "health_potion_small", "buy_price": 25, "sell_multiplier": 0.5, "stock": -1},
		{"item_id": "health_potion_large", "buy_price": 75, "sell_multiplier": 0.5, "stock": -1},
		{"item_id": "speed_potion", "buy_price": 50, "sell_multiplier": 0.5, "stock": 10},
		{"item_id": "strength_potion", "buy_price": 60, "sell_multiplier": 0.5, "stock": 10},
		{"item_id": "torch", "buy_price": 10, "sell_multiplier": 0.3, "stock": -1},
		{"item_id": "rope", "buy_price": 15, "sell_multiplier": 0.3, "stock": 20},
	]

	# Blacksmith - weapons and armor
	shops["blacksmith"] = [
		{"item_id": "iron_sword", "buy_price": 120, "sell_multiplier": 0.5, "stock": 5},
		{"item_id": "steel_sword", "buy_price": 300, "sell_multiplier": 0.5, "stock": 3},
		{"item_id": "iron_axe", "buy_price": 100, "sell_multiplier": 0.5, "stock": 5},
		{"item_id": "leather_vest", "buy_price": 80, "sell_multiplier": 0.4, "stock": 5},
		{"item_id": "leather_boots", "buy_price": 50, "sell_multiplier": 0.4, "stock": 5},
		{"item_id": "chainmail_vest", "buy_price": 250, "sell_multiplier": 0.4, "stock": 2},
		{"item_id": "chainmail_helm", "buy_price": 180, "sell_multiplier": 0.4, "stock": 2},
	]

	# Mage Shop - magic items and scrolls
	shops["mage_shop"] = [
		{"item_id": "mana_potion_small", "buy_price": 30, "sell_multiplier": 0.5, "stock": -1},
		{"item_id": "mana_potion_large", "buy_price": 80, "sell_multiplier": 0.5, "stock": -1},
		{"item_id": "scroll_fireball", "buy_price": 100, "sell_multiplier": 0.3, "stock": 5},
		{"item_id": "scroll_heal", "buy_price": 75, "sell_multiplier": 0.3, "stock": 5},
		{"item_id": "staff_basic", "buy_price": 150, "sell_multiplier": 0.4, "stock": 3},
		{"item_id": "robe_apprentice", "buy_price": 100, "sell_multiplier": 0.4, "stock": 3},
	]

	# Fishing Supplies
	shops["fishing_supplies"] = [
		{"item_id": "fishing_rod_basic", "buy_price": 50, "sell_multiplier": 0.4, "stock": 5},
		{"item_id": "fishing_rod_advanced", "buy_price": 150, "sell_multiplier": 0.4, "stock": 2},
		{"item_id": "bait_worm", "buy_price": 5, "sell_multiplier": 0.2, "stock": -1},
		{"item_id": "bait_special", "buy_price": 15, "sell_multiplier": 0.2, "stock": 20},
	]

	# Mining Supplies
	shops["mining_supplies"] = [
		{"item_id": "pickaxe_iron", "buy_price": 80, "sell_multiplier": 0.4, "stock": 5},
		{"item_id": "pickaxe_steel", "buy_price": 200, "sell_multiplier": 0.4, "stock": 2},
	]


func get_shop(shop_id: String) -> Array:
	## Get all items for a shop.
	return shops.get(shop_id, [])


func get_shop_item(shop_id: String, item_id: String) -> Dictionary:
	## Get a specific item from a shop.
	var shop := get_shop(shop_id)
	for item in shop:
		if item.item_id == item_id:
			return item
	return {}


func get_buy_price(shop_id: String, item_id: String) -> int:
	## Get the buy price for an item at a specific shop.
	var shop_item := get_shop_item(shop_id, item_id)
	if shop_item.is_empty():
		# Default price from item database
		var item_def := ItemDatabase.get_item(item_id)
		return item_def.get("value", 0) * 2
	return shop_item.get("buy_price", 0)


func get_sell_price(item_id: String) -> int:
	## Get the sell price for an item (universal, not shop-specific).
	## Default is 50% of item base value.
	var item_def := ItemDatabase.get_item(item_id)
	var base_value: int = item_def.get("value", 0)
	return int(base_value * 0.5)


func can_buy(shop_id: String, item_id: String) -> bool:
	## Check if an item can be purchased (has stock).
	var shop_item := get_shop_item(shop_id, item_id)
	if shop_item.is_empty():
		return false
	var stock: int = shop_item.get("stock", 0)
	return stock != 0  # -1 = infinite, >0 = has stock


func buy_item(shop_id: String, item_id: String) -> bool:
	## Decrease stock when an item is bought.
	## Returns false if out of stock.
	var shop := get_shop(shop_id)
	for i in shop.size():
		if shop[i].item_id == item_id:
			var stock: int = shop[i].get("stock", 0)
			if stock == 0:
				return false
			if stock > 0:
				shop[i].stock = stock - 1
			return true
	return false


func restock_shop(shop_id: String) -> void:
	## Restock a shop to its initial inventory.
	## Call this periodically or when a new day starts.
	_init_shops()  # For now, just reinitialize


func get_all_shop_ids() -> Array:
	## Get list of all shop IDs.
	return shops.keys()
