extends Control
class_name MiningMinigame
## Mining minigame with timing bar.
## Port of the original TileGame3D mining system.

signal mining_complete(ore_count: int)
signal mining_cancelled()

enum State { IDLE, ACTIVE, COMPLETE }

@onready var timing_bar: Control = $TimingBar
@onready var indicator: ColorRect = $TimingBar/Indicator
@onready var sweet_spot: ColorRect = $TimingBar/SweetSpot
@onready var timer_label: Label = $TimerLabel
@onready var ore_counter: Label = $OreCounter
@onready var combo_label: Label = $ComboLabel
@onready var feedback_label: Label = $Feedback
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel

var state: State = State.IDLE
var ore_type: String = "copper"

# Timing bar state
var indicator_position: float = 0.0
var indicator_speed: float = 2.0
var moving_right: bool = true

# Sweet spot position (0-1)
var sweet_spot_start: float = 0.4
var sweet_spot_end: float = 0.6

# Game state
var time_remaining: float = 20.0
var total_time: float = 20.0
var ore_mined: int = 0
var current_hits: int = 0
var hits_per_ore: int = 5
var combo: int = 0
var score: int = 0


func _ready() -> void:
	visible = false
	result_panel.visible = false


func start_mining(ore: String) -> void:
	ore_type = ore
	visible = true
	state = State.ACTIVE
	_reset_stats()

	# Adjust difficulty based on ore type
	match ore_type:
		"copper":
			indicator_speed = 1.5
			sweet_spot_start = 0.35
			sweet_spot_end = 0.65
		"iron":
			indicator_speed = 2.0
			sweet_spot_start = 0.40
			sweet_spot_end = 0.60
		"gold":
			indicator_speed = 2.5
			sweet_spot_start = 0.42
			sweet_spot_end = 0.58

	_update_sweet_spot_visual()
	_update_display()


func _update_sweet_spot_visual() -> void:
	var bar_width := timing_bar.size.x
	sweet_spot.position.x = sweet_spot_start * bar_width
	sweet_spot.size.x = (sweet_spot_end - sweet_spot_start) * bar_width


func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return

	# Update timer
	time_remaining -= delta
	_update_timer_display()

	if time_remaining <= 0:
		_complete_mining()
		return

	# Move indicator
	if moving_right:
		indicator_position += indicator_speed * delta
		if indicator_position >= 1.0:
			indicator_position = 1.0
			moving_right = false
	else:
		indicator_position -= indicator_speed * delta
		if indicator_position <= 0.0:
			indicator_position = 0.0
			moving_right = true

	# Update indicator visual
	var bar_width := timing_bar.size.x
	indicator.position.x = indicator_position * bar_width - indicator.size.x / 2

	# Check for swing input
	if Input.is_action_just_pressed("jump"):
		_handle_swing()


func _handle_swing() -> void:
	var hit_quality := _evaluate_hit()

	match hit_quality:
		"perfect":
			combo += 1
			current_hits += 1
			score += 20 * combo
			_show_feedback("Perfect!", Color.GREEN)
			AudioManager.play_sound("mining_hit")
		"great":
			combo += 1
			current_hits += 1
			score += 15 * combo
			_show_feedback("Great!", Color.CYAN)
			AudioManager.play_sound("mining_hit")
		"good":
			combo += 1
			current_hits += 1
			score += 10 * combo
			_show_feedback("Good!", Color.YELLOW)
			AudioManager.play_sound("mining_hit")
		"miss":
			combo = 0
			_show_feedback("Miss!", Color.RED)

	# Check if ore was mined
	if current_hits >= hits_per_ore:
		ore_mined += 1
		current_hits = 0
		AudioManager.play_sound("mining_success")

	_update_display()


func _evaluate_hit() -> String:
	var sweet_center := (sweet_spot_start + sweet_spot_end) / 2
	var sweet_width := sweet_spot_end - sweet_spot_start
	var distance := abs(indicator_position - sweet_center)

	if distance <= sweet_width * 0.3:
		return "perfect"
	elif distance <= sweet_width * 0.5:
		return "great"
	elif distance <= sweet_width * 0.75:
		return "good"
	else:
		return "miss"


func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.visible = true

	# Fade out
	var tween := create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): feedback_label.visible = false; feedback_label.modulate.a = 1.0)


func _update_display() -> void:
	ore_counter.text = "Ore: %d" % ore_mined
	combo_label.text = "Combo: %d" % combo

	# Show progress toward next ore
	var progress_text := "%d/%d" % [current_hits, hits_per_ore]
	# Progress would be shown visually


func _update_timer_display() -> void:
	timer_label.text = "%.1f" % time_remaining

	# Change color as time runs low
	if time_remaining <= 5.0:
		timer_label.modulate = Color.RED
	elif time_remaining <= 10.0:
		timer_label.modulate = Color.ORANGE
	else:
		timer_label.modulate = Color.WHITE


func _complete_mining() -> void:
	state = State.COMPLETE

	# Convert ore type to item ID
	var ore_item_id := "ore_" + ore_type

	# Add ore to inventory
	for i in ore_mined:
		EventBus.item_picked_up.emit(ore_item_id, 1)

	# Show result
	var ore_name: String = ItemDatabase.get_item(ore_item_id).get("name", ore_type.capitalize() + " Ore")
	result_label.text = "Mined %d %s!" % [ore_mined, ore_name]
	result_panel.visible = true

	mining_complete.emit(ore_mined)

	await get_tree().create_timer(2.0).timeout
	_end_mining()


func _end_mining() -> void:
	state = State.IDLE
	visible = false
	result_panel.visible = false


func cancel() -> void:
	if state != State.IDLE:
		state = State.IDLE
		visible = false
		mining_cancelled.emit()


func _reset_stats() -> void:
	indicator_position = 0.0
	moving_right = true
	time_remaining = total_time
	ore_mined = 0
	current_hits = 0
	combo = 0
	score = 0
	feedback_label.visible = false
