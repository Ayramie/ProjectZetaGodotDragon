extends Control
class_name DialogueUI
## Dialogue UI for NPC conversations.
## Supports text display and choice selections.

signal dialogue_choice_made(choice_index: int)
signal dialogue_closed()

var panel: PanelContainer = null
var name_label: Label = null
var text_label: RichTextLabel = null
var choices_container: VBoxContainer = null
var continue_hint: Label = null

var current_npc: Node3D = null
var dialogue_lines: Array = []
var current_line_index: int = 0
var is_open: bool = false


func _ready() -> void:
	_build_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.3)
	add_child(bg)

	# Main panel at bottom of screen
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -200
	panel.offset_bottom = -20
	panel.offset_left = 50
	panel.offset_right = -50
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# NPC name
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Dialogue text
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size = Vector2(0, 60)
	text_label.add_theme_font_size_override("normal_font_size", 18)
	vbox.add_child(text_label)

	# Choices container
	choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 8)
	vbox.add_child(choices_container)

	# Continue hint
	continue_hint = Label.new()
	continue_hint.text = "Press F or Enter to continue..."
	continue_hint.add_theme_font_size_override("font_size", 14)
	continue_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(continue_hint)


func open(npc_name: String, npc: Node3D = null) -> void:
	current_npc = npc
	name_label.text = npc_name
	is_open = true
	visible = true
	GameManager.set_game_state(GameManager.GameState.PAUSED)
	EventBus.dialogue_started.emit(npc)


func show_dialogue(lines: Array) -> void:
	dialogue_lines = lines
	current_line_index = 0
	_display_current_line()


func show_single_line(text: String) -> void:
	dialogue_lines = [text]
	current_line_index = 0
	_display_current_line()


func _display_current_line() -> void:
	if current_line_index >= dialogue_lines.size():
		close()
		return

	var line = dialogue_lines[current_line_index]

	if line is String:
		# Simple text line
		text_label.text = line
		_clear_choices()
		continue_hint.visible = true
	elif line is Dictionary:
		# Line with potential choices
		text_label.text = line.get("text", "")

		if line.has("choices") and line.choices is Array and line.choices.size() > 0:
			_show_choices(line.choices)
			continue_hint.visible = false
		else:
			_clear_choices()
			continue_hint.visible = true


func _show_choices(choices: Array) -> void:
	_clear_choices()

	for i in choices.size():
		var choice = choices[i]
		var btn := Button.new()

		if choice is String:
			btn.text = str(i + 1) + ". " + choice
		elif choice is Dictionary:
			btn.text = str(i + 1) + ". " + choice.get("text", "Option " + str(i + 1))

		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)

	# Focus first choice
	if choices_container.get_child_count() > 0:
		choices_container.get_child(0).grab_focus()


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Handle advancing dialogue
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		# Only advance if no choices are shown
		if choices_container.get_child_count() == 0:
			get_viewport().set_input_as_handled()
			advance()

	# Handle closing with escape
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

	# Handle number key choices
	for i in range(1, 5):
		if event.is_action_pressed("hotbar_" + str(i)):
			var choice_index := i - 1
			if choice_index < choices_container.get_child_count():
				get_viewport().set_input_as_handled()
				_on_choice_pressed(choice_index)
				break


func _on_choice_pressed(index: int) -> void:
	AudioManager.play_sound("button_click")
	dialogue_choice_made.emit(index)
	advance()


func advance() -> void:
	current_line_index += 1
	if current_line_index >= dialogue_lines.size():
		close()
	else:
		_display_current_line()


func close() -> void:
	is_open = false
	visible = false
	current_npc = null
	dialogue_lines = []
	current_line_index = 0
	_clear_choices()
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	dialogue_closed.emit()
	EventBus.dialogue_ended.emit()
