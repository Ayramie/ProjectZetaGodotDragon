extends NPC
class_name HealerNPC
## Healer NPC that restores player health for gold.

@export var heal_cost_per_hp: float = 0.5  # Gold per HP healed
@export var minimum_cost: int = 10

var dialogue_ui: DialogueUI = null


func _ready() -> void:
	npc_name = "Healer"
	dialogue_lines = ["I can mend your wounds... for a price."]
	super._ready()


func _start_interaction() -> void:
	var player := GameManager.player
	if not player:
		EventBus.show_message.emit("No one to heal.", Color.YELLOW, 2.0)
		return

	var missing_hp: int = player.max_health - player.health
	if missing_hp <= 0:
		EventBus.show_message.emit(npc_name + ": You are already in perfect health!", Color.GREEN, 2.0)
		return

	var heal_cost: int = max(minimum_cost, int(missing_hp * heal_cost_per_hp))

	if dialogue_ui:
		# Use dialogue UI for choice
		dialogue_ui.open(npc_name, self)
		var lines := [
			{
				"text": "You are missing %d health. I can restore it for %d gold. Do you wish to be healed?" % [missing_hp, heal_cost],
				"choices": [
					{"text": "Yes, heal me.", "action": "heal"},
					{"text": "No, thank you.", "action": "cancel"}
				]
			}
		]
		dialogue_ui.show_dialogue(lines)
		dialogue_ui.dialogue_choice_made.connect(_on_heal_choice.bind(heal_cost), CONNECT_ONE_SHOT)
	else:
		# Direct heal without UI - show message and heal if player has gold
		_try_heal(heal_cost, missing_hp)


func _on_heal_choice(choice_index: int, heal_cost: int) -> void:
	if choice_index == 0:
		var player := GameManager.player
		if player:
			var missing_hp: int = player.max_health - player.health
			_try_heal(heal_cost, missing_hp)


func _try_heal(cost: int, missing_hp: int) -> void:
	if not GameManager.inventory:
		EventBus.show_message.emit("Cannot access your gold.", Color.RED, 2.0)
		return

	if GameManager.inventory.gold < cost:
		EventBus.show_message.emit(npc_name + ": You don't have enough gold.", Color.RED, 2.0)
		AudioManager.play_sound("error")
		return

	# Deduct gold and heal
	GameManager.inventory.remove_gold(cost)
	GameManager.player.heal(missing_hp)

	EventBus.show_message.emit(npc_name + ": You have been healed!", Color.GREEN, 2.0)
	AudioManager.play_sound("heal")


func set_dialogue_ui(ui: DialogueUI) -> void:
	dialogue_ui = ui
