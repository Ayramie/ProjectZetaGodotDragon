extends Control
class_name FishingMinigame
## Fishing minigame with QTE key sequence.
## Port of the original TileGame3D fishing system.

signal fishing_complete(fish_id: String, quality: String)
signal fishing_failed()
signal fishing_cancelled()

enum State { IDLE, CASTING, WAITING, BITE, QTE, REELING, COMPLETE, FAILED }

# UI nodes - created programmatically
var qte_container: Control
var current_key_label: Label
var key_queue_container: HBoxContainer
var timer_bar: ProgressBar
var feedback_label: Label
var fish_counter: Label
var combo_label: Label
var score_label: Label
var result_panel: PanelContainer
var result_label: Label

var state: State = State.IDLE
var qte_sequence: Array[String] = []
var qte_index: int = 0
var qte_timer: float = 0.0
var qte_timeout: float = 2.0
var total_time: float = 30.0
var time_remaining: float = 30.0

var combo: int = 0
var max_combo: int = 0
var score: int = 0
var fish_caught: int = 0

const QTE_KEYS := ["W", "A", "S", "D"]
const SEQUENCE_LENGTH := 6


func _ready() -> void:
	_build_ui()
	visible = false
	qte_container.visible = false
	result_panel.visible = false


func _build_ui() -> void:
	# Full screen anchor
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# QTE container (main game panel)
	qte_container = PanelContainer.new()
	qte_container.set_anchors_preset(Control.PRESET_CENTER)
	qte_container.custom_minimum_size = Vector2(500, 350)
	qte_container.position = -qte_container.custom_minimum_size / 2
	add_child(qte_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	qte_container.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Fishing"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Timer bar
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(400, 25)
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	vbox.add_child(timer_bar)

	# Current key display
	current_key_label = Label.new()
	current_key_label.text = "W"
	current_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_key_label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(current_key_label)

	# Key queue
	key_queue_container = HBoxContainer.new()
	key_queue_container.alignment = BoxContainer.ALIGNMENT_CENTER
	key_queue_container.add_theme_constant_override("separation", 10)
	vbox.add_child(key_queue_container)

	# Feedback label
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(feedback_label)

	# Stats row
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 30)
	vbox.add_child(stats)

	fish_counter = Label.new()
	fish_counter.text = "Fish: 0"
	stats.add_child(fish_counter)

	combo_label = Label.new()
	combo_label.text = "Combo: 0"
	stats.add_child(combo_label)

	score_label = Label.new()
	score_label.text = "Score: 0"
	stats.add_child(score_label)

	# Instructions
	var instructions := Label.new()
	instructions.text = "Press W/A/S/D to match the keys!"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(instructions)

	# Result panel (separate overlay)
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(350, 100)
	result_panel.position = -result_panel.custom_minimum_size / 2
	result_panel.visible = false
	add_child(result_panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 22)
	result_panel.add_child(result_label)


func start_fishing() -> void:
	visible = true
	state = State.CASTING
	_reset_stats()

	# Show casting animation
	feedback_label.text = "Casting..."
	feedback_label.modulate = Color.WHITE

	await get_tree().create_timer(1.0).timeout

	state = State.WAITING
	_start_waiting()


func _start_waiting() -> void:
	feedback_label.text = "Waiting for a bite..."
	qte_container.visible = false

	# Random wait time for fish to bite
	var wait_time := randf_range(2.0, 5.0)
	await get_tree().create_timer(wait_time).timeout

	if state == State.WAITING:
		_fish_bite()


func _fish_bite() -> void:
	state = State.BITE
	feedback_label.text = "!! FISH ON !!"
	feedback_label.modulate = Color.YELLOW

	AudioManager.play_sound("fishing_splash")

	# Player has 2 seconds to react
	var react_timer := 2.0
	while react_timer > 0 and state == State.BITE:
		await get_tree().process_frame
		react_timer -= get_process_delta_time()

		if Input.is_action_just_pressed("interact"):
			_start_qte()
			return

	# Missed the bite
	if state == State.BITE:
		_fail_fishing("Too slow! The fish got away.")


func _start_qte() -> void:
	state = State.QTE
	qte_container.visible = true
	time_remaining = total_time
	qte_index = 0

	_generate_sequence()
	_update_display()


func _generate_sequence() -> void:
	qte_sequence.clear()
	for i in SEQUENCE_LENGTH:
		qte_sequence.append(QTE_KEYS[randi() % QTE_KEYS.size()])


func _process(delta: float) -> void:
	if state != State.QTE:
		return

	# Update timer
	time_remaining -= delta
	timer_bar.value = (time_remaining / total_time) * 100.0

	if time_remaining <= 0:
		_complete_fishing()
		return

	# Check for key press
	for key in QTE_KEYS:
		if Input.is_action_just_pressed("move_forward") and key == "W":
			_handle_key_press("W")
		elif Input.is_action_just_pressed("move_back") and key == "S":
			_handle_key_press("S")
		elif Input.is_action_just_pressed("move_left") and key == "A":
			_handle_key_press("A")
		elif Input.is_action_just_pressed("move_right") and key == "D":
			_handle_key_press("D")


func _handle_key_press(key: String) -> void:
	if state != State.QTE:
		return

	var expected := qte_sequence[qte_index]

	if key == expected:
		# Correct key
		combo += 1
		max_combo = max(max_combo, combo)
		score += 10 * combo
		qte_index += 1

		_show_feedback("Perfect!", Color.GREEN)
		AudioManager.play_sound("fishing_reel")

		if qte_index >= qte_sequence.size():
			# Caught a fish
			fish_caught += 1
			_generate_sequence()
			qte_index = 0
	else:
		# Wrong key
		combo = 0
		_show_feedback("Miss!", Color.RED)

	_update_display()


func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.modulate = color

	# Reset after short delay
	await get_tree().create_timer(0.3).timeout
	if state == State.QTE:
		feedback_label.text = ""


func _update_display() -> void:
	# Current key
	if qte_index < qte_sequence.size():
		current_key_label.text = qte_sequence[qte_index]
	else:
		current_key_label.text = ""

	# Key queue (next 5 keys)
	for child in key_queue_container.get_children():
		child.queue_free()

	for i in range(qte_index + 1, min(qte_index + 6, qte_sequence.size())):
		var label := Label.new()
		label.text = qte_sequence[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(40, 40)
		key_queue_container.add_child(label)

	# Stats
	fish_counter.text = "Fish: %d" % fish_caught
	combo_label.text = "Combo: %d" % combo
	score_label.text = "Score: %d" % score


func _complete_fishing() -> void:
	state = State.COMPLETE
	qte_container.visible = false

	# Determine fish quality based on score
	var quality := "common"
	var fish_id := "fish_small_trout"

	if score >= 500:
		quality = "legendary"
		fish_id = "fish_legendary_koi"
	elif score >= 300:
		quality = "rare"
		fish_id = "fish_rainbow_trout"
	elif score >= 150:
		quality = "uncommon"
		fish_id = "fish_golden_carp"
	elif score >= 50:
		quality = "common"
		fish_id = "fish_bass"

	_show_result("Caught: %s!" % ItemDatabase.get_item(fish_id).get("name", "Fish"), Color.GREEN)

	AudioManager.play_sound("fishing_catch")
	fishing_complete.emit(fish_id, quality)

	await get_tree().create_timer(2.0).timeout
	_end_fishing()


func _fail_fishing(reason: String) -> void:
	state = State.FAILED
	qte_container.visible = false

	_show_result(reason, Color.RED)
	fishing_failed.emit()

	await get_tree().create_timer(2.0).timeout
	_end_fishing()


func _show_result(text: String, color: Color) -> void:
	result_panel.visible = true
	result_label.text = text
	result_label.modulate = color


func _end_fishing() -> void:
	state = State.IDLE
	visible = false
	result_panel.visible = false


func cancel() -> void:
	if state != State.IDLE:
		state = State.IDLE
		visible = false
		fishing_cancelled.emit()


func _reset_stats() -> void:
	combo = 0
	max_combo = 0
	score = 0
	fish_caught = 0
	qte_index = 0
	time_remaining = total_time
