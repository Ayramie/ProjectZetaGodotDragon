extends Node
## Audio manager singleton.
## Handles all sound effects and music playback.

# Audio bus names
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_UI := "UI"

# Audio pools for frequently played sounds
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_3d_pool: Array[AudioStreamPlayer3D] = []
const SFX_POOL_SIZE := 16
const SFX_3D_POOL_SIZE := 24

# Currently playing music
var current_music: AudioStreamPlayer = null
var music_tween: Tween = null

# Volume settings (0.0 to 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.7
var ui_volume: float = 1.0

# Preloaded sound effects
var sounds: Dictionary = {}


func _ready() -> void:
	_setup_audio_buses()
	_create_audio_pools()
	_preload_sounds()


func _setup_audio_buses() -> void:
	# Audio buses should be configured in project settings
	# This just ensures volumes are applied
	_apply_volumes()


func _create_audio_pools() -> void:
	# Create 2D SFX pool
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		sfx_pool.append(player)

	# Create 3D SFX pool
	for i in SFX_3D_POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS_SFX
		player.max_distance = 50.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		sfx_3d_pool.append(player)

	# Create music player
	current_music = AudioStreamPlayer.new()
	current_music.bus = BUS_MUSIC
	add_child(current_music)


func _preload_sounds() -> void:
	# Combat sounds
	_register_sound("sword_swing", "res://assets/audio/sfx/combat/sword_swing.ogg")
	_register_sound("sword_hit", "res://assets/audio/sfx/combat/sword_hit.ogg")
	_register_sound("bow_shoot", "res://assets/audio/sfx/combat/bow_shoot.ogg")
	_register_sound("arrow_hit", "res://assets/audio/sfx/combat/arrow_hit.ogg")
	_register_sound("spell_cast", "res://assets/audio/sfx/combat/spell_cast.ogg")
	_register_sound("spell_hit", "res://assets/audio/sfx/combat/spell_hit.ogg")
	_register_sound("player_hurt", "res://assets/audio/sfx/combat/player_hurt.ogg")
	_register_sound("enemy_hurt", "res://assets/audio/sfx/combat/enemy_hurt.ogg")
	_register_sound("enemy_death", "res://assets/audio/sfx/combat/enemy_death.ogg")

	# Ability sounds
	_register_sound("cleave", "res://assets/audio/sfx/abilities/cleave.ogg")
	_register_sound("whirlwind", "res://assets/audio/sfx/abilities/whirlwind.ogg")
	_register_sound("heroic_leap", "res://assets/audio/sfx/abilities/heroic_leap.ogg")
	_register_sound("parry", "res://assets/audio/sfx/abilities/parry.ogg")
	_register_sound("sunder", "res://assets/audio/sfx/abilities/sunder.ogg")
	_register_sound("blizzard", "res://assets/audio/sfx/abilities/blizzard.ogg")
	_register_sound("flame_wave", "res://assets/audio/sfx/abilities/flame_wave.ogg")
	_register_sound("frost_nova", "res://assets/audio/sfx/abilities/frost_nova.ogg")
	_register_sound("blink", "res://assets/audio/sfx/abilities/blink.ogg")
	_register_sound("arrow_wave", "res://assets/audio/sfx/abilities/arrow_wave.ogg")
	_register_sound("trap_place", "res://assets/audio/sfx/abilities/trap_place.ogg")
	_register_sound("trap_trigger", "res://assets/audio/sfx/abilities/trap_trigger.ogg")

	# UI sounds
	_register_sound("inventory_open", "res://assets/audio/sfx/ui/inventory_open.ogg")
	_register_sound("inventory_close", "res://assets/audio/sfx/ui/inventory_close.ogg")
	_register_sound("equip", "res://assets/audio/sfx/ui/equip.ogg")
	_register_sound("unequip", "res://assets/audio/sfx/ui/unequip.ogg")
	_register_sound("item_pickup", "res://assets/audio/sfx/ui/item_pickup.ogg")
	_register_sound("item_use", "res://assets/audio/sfx/ui/item_use.ogg")
	_register_sound("button_click", "res://assets/audio/sfx/ui/button_click.ogg")
	_register_sound("button_hover", "res://assets/audio/sfx/ui/button_hover.ogg")
	_register_sound("level_up", "res://assets/audio/sfx/ui/level_up.ogg")
	_register_sound("quest_complete", "res://assets/audio/sfx/ui/quest_complete.ogg")

	# Life skill sounds
	_register_sound("fishing_cast", "res://assets/audio/sfx/minigames/fishing_cast.ogg")
	_register_sound("fishing_splash", "res://assets/audio/sfx/minigames/fishing_splash.ogg")
	_register_sound("fishing_reel", "res://assets/audio/sfx/minigames/fishing_reel.ogg")
	_register_sound("fishing_catch", "res://assets/audio/sfx/minigames/fishing_catch.ogg")
	_register_sound("cooking_sizzle", "res://assets/audio/sfx/minigames/cooking_sizzle.ogg")
	_register_sound("cooking_flip", "res://assets/audio/sfx/minigames/cooking_flip.ogg")
	_register_sound("cooking_complete", "res://assets/audio/sfx/minigames/cooking_complete.ogg")
	_register_sound("mining_hit", "res://assets/audio/sfx/minigames/mining_hit.ogg")
	_register_sound("mining_success", "res://assets/audio/sfx/minigames/mining_success.ogg")
	_register_sound("chopping_hit", "res://assets/audio/sfx/minigames/chopping_hit.ogg")
	_register_sound("chopping_success", "res://assets/audio/sfx/minigames/chopping_success.ogg")
	_register_sound("crafting_hammer", "res://assets/audio/sfx/minigames/crafting_hammer.ogg")
	_register_sound("crafting_complete", "res://assets/audio/sfx/minigames/crafting_complete.ogg")
	_register_sound("smelting_fire", "res://assets/audio/sfx/minigames/smelting_fire.ogg")
	_register_sound("anvil_strike", "res://assets/audio/sfx/minigames/anvil_strike.ogg")

	# Potion/heal sounds
	_register_sound("potion_drink", "res://assets/audio/sfx/combat/potion_drink.ogg")
	_register_sound("heal", "res://assets/audio/sfx/combat/heal.ogg")
	_register_sound("buff_apply", "res://assets/audio/sfx/combat/buff_apply.ogg")


func _register_sound(sound_name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		sounds[sound_name] = load(path)


func play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sounds.has(sound_name):
		return

	var player := _get_available_sfx_player()
	if player:
		player.stream = sounds[sound_name]
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()


func play_sound_3d(sound_name: String, position: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sounds.has(sound_name):
		return

	var player := _get_available_sfx_3d_player()
	if player:
		player.stream = sounds[sound_name]
		player.global_position = position
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()


func play_music(music_path: String, fade_duration: float = 1.0) -> void:
	if not ResourceLoader.exists(music_path):
		return

	var new_stream: AudioStream = load(music_path)

	if music_tween:
		music_tween.kill()

	if current_music.playing:
		# Fade out current music
		music_tween = create_tween()
		music_tween.tween_property(current_music, "volume_db", -40.0, fade_duration)
		await music_tween.finished

	current_music.stream = new_stream
	current_music.volume_db = -40.0
	current_music.play()

	# Fade in new music
	music_tween = create_tween()
	music_tween.tween_property(current_music, "volume_db", linear_to_db(music_volume), fade_duration)


func stop_music(fade_duration: float = 1.0) -> void:
	if music_tween:
		music_tween.kill()

	if current_music.playing:
		music_tween = create_tween()
		music_tween.tween_property(current_music, "volume_db", -40.0, fade_duration)
		await music_tween.finished
		current_music.stop()


func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()


func set_ui_volume(volume: float) -> void:
	ui_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	var ui_idx := AudioServer.get_bus_index(BUS_UI)

	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))
	if ui_idx >= 0:
		AudioServer.set_bus_volume_db(ui_idx, linear_to_db(ui_volume))


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	# If all are playing, return the first one (will interrupt it)
	return sfx_pool[0]


func _get_available_sfx_3d_player() -> AudioStreamPlayer3D:
	for player in sfx_3d_pool:
		if not player.playing:
			return player
	# If all are playing, return the first one
	return sfx_3d_pool[0]
