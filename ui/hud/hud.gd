extends CanvasLayer
class_name HUD
## Main game HUD controller.
## Updates health, abilities, hotbar, and target display.

@onready var health_bar: ProgressBar = $TopLeft/HealthBar
@onready var health_label: Label = $TopLeft/HealthBar/HealthLabel

@onready var target_frame: PanelContainer = $TopCenter/TargetFrame
@onready var target_name: Label = $TopCenter/TargetFrame/VBox/TargetName
@onready var target_health: ProgressBar = $TopCenter/TargetFrame/VBox/TargetHealth

@onready var ability_slots: Array[PanelContainer] = [
	$BottomCenter/AbilityBar/AbilityQ,
	$BottomCenter/AbilityBar/AbilityF,
	$BottomCenter/AbilityBar/AbilityE,
	$BottomCenter/AbilityBar/AbilityR,
	$BottomCenter/AbilityBar/AbilityC
]

@onready var hotbar_slots: Array[PanelContainer] = [
	$BottomRight/Hotbar1,
	$BottomRight/Hotbar2,
	$BottomRight/Hotbar3,
	$BottomRight/Hotbar4,
	$BottomRight/Hotbar5
]

@onready var gold_display: Label = $BottomRight/GoldDisplay
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var message_display: Label = $MessageDisplay

var player: Player = null
var current_target: Node3D = null
var message_timer: float = 0.0

const ABILITY_KEYS := ["q", "f", "e", "r", "c"]
const ABILITY_COOLDOWNS := {
	"warrior": [4.0, 6.0, 5.0, 10.0, 5.0],
	"mage": [8.0, 6.0, 8.0, 10.0, 5.0],
	"hunter": [6.0, 8.0, 5.0, 12.0, 10.0],
	"adventurer": [4.0, 6.0, 5.0, 10.0, 5.0]
}

const ABILITY_NAMES := {
	"warrior": ["Cleave", "Whirlwind", "Parry", "Heroic Leap", "Sunder"],
	"mage": ["Blizzard", "Flame Wave", "Frost Nova", "Frozen Orb", "Blink"],
	"hunter": ["Arrow Wave", "Spin Dash", "Shotgun", "Trap", "Giant Arrow"],
	"adventurer": ["Slash", "Dash", "Evade", "Ultimate", "Stealth"]
}


func _ready() -> void:
	# Connect to signals
	EventBus.target_changed.connect(_on_target_changed)
	EventBus.target_cleared.connect(_on_target_cleared)
	EventBus.show_message.connect(_on_show_message)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.inventory_changed.connect(_update_hotbar)
	EventBus.hotbar_changed.connect(_update_hotbar)

	# Hide interaction prompt initially
	interaction_prompt.visible = false
	message_display.visible = false


func _process(delta: float) -> void:
	if player:
		_update_health()
		_update_abilities(delta)

	if current_target and is_instance_valid(current_target):
		_update_target()

	# Update message timer
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_display.visible = false


func set_player(p: Player) -> void:
	player = p

	if player:
		player.health_changed.connect(_on_player_health_changed)
		health_bar.max_value = player.max_health
		health_bar.value = player.health
		_update_health_label()
		_setup_ability_names()


func _update_health() -> void:
	if not player:
		return

	health_bar.value = player.health


func _update_health_label() -> void:
	if not player:
		return

	health_label.text = "%d / %d" % [player.health, player.max_health]


func _setup_ability_names() -> void:
	var class_name_lower := GameManager.get_class_name_string().to_lower()
	var names: Array = ABILITY_NAMES.get(class_name_lower, ["Q", "F", "E", "R", "C"])

	for i in ability_slots.size():
		var slot := ability_slots[i]
		var name_label: Label = slot.get_node("VBox/Name")
		if name_label and i < names.size():
			name_label.text = names[i]


func _on_player_health_changed(new_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = new_health
	_update_health_label()


func _update_abilities(_delta: float) -> void:
	if not player:
		return

	var class_name_lower := GameManager.get_class_name_string().to_lower()
	var cooldowns: Array = ABILITY_COOLDOWNS.get(class_name_lower, [4.0, 6.0, 5.0, 10.0, 5.0])

	for i in ability_slots.size():
		var slot := ability_slots[i]
		var key: String = ABILITY_KEYS[i]
		var max_cd: float = cooldowns[i]
		var remaining: float = player.get_ability_cooldown(key)

		var cooldown_overlay: ColorRect = slot.get_node("Cooldown")
		var cooldown_label: Label = slot.get_node("CooldownLabel")

		if remaining > 0:
			cooldown_overlay.visible = true
			cooldown_label.visible = true
			# Scale height based on cooldown remaining
			var percent := remaining / max_cd
			cooldown_overlay.anchor_top = 1.0 - percent
			# Show remaining time
			cooldown_label.text = "%.1f" % remaining
		else:
			cooldown_overlay.visible = false
			cooldown_label.visible = false


func _update_hotbar() -> void:
	# Hotbar update would read from inventory and update visuals
	pass


func _on_target_changed(new_target: Node3D) -> void:
	current_target = new_target
	if current_target:
		target_frame.visible = true
		_update_target()
	else:
		target_frame.visible = false


func _on_target_cleared() -> void:
	current_target = null
	target_frame.visible = false


func _update_target() -> void:
	if not current_target or not is_instance_valid(current_target):
		target_frame.visible = false
		return

	if current_target is EnemyBase:
		var enemy := current_target as EnemyBase
		target_name.text = enemy.name
		target_health.max_value = enemy.max_health
		target_health.value = enemy.health


func _on_show_message(text: String, color: Color, duration: float) -> void:
	message_display.text = text
	message_display.modulate = color
	message_display.visible = true
	message_timer = duration


func _on_gold_changed(amount: int) -> void:
	gold_display.text = "$ %d" % amount


func show_interaction_prompt(text: String) -> void:
	interaction_prompt.text = text
	interaction_prompt.visible = true


func hide_interaction_prompt() -> void:
	interaction_prompt.visible = false
