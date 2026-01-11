extends Node
class_name AnimationController
## Handles character animations using KayKit animation libraries.
## Loads animations from separate GLB files and applies them to characters.

signal animation_finished(anim_name: String)

var animation_player: AnimationPlayer = null
var current_animation: String = ""
var is_playing_oneshot: bool = false
var animations_loaded: bool = false

# Animation name mappings (KayKit naming convention -> our names)
# Based on original Three.js kayKitCharacter.js mappings
const ANIMATION_MAP := {
	# Idle animations
	"Idle": "idle",
	"Idle_A": "idle",
	"Idle_B": "idle",
	"1H_Melee_Idle": "idle",
	"2H_Melee_Idle": "idle",
	"1H_Ranged_Idle": "idle",
	"Unarmed_Idle": "idle",

	# Movement animations
	"Walking_A": "walk",
	"Walking_B": "walk",
	"Walking_C": "walk",
	"Walking_Backwards": "walk_back",
	"Running_A": "run",
	"Running_B": "run",
	"Running_Strafe_Left": "strafe_left",
	"Running_Strafe_Right": "strafe_right",

	# Attack animations
	"1H_Melee_Attack_Slice_Horizontal": "attack",
	"1H_Melee_Attack_Slice_Diagonal": "attack2",
	"1H_Melee_Attack_Chop": "attack3",
	"1H_Melee_Attack_Stab": "attack_stab",
	"2H_Melee_Attack_Slice": "attack_2h",
	"2H_Melee_Attack_Spin": "attack_spin",
	"1H_Ranged_Aiming": "aim",
	"1H_Ranged_Shoot": "shoot",
	"1H_Ranged_Shooting": "shooting",
	"Unarmed_Melee_Attack_Punch_A": "punch",
	"Unarmed_Melee_Attack_Punch_B": "punch2",
	"Unarmed_Melee_Attack_Kick": "kick",

	# Combat utility
	"Dodge_Left": "dodge_left",
	"Dodge_Right": "dodge_right",
	"Dodge_Backward": "dodge_back",
	"Block": "block",
	"Blocking": "blocking",

	# Damage/Death
	"Hit_A": "hit",
	"Hit_B": "hit2",
	"Death_A": "death",
	"Death_A_Pose": "death_pose",
	"Death_B": "death2",
	"Death_B_Pose": "death2_pose",

	# Jump
	"Jump_Full_Short": "jump_short",
	"Jump_Full_Long": "jump",
	"Jump_Start": "jump_start",
	"Jump_Idle": "jump_idle",
	"Jump_Land": "jump_land",

	# Spellcasting
	"Spellcast_Shoot": "cast",
	"Spellcast_Raise": "cast_raise",
	"Spellcast_Long": "cast_long",
	"Spellcasting": "casting",

	# Interact
	"Interact": "interact",
	"PickUp": "pickup",
	"Use_Item": "use_item",
}

# Animation library paths (same as original Three.js)
const ANIM_LIBS := {
	"movement": "res://assets/kaykit/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"movement_adv": "res://assets/kaykit/animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
	"combat_melee": "res://assets/kaykit/animations/rig_medium/Rig_Medium_CombatMelee.glb",
	"combat_ranged": "res://assets/kaykit/animations/rig_medium/Rig_Medium_CombatRanged.glb",
	"general": "res://assets/kaykit/animations/rig_medium/Rig_Medium_General.glb",
	"special": "res://assets/kaykit/animations/rig_medium/Rig_Medium_Special.glb",
	"simulation": "res://assets/kaykit/animations/rig_medium/Rig_Medium_Simulation.glb",
}

# Reverse map for lookup
var reverse_map: Dictionary = {}

# Animations that should loop
const LOOPING_ANIMATIONS := [
	"idle", "walk", "walk_back", "run",
	"strafe_left", "strafe_right",
	"blocking", "casting", "aim"
]


func _ready() -> void:
	# Build reverse map
	for kaykit_name in ANIMATION_MAP:
		var our_name: String = ANIMATION_MAP[kaykit_name]
		if not reverse_map.has(our_name):
			reverse_map[our_name] = kaykit_name


func setup(anim_player: AnimationPlayer, skeleton_root: Node = null) -> void:
	animation_player = anim_player

	if animation_player:
		# Set root node for animation paths if skeleton root provided
		# The animation tracks reference nodes relative to root_node
		# For KayKit animations, tracks are like "Skeleton3D:BoneName" or "Armature/Skeleton3D:BoneName"
		if skeleton_root:
			# root_node should be the parent of the skeleton hierarchy
			animation_player.root_node = animation_player.get_path_to(skeleton_root)

		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

		# Load animations from KayKit GLB files
		_load_animation_libraries()


func setup_for_model(model_node: Node3D) -> void:
	## Sets up animation controller for a model node.
	## Creates AnimationPlayer if needed and loads animations.
	if not model_node:
		push_warning("AnimationController: setup_for_model called with null model")
		return

	# First, check if the model already has an AnimationPlayer
	animation_player = _find_animation_player(model_node)

	if not animation_player:
		# Create AnimationPlayer as direct child of model_node
		# This ensures animation paths like "Armature/Skeleton3D:BoneName" resolve correctly
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		model_node.add_child(animation_player)

	# Set root_node to the model_node (parent of AnimationPlayer) so animation paths resolve correctly
	# KayKit animation tracks use paths like "Armature/Skeleton3D:BoneName"
	# which need to start from the GLB's root node (model_node)
	animation_player.root_node = NodePath("..")

	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

	# Load animations
	_load_animation_libraries()


func _load_animation_libraries() -> void:
	if not animation_player or animations_loaded:
		return

	# Create default animation library if needed
	if not animation_player.has_animation_library(""):
		animation_player.add_animation_library("", AnimationLibrary.new())

	var lib := animation_player.get_animation_library("")

	var anims_loaded := 0

	# Load each animation pack
	for lib_name in ANIM_LIBS:
		var lib_path: String = ANIM_LIBS[lib_name]
		if not ResourceLoader.exists(lib_path):
			print("AnimController: Missing library: %s" % lib_path)
			continue

		var glb_scene: PackedScene = load(lib_path)
		if not glb_scene:
			print("AnimController: Failed to load: %s" % lib_path)
			continue

		var instance := glb_scene.instantiate()

		# Find AnimationPlayer in the GLB scene
		var glb_anim_player := _find_animation_player(instance)
		if not glb_anim_player:
			print("AnimController: No AnimationPlayer in %s" % lib_name)
			instance.queue_free()
			continue

		# Get all animation libraries from the GLB's AnimationPlayer
		var lib_list := glb_anim_player.get_animation_library_list()
		print("AnimController: %s has libraries: %s" % [lib_name, lib_list])

		for glb_lib_name in lib_list:
			var glb_lib := glb_anim_player.get_animation_library(glb_lib_name)
			if glb_lib:
				for anim_name in glb_lib.get_animation_list():
					var anim := glb_lib.get_animation(anim_name)
					if anim:
						# Map to our naming convention
						var mapped_name := anim_name
						if ANIMATION_MAP.has(anim_name):
							mapped_name = ANIMATION_MAP[anim_name]

						# Add animation if we don't have it yet
						if not lib.has_animation(mapped_name):
							var anim_copy: Animation = anim.duplicate()
							# Remove root motion (position tracks on root bones)
							_remove_root_motion(anim_copy)
							# Set loop mode based on animation type
							if mapped_name in LOOPING_ANIMATIONS:
								anim_copy.loop_mode = Animation.LOOP_LINEAR
							else:
								anim_copy.loop_mode = Animation.LOOP_NONE
							lib.add_animation(mapped_name, anim_copy)
							anims_loaded += 1

		instance.queue_free()

	animations_loaded = true

	print("AnimController: Loaded %d animations total" % anims_loaded)
	if anims_loaded == 0:
		push_warning("AnimationController: No animations loaded! Check animation library paths.")


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _remove_root_motion(anim: Animation) -> void:
	## Remove position tracks from root bones to prevent unwanted movement.
	## Same as original Three.js removeRootMotion function.
	var tracks_to_remove: Array[int] = []

	for i in anim.get_track_count():
		var track_path := anim.track_get_path(i)
		var track_path_str := str(track_path)

		# Check if it's a position track on a root bone
		var is_position_track := track_path_str.ends_with(":position")
		var is_root_bone := (
			track_path_str.contains("Root") or
			track_path_str.contains("Hips") or
			track_path_str.contains("Armature") or
			track_path_str.contains("Skeleton")
		)

		if is_position_track and is_root_bone:
			tracks_to_remove.append(i)

	# Remove tracks in reverse order to maintain indices
	tracks_to_remove.reverse()
	for idx in tracks_to_remove:
		anim.remove_track(idx)


func play(anim_name: String, force: bool = false) -> void:
	if not animation_player:
		push_warning("AnimationController.play: No animation player!")
		return

	# Don't interrupt oneshot animations unless forced
	if is_playing_oneshot and not force:
		return

	if animation_player.has_animation(anim_name):
		if current_animation != anim_name or force:
			animation_player.play(anim_name)
			current_animation = anim_name
	else:
		if not animations_loaded:
			# Animations not loaded yet, try to load them
			_load_animation_libraries()
			if animation_player.has_animation(anim_name):
				animation_player.play(anim_name)
				current_animation = anim_name
			else:
				print("AnimController: Animation '%s' not found after loading" % anim_name)
		else:
			print("AnimController: Animation '%s' not found (loaded=%d)" % [anim_name, get_available_animations().size()])


func play_oneshot(anim_name: String) -> void:
	if not animation_player:
		return

	if animation_player.has_animation(anim_name):
		is_playing_oneshot = true
		animation_player.play(anim_name)
		current_animation = anim_name


func stop() -> void:
	if animation_player:
		animation_player.stop()
		is_playing_oneshot = false


func _on_animation_finished(anim_name: String) -> void:
	is_playing_oneshot = false
	animation_finished.emit(anim_name)


# Convenience methods using our mapped names
func play_idle() -> void:
	play("idle")


func play_walk() -> void:
	play("walk")


func play_run() -> void:
	play("run")


func play_attack_melee() -> void:
	play_oneshot("attack")


func play_attack_ranged() -> void:
	play_oneshot("shoot")


func play_cast() -> void:
	play_oneshot("cast")


func play_hit() -> void:
	play_oneshot("hit")


func play_death() -> void:
	play_oneshot("death")


func play_jump() -> void:
	play_oneshot("jump")


func is_animation_playing(anim_name: String) -> bool:
	return current_animation == anim_name and animation_player and animation_player.is_playing()


func has_animation(anim_name: String) -> bool:
	return animation_player and animation_player.has_animation(anim_name)


func get_available_animations() -> PackedStringArray:
	if not animation_player:
		return PackedStringArray()

	var lib := animation_player.get_animation_library("")
	if lib:
		return lib.get_animation_list()
	return PackedStringArray()
