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


func setup(anim_player: AnimationPlayer) -> void:
	animation_player = anim_player

	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

		# Load animations from KayKit GLB files
		_load_animation_libraries()


func _load_animation_libraries() -> void:
	if not animation_player or animations_loaded:
		return

	# Create default animation library if needed
	if not animation_player.has_animation_library(""):
		animation_player.add_animation_library("", AnimationLibrary.new())

	var lib := animation_player.get_animation_library("")

	# Load each animation pack
	for lib_name in ANIM_LIBS:
		var lib_path: String = ANIM_LIBS[lib_name]
		if not ResourceLoader.exists(lib_path):
			continue

		var glb_scene: PackedScene = load(lib_path)
		if not glb_scene:
			continue

		var instance := glb_scene.instantiate()

		# Find AnimationPlayer in the GLB scene
		var glb_anim_player := _find_animation_player(instance)
		if glb_anim_player:
			# Get all animation libraries from the GLB's AnimationPlayer
			for glb_lib_name in glb_anim_player.get_animation_library_list():
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

		instance.queue_free()

	animations_loaded = true


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
		return

	# Don't interrupt oneshot animations unless forced
	if is_playing_oneshot and not force:
		return

	if animation_player.has_animation(anim_name):
		if current_animation != anim_name or force:
			animation_player.play(anim_name)
			current_animation = anim_name


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
