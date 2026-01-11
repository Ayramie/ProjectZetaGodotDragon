extends InteractableBase
class_name LifeSkillStation
## Base class for life skill stations.
## Handles UI popup management and player validation.

@export var station_type: String = "generic"

var minigame_ui: Control = null
var inventory: Inventory = null


func _ready() -> void:
	super._ready()


func set_ui(ui: Control) -> void:
	minigame_ui = ui


func set_inventory(inv: Inventory) -> void:
	inventory = inv


func _start_interaction() -> void:
	if not minigame_ui:
		push_warning("No UI assigned to station: " + name)
		return

	if not inventory:
		push_warning("No inventory assigned to station: " + name)
		return

	super._start_interaction()
	_open_minigame()


func _open_minigame() -> void:
	## Override in subclass to open specific minigame.
	pass


func _cancel_interaction() -> void:
	if minigame_ui and minigame_ui.has_method("cancel"):
		minigame_ui.cancel()
	super._cancel_interaction()
