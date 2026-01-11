extends CraftingStation
class_name Forge
## Smelting station for processing ores into bars.

var fire_particles: GPUParticles3D = null


func _ready() -> void:
	station_type = RecipeDatabase.RecipeType.SMELTING
	station_name = "Forge"
	interaction_text = "Press F to use Forge"
	super._ready()

	_setup_fire_effect()


func _setup_fire_effect() -> void:
	# Create ambient fire particles
	fire_particles = GPUParticles3D.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = true
	fire_particles.amount = 20
	fire_particles.lifetime = 1.0
	fire_particles.position = Vector3(0, 0.5, 0)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0, 2, 0)

	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.8, 0.3))
	color_ramp.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = color_ramp
	material.color_ramp = color_texture

	fire_particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mesh_material := StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.emission_enabled = true
	mesh_material.emission = Color(1.0, 0.6, 0.2)
	mesh_material.emission_energy_multiplier = 3.0
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.surface_set_material(0, mesh_material)
	fire_particles.draw_pass_1 = mesh

	add_child(fire_particles)


func _play_crafting_effect() -> void:
	AudioManager.play_sound_3d("smelting_fire", global_position)

	# Intensify fire while smelting
	if fire_particles:
		fire_particles.amount = 40
		fire_particles.speed_scale = 1.5

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP * 0.5, 15)


func _play_completion_effect() -> void:
	AudioManager.play_sound_3d("smelting_complete", global_position)

	# Return fire to normal
	if fire_particles:
		fire_particles.amount = 20
		fire_particles.speed_scale = 1.0

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP, 25)
