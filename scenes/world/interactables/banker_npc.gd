extends NPC
class_name BankerNPC
## Banker NPC that opens bank storage UI.

var bank_ui: BankUI = null


func _ready() -> void:
	npc_name = "Banker"
	dialogue_lines = ["Your valuables are safe with me."]
	super._ready()


func _start_interaction() -> void:
	if bank_ui and GameManager.player_bank and GameManager.inventory:
		bank_ui.open(GameManager.player_bank, GameManager.inventory)
	else:
		# Fallback if bank system not set up
		EventBus.show_message.emit(npc_name + ": The bank is currently closed.", Color.YELLOW, 2.0)


func set_bank_ui(ui: BankUI) -> void:
	bank_ui = ui
