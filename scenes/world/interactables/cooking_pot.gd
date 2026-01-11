extends CraftingStation
class_name CookingPot
## Cooking station for preparing food items.

var steam_particles: GPUParticles3D = null
var bubble_timer: float = 0.0
const BUBBLE_INTERVAL: float = 0.8


func _ready() -> void:
	station_type = RecipeDatabase.RecipeType.COOKING
	station_name = "Cooking Pot"
	interaction_text = "Press F to use Cooking Pot"
	super._ready()

	_setup_steam_effect()


func _setup_steam_effect() -> void:
	steam_particles = GPUParticles3D.new()
	steam_particles.name = "SteamParticles"
	steam_particles.emitting = true
	steam_particles.amount = 8
	steam_particles.lifetime = 2.0
	steam_particles.position = Vector3(0, 0.8, 0)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 20.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.0
	material.gravity = Vector3(0, 0.5, 0)

	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.9, 0.9, 0.9, 0.4))
	color_ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = color_ramp
	material.color_ramp = color_texture

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(1.0, 1.5))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	material.scale_curve = scale_texture

	steam_particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	var mesh_material := StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mesh_material)
	steam_particles.draw_pass_1 = mesh

	add_child(steam_particles)


func _process(delta: float) -> void:
	super._process(delta)

	# Bubble sounds while cooking
	if is_crafting:
		bubble_timer -= delta
		if bubble_timer <= 0:
			bubble_timer = BUBBLE_INTERVAL + randf() * 0.4
			AudioManager.play_sound_3d("cooking_sizzle", global_position)


func _play_crafting_effect() -> void:
	bubble_timer = 0.0
	AudioManager.play_sound_3d("cooking_sizzle", global_position)

	# More steam while cooking
	if steam_particles:
		steam_particles.amount = 20
		steam_particles.speed_scale = 1.5


func _play_completion_effect() -> void:
	bubble_timer = 999.0
	AudioManager.play_sound_3d("cooking_complete", global_position)

	# Return steam to normal
	if steam_particles:
		steam_particles.amount = 8
		steam_particles.speed_scale = 1.0

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("heal", global_position + Vector3.UP, 15)
