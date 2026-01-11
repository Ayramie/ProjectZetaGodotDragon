extends NPC
class_name ShopkeeperNPC
## Shopkeeper NPC that opens a shop UI when interacted.

@export var shop_id: String = "general_store"
@export var shop_display_name: String = ""
@export var greeting: String = "Welcome! Take a look at my wares."

var shop_ui: ShopUI = null


func _ready() -> void:
	is_shopkeeper = true
	dialogue_lines = [greeting]
	super._ready()


func _start_interaction() -> void:
	# If we have a shop UI reference, open the shop
	if shop_ui and GameManager.inventory:
		var display_name := shop_display_name if not shop_display_name.is_empty() else npc_name + "'s Shop"
		shop_ui.open(shop_id, GameManager.inventory, display_name)
	else:
		# Fallback to regular dialogue if no shop UI
		EventBus.show_message.emit(npc_name + ": " + greeting, Color.WHITE, 3.0)
		super._start_interaction()


func set_shop_ui(ui: ShopUI) -> void:
	shop_ui = ui
