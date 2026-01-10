extends RefCounted
class_name ItemStack
## Represents a stack of items in inventory.

var item_id: String
var quantity: int
var instance_id: String


func _init(id: String = "", qty: int = 1) -> void:
	item_id = id
	quantity = qty
	instance_id = _generate_id()


func _generate_id() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())


func get_definition() -> Dictionary:
	return ItemDatabase.get_item(item_id)


func get_name() -> String:
	var def := get_definition()
	return def.get("name", "Unknown")


func get_description() -> String:
	var def := get_definition()
	return def.get("description", "")


func get_rarity() -> int:
	var def := get_definition()
	return def.get("rarity", ItemDatabase.Rarity.COMMON)


func get_rarity_color() -> Color:
	return ItemDatabase.get_rarity_color(get_rarity())


func get_icon() -> String:
	var def := get_definition()
	return def.get("icon", "")


func is_stackable() -> bool:
	var def := get_definition()
	return def.get("stackable", false)


func get_max_stack() -> int:
	var def := get_definition()
	return def.get("max_stack", 1) if is_stackable() else 1


func get_value() -> int:
	var def := get_definition()
	return def.get("value", 0) * quantity


func can_stack_with(other: ItemStack) -> bool:
	if not other:
		return false
	if item_id != other.item_id:
		return false
	if not is_stackable():
		return false
	return quantity + other.quantity <= get_max_stack()


func duplicate_stack() -> ItemStack:
	var new_stack := ItemStack.new(item_id, quantity)
	return new_stack
