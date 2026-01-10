extends Control
## Main menu screen with class and mode selection.

@onready var warrior_btn: Button = $VBoxContainer/ClassButtons/WarriorBtn
@onready var mage_btn: Button = $VBoxContainer/ClassButtons/MageBtn
@onready var hunter_btn: Button = $VBoxContainer/ClassButtons/HunterBtn
@onready var adventurer_btn: Button = $VBoxContainer/ClassButtons/AdventurerBtn

@onready var adventure_btn: Button = $VBoxContainer/ModeButtons/AdventureBtn
@onready var horde_btn: Button = $VBoxContainer/ModeButtons/HordeBtn

@onready var start_btn: Button = $VBoxContainer/StartBtn

var selected_class: GameManager.PlayerClass = GameManager.PlayerClass.WARRIOR
var selected_mode: GameManager.GameMode = GameManager.GameMode.ADVENTURE

const SELECTED_COLOR := Color(0.3, 0.6, 1.0)
const UNSELECTED_COLOR := Color(1.0, 1.0, 1.0)


func _ready() -> void:
	# Connect class buttons
	warrior_btn.pressed.connect(_on_class_selected.bind(GameManager.PlayerClass.WARRIOR))
	mage_btn.pressed.connect(_on_class_selected.bind(GameManager.PlayerClass.MAGE))
	hunter_btn.pressed.connect(_on_class_selected.bind(GameManager.PlayerClass.HUNTER))
	adventurer_btn.pressed.connect(_on_class_selected.bind(GameManager.PlayerClass.ADVENTURER))

	# Connect mode buttons
	adventure_btn.pressed.connect(_on_mode_selected.bind(GameManager.GameMode.ADVENTURE))
	horde_btn.pressed.connect(_on_mode_selected.bind(GameManager.GameMode.HORDE))

	# Connect start button
	start_btn.pressed.connect(_on_start_pressed)

	# Set initial selection visuals
	_update_class_buttons()
	_update_mode_buttons()


func _on_class_selected(player_class: GameManager.PlayerClass) -> void:
	selected_class = player_class
	_update_class_buttons()
	AudioManager.play_sound("button_click")


func _on_mode_selected(mode: GameManager.GameMode) -> void:
	selected_mode = mode
	_update_mode_buttons()
	AudioManager.play_sound("button_click")


func _on_start_pressed() -> void:
	AudioManager.play_sound("button_click")

	# Set selections in game manager
	GameManager.set_player_class(selected_class)
	GameManager.set_game_mode(selected_mode)

	# Start the game
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _update_class_buttons() -> void:
	_set_button_selected(warrior_btn, selected_class == GameManager.PlayerClass.WARRIOR)
	_set_button_selected(mage_btn, selected_class == GameManager.PlayerClass.MAGE)
	_set_button_selected(hunter_btn, selected_class == GameManager.PlayerClass.HUNTER)
	_set_button_selected(adventurer_btn, selected_class == GameManager.PlayerClass.ADVENTURER)


func _update_mode_buttons() -> void:
	_set_button_selected(adventure_btn, selected_mode == GameManager.GameMode.ADVENTURE)
	_set_button_selected(horde_btn, selected_mode == GameManager.GameMode.HORDE)


func _set_button_selected(btn: Button, is_selected: bool) -> void:
	if is_selected:
		btn.modulate = SELECTED_COLOR
	else:
		btn.modulate = UNSELECTED_COLOR
