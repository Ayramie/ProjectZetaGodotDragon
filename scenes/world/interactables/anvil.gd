extends CraftingStation
class_name Anvil
## Anvil station for smithing weapons and armor.

var hammer_sound_timer: float = 0.0
const HAMMER_INTERVAL: float = 0.4


func _ready() -> void:
	station_type = RecipeDatabase.RecipeType.ANVIL
	station_name = "Anvil"
	interaction_text = "Press F to use Anvil"
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)

	# Play hammering sounds while crafting
	if is_crafting:
		hammer_sound_timer -= delta
		if hammer_sound_timer <= 0:
			hammer_sound_timer = HAMMER_INTERVAL
			AudioManager.play_sound_3d("anvil_strike", global_position)

			# Spark effect
			var spawner := get_node_or_null("/root/EffectSpawner")
			if spawner:
				spawner.spawn_particles_advanced(global_position + Vector3.UP * 0.8, {
					"count": 5,
					"texture": "spark",
					"color": Color(1.0, 0.8, 0.4),
					"size": 0.08,
					"speed": 8.0,
					"spread": 60.0,
					"life": 0.3,
					"gravity": -15.0
				})


func _play_crafting_effect() -> void:
	hammer_sound_timer = 0.0  # Play first hammer immediately
	AudioManager.play_sound_3d("crafting_hammer", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP * 0.5, 10)


func _play_completion_effect() -> void:
	hammer_sound_timer = 999.0  # Stop hammer sounds
	AudioManager.play_sound_3d("crafting_complete", global_position)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP, 20)
