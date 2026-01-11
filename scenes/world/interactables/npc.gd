extends Interactable
class_name NPC
## Base NPC class for quest givers, shopkeepers, etc.
## NPCs can wander near their home position and have idle/walk animations.

signal dialogue_started()
signal dialogue_ended()

@export var npc_name: String = "Villager"
@export var available_quest_ids: Array[String] = []
@export var is_shopkeeper: bool = false
@export var dialogue_lines: Array[String] = ["Hello, adventurer!"]
@export var character_model_path: String = ""  # Path to .glb model file

# Wandering settings
@export var wander_enabled: bool = true
@export var wander_radius: float = 5.0  # How far from home position NPC can wander
@export var wander_speed: float = 1.5  # Movement speed while wandering
@export var idle_time_min: float = 2.0  # Minimum time to idle before wandering
@export var idle_time_max: float = 6.0  # Maximum time to idle before wandering

var current_dialogue_index: int = 0
var in_dialogue: bool = false

# Quest indicator (shows when NPC has available quests)
var quest_indicator: Node3D = null

# Character model and animation
var character_model: Node3D = null
var anim_controller: AnimationController = null

# Wandering state
var home_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var is_wandering: bool = false
var idle_timer: float = 0.0
var current_idle_duration: float = 3.0

enum NPCState { IDLE, WALKING, INTERACTING }
var current_state: NPCState = NPCState.IDLE


func _ready() -> void:
	one_time_use = false
	interaction_text = "Press F to talk to " + npc_name
	super._ready()

	_setup_quest_indicator()
	_update_quest_indicator()

	# Store home position for wandering
	home_position = global_position

	# Connect to quest events
	QuestManager.quest_completed.connect(_on_quest_completed)

	# Setup visual and animations (async due to model loading)
	_setup_visual_async()


func _setup_visual_async() -> void:
	# Try to load character model if path is provided
	if not character_model_path.is_empty() and ResourceLoader.exists(character_model_path):
		var model_scene: PackedScene = load(character_model_path)
		character_model = model_scene.instantiate()
		character_model.name = "CharacterModel"
		add_child(character_model)

		# Setup animation controller
		anim_controller = AnimationController.new()
		anim_controller.name = "AnimationController"
		add_child(anim_controller)

		# Wait a frame for the model to be fully added to scene tree
		await get_tree().process_frame
		anim_controller.setup_for_model(character_model)

		# Now start idle state with animation
		_start_idle()
		return

	# Fallback: Add a capsule mesh as default NPC visual
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "NPCMesh"

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	mesh_instance.mesh = capsule
	mesh_instance.position.y = 0.8

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.4, 0.3)  # Brown-ish for NPC
	mesh_instance.material_override = material

	add_child(mesh_instance)

	# Start idle for capsule NPCs too
	_start_idle()


func _setup_quest_indicator() -> void:
	# Create floating "!" or "?" above NPC
	quest_indicator = Node3D.new()
	quest_indicator.name = "QuestIndicator"
	quest_indicator.position = Vector3(0, 2.5, 0)

	var mesh_instance := MeshInstance3D.new()
	var text_mesh := TextMesh.new()
	text_mesh.text = "!"
	text_mesh.font_size = 128
	text_mesh.depth = 0.05
	mesh_instance.mesh = text_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color.YELLOW
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material

	quest_indicator.add_child(mesh_instance)
	add_child(quest_indicator)
	quest_indicator.visible = false


func _update_quest_indicator() -> void:
	var has_available := false
	var has_completable := false

	for quest_id in available_quest_ids:
		if QuestManager.is_quest_active(quest_id):
			var state := QuestManager.get_quest_state(quest_id)
			var all_complete := true
			for obj_id in state.objectives:
				if not state.objectives[obj_id].completed:
					all_complete = false
					break
			if all_complete:
				has_completable = true

		elif not QuestManager.is_quest_completed(quest_id):
			# Check if quest can be started
			var quest := QuestManager.get_quest(quest_id)
			var prereqs_met := true
			for prereq in quest.get("prerequisites", []):
				if not QuestManager.is_quest_completed(prereq):
					prereqs_met = false
					break
			if prereqs_met:
				has_available = true

	if quest_indicator:
		if has_completable:
			quest_indicator.visible = true
			var mesh := quest_indicator.get_child(0) as MeshInstance3D
			if mesh and mesh.mesh is TextMesh:
				(mesh.mesh as TextMesh).text = "?"
				mesh.material_override.albedo_color = Color.GREEN
				mesh.material_override.emission = Color.GREEN
		elif has_available:
			quest_indicator.visible = true
			var mesh := quest_indicator.get_child(0) as MeshInstance3D
			if mesh and mesh.mesh is TextMesh:
				(mesh.mesh as TextMesh).text = "!"
				mesh.material_override.albedo_color = Color.YELLOW
				mesh.material_override.emission = Color.YELLOW
		else:
			quest_indicator.visible = false


func _process(delta: float) -> void:
	super._process(delta)

	# Rotate quest indicator to face camera
	if quest_indicator and quest_indicator.visible:
		var camera := get_viewport().get_camera_3d()
		if camera:
			quest_indicator.look_at(camera.global_position)

	# Handle wandering behavior
	if wander_enabled and current_state != NPCState.INTERACTING:
		_update_wandering(delta)


func _update_wandering(delta: float) -> void:
	match current_state:
		NPCState.IDLE:
			idle_timer -= delta
			if idle_timer <= 0:
				_start_wandering()

		NPCState.WALKING:
			_move_toward_target(delta)


func _start_idle() -> void:
	current_state = NPCState.IDLE
	current_idle_duration = randf_range(idle_time_min, idle_time_max)
	idle_timer = current_idle_duration

	if anim_controller:
		anim_controller.play_idle()


func _start_wandering() -> void:
	# Pick a random point near home position, try a few times to find unblocked path
	var attempts := 5
	var found_valid_target := false

	while attempts > 0 and not found_valid_target:
		var angle := randf() * TAU
		var distance := randf() * wander_radius
		var potential_target := home_position + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)

		# Check if path to this target is clear
		if not _is_path_blocked(global_position, potential_target):
			wander_target = potential_target
			found_valid_target = true
		attempts -= 1

	if not found_valid_target:
		# Couldn't find valid path, stay idle
		_start_idle()
		return

	current_state = NPCState.WALKING

	if anim_controller:
		anim_controller.play_walk()


func _move_toward_target(delta: float) -> void:
	var current_pos := global_position
	var target_pos := wander_target
	target_pos.y = current_pos.y  # Keep on same height

	var direction := (target_pos - current_pos).normalized()
	var distance := current_pos.distance_to(target_pos)

	if distance < 0.3:
		# Reached target, start idling
		_start_idle()
		return

	# Move toward target
	var move_amount := wander_speed * delta
	if move_amount > distance:
		move_amount = distance

	# Check for obstacles before moving
	var new_pos := current_pos + direction * move_amount
	if _is_path_blocked(current_pos, new_pos):
		# Path is blocked, pick a new wander target
		_start_idle()
		return

	global_position = new_pos

	# Face movement direction
	if direction.length() > 0.01:
		var target_rotation := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)


func _is_path_blocked(from_pos: Vector3, to_pos: Vector3) -> bool:
	## Check if there's an obstacle between from_pos and to_pos using raycasting
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return false

	# Raycast at character height (about 1m up from ground)
	var from := from_pos + Vector3(0, 1.0, 0)
	var to := to_pos + Vector3(0, 1.0, 0)

	# Also check a bit in front of the target
	var direction := (to - from).normalized()
	to += direction * 0.5  # Check a bit further ahead

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Buildings are on layer 1
	query.exclude = [self]  # Don't hit ourselves

	var result := space_state.intersect_ray(query)
	return not result.is_empty()


func interact(player: Node3D) -> void:
	# Stop wandering when interacting
	current_state = NPCState.INTERACTING
	if anim_controller:
		anim_controller.play_idle()

	# Face the player
	var dir_to_player := (player.global_position - global_position).normalized()
	if dir_to_player.length() > 0.01:
		rotation.y = atan2(dir_to_player.x, dir_to_player.z)

	if in_dialogue:
		_advance_dialogue()
	else:
		_start_interaction()

	interacted.emit(player)


func _start_interaction() -> void:
	# Check for completable quests first
	for quest_id in available_quest_ids:
		if QuestManager.is_quest_active(quest_id):
			var state := QuestManager.get_quest_state(quest_id)
			var all_complete := true
			for obj_id in state.objectives:
				if not state.objectives[obj_id].completed:
					all_complete = false
					break
			if all_complete:
				QuestManager.complete_quest(quest_id)
				_update_quest_indicator()
				_end_interaction()
				return

	# Check for available quests
	for quest_id in available_quest_ids:
		if not QuestManager.is_quest_active(quest_id) and not QuestManager.is_quest_completed(quest_id):
			var quest := QuestManager.get_quest(quest_id)
			# Check prerequisites
			var prereqs_met := true
			for prereq in quest.get("prerequisites", []):
				if not QuestManager.is_quest_completed(prereq):
					prereqs_met = false
					break

			if prereqs_met:
				_offer_quest(quest_id)
				return

	# No quests - show regular dialogue
	_start_dialogue()


func _offer_quest(quest_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)

	# Show quest offer dialogue
	EventBus.show_message.emit(npc_name + ": " + quest.description, Color.WHITE, 4.0)

	# Auto-accept for now (full implementation would show quest UI)
	QuestManager.start_quest(quest_id)
	_update_quest_indicator()
	_end_interaction()


func _start_dialogue() -> void:
	if dialogue_lines.is_empty():
		_end_interaction()
		return

	in_dialogue = true
	current_dialogue_index = 0
	dialogue_started.emit()

	_show_current_dialogue()


func _advance_dialogue() -> void:
	current_dialogue_index += 1

	if current_dialogue_index >= dialogue_lines.size():
		_end_dialogue()
	else:
		_show_current_dialogue()


func _show_current_dialogue() -> void:
	var line := dialogue_lines[current_dialogue_index]
	EventBus.show_message.emit(npc_name + ": " + line, Color.WHITE, 3.0)


func _end_dialogue() -> void:
	in_dialogue = false
	current_dialogue_index = 0
	dialogue_ended.emit()
	_end_interaction()


func _end_interaction() -> void:
	# Resume wandering after interaction ends
	await get_tree().create_timer(1.0).timeout
	_start_idle()


func _on_quest_completed(_quest_id: String) -> void:
	_update_quest_indicator()


func add_quest(quest_id: String) -> void:
	if quest_id not in available_quest_ids:
		available_quest_ids.append(quest_id)
	_update_quest_indicator()


func set_home_position(pos: Vector3) -> void:
	home_position = pos
