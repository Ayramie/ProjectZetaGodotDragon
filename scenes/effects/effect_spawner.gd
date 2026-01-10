extends Node
## Global effect spawner for damage numbers, particles, etc.
## Recreates the layered particle system from the original Three.js version.

var _projectile_script: GDScript = null
var _damage_number_scene: PackedScene = null


func spawn_damage_number(pos: Vector3, amount: int, critical: bool = false, heal: bool = false) -> void:
	var parent := get_tree().current_scene
	if not parent:
		return

	# Load damage number scene on first use
	if not _damage_number_scene:
		_damage_number_scene = load("res://scenes/effects/damage_number.tscn")

	var dmg_num: Node3D = _damage_number_scene.instantiate()
	dmg_num.set("damage_amount", amount)
	dmg_num.set("is_critical", critical)
	dmg_num.set("is_heal", heal)
	parent.add_child(dmg_num)
	dmg_num.global_position = pos


## Spawn particles with full options matching original Three.js system
func spawn_particles_advanced(pos: Vector3, options: Dictionary) -> void:
	var parent := get_tree().current_scene
	if not parent:
		return

	var count: int = options.get("count", 10)
	var color: Color = options.get("color", Color.WHITE)
	var end_color: Color = options.get("end_color", color.darkened(0.3))
	var size: float = options.get("size", 0.15)
	var end_size: float = options.get("end_size", size * 0.3)
	var speed: float = options.get("speed", 6.0)
	var spread: float = options.get("spread", 60.0)
	var life: float = options.get("life", 0.8)
	var gravity: float = options.get("gravity", -10.0)
	var upward_bias: float = options.get("upward_bias", 1.0)
	var drag: float = options.get("drag", 0.98)
	var additive: bool = options.get("additive", true)
	var texture_type: String = options.get("texture", "soft")

	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = count
	particles.lifetime = life

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, upward_bias, 0).normalized()
	material.spread = spread
	material.initial_velocity_min = speed * 0.7
	material.initial_velocity_max = speed * 1.3
	material.gravity = Vector3(0, gravity, 0)
	material.damping_min = (1.0 - drag) * 100
	material.damping_max = (1.0 - drag) * 100

	# Color gradient (start -> end)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.set_color(1, end_color)
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = color_ramp
	material.color_ramp = color_texture

	# Scale curve (size -> end_size with fade)
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, size / 0.15))  # Normalize to base size
	scale_curve.add_point(Vector2(0.7, size / 0.15))
	scale_curve.add_point(Vector2(1.0, end_size / 0.15))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	material.scale_curve = scale_texture

	# Alpha fade out
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.1, 1.0))
	alpha_curve.add_point(Vector2(0.6, 1.0))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_texture := CurveTexture.new()
	alpha_texture.curve = alpha_curve
	material.alpha_curve = alpha_texture

	particles.process_material = material

	# Create mesh based on texture type
	var mesh: Mesh
	var mesh_material := StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.vertex_color_use_as_albedo = true
	mesh_material.albedo_color = Color.WHITE
	mesh_material.emission_enabled = true
	mesh_material.emission = Color.WHITE
	mesh_material.emission_energy_multiplier = 3.0 if additive else 1.0
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX

	match texture_type:
		"spark":
			# Bright sharp point
			var sphere := SphereMesh.new()
			sphere.radius = 0.08
			sphere.height = 0.16
			mesh = sphere
			mesh_material.emission_energy_multiplier = 5.0
		"glow":
			# Large soft glow
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			mesh = sphere
			mesh_material.emission_energy_multiplier = 2.0
		"star":
			# Use a small box rotated as star-like
			var box := BoxMesh.new()
			box.size = Vector3(0.15, 0.15, 0.02)
			mesh = box
		"ring":
			# Torus for ring effect
			var torus := TorusMesh.new()
			torus.inner_radius = 0.1
			torus.outer_radius = 0.2
			mesh = torus
		"streak":
			# Elongated for motion trails
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.02
			cylinder.bottom_radius = 0.02
			cylinder.height = 0.3
			mesh = cylinder
		"ember":
			# Flame-like shape
			var prism := PrismMesh.new()
			prism.size = Vector3(0.1, 0.2, 0.1)
			mesh = prism
		"smoke":
			# Larger soft sphere, normal blend
			var sphere := SphereMesh.new()
			sphere.radius = 0.25
			sphere.height = 0.5
			mesh = sphere
			mesh_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			mesh_material.emission_energy_multiplier = 0.5
		_:  # "soft" default
			var sphere := SphereMesh.new()
			sphere.radius = 0.12
			sphere.height = 0.24
			mesh = sphere

	mesh.surface_set_material(0, mesh_material)
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos

	# Auto-remove after lifetime
	var timer := Timer.new()
	timer.wait_time = life + 0.5
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func():
		particles.queue_free()
	)
	particles.add_child(timer)


## Simple spawn wrapper for basic effects
func spawn_particles(effect_name: String, pos: Vector3, count: int = 10) -> void:
	# Map effect names to layered particle effects like the original
	match effect_name:
		"hit":
			_spawn_hit_effect(pos, count)
		"heal":
			_spawn_heal_effect(pos, count)
		"death":
			_spawn_death_effect(pos, count)
		"fire":
			_spawn_fire_effect(pos, count)
		"ice":
			_spawn_ice_effect(pos, count)
		"magic":
			_spawn_magic_effect(pos, count)
		_:
			_spawn_generic_effect(pos, count, Color.WHITE)


func _spawn_hit_effect(pos: Vector3, intensity: int) -> void:
	# Layer 1: Core flash
	spawn_particles_advanced(pos, {
		"count": 1,
		"texture": "glow",
		"color": Color(1.0, 1.0, 1.0),
		"end_color": Color(1.0, 0.4, 0.4),
		"size": 0.4,
		"end_size": 0.1,
		"speed": 0.5,
		"life": 0.2,
		"gravity": 0.0
	})
	# Layer 2: Main particles
	spawn_particles_advanced(pos, {
		"count": intensity,
		"texture": "soft",
		"color": Color(1.0, 0.3, 0.3),
		"end_color": Color(0.5, 0.1, 0.1),
		"size": 0.15,
		"end_size": 0.05,
		"speed": 8.0,
		"spread": 70.0,
		"life": 0.5,
		"gravity": -12.0
	})
	# Layer 3: Sparks
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.6),
		"texture": "spark",
		"color": Color(1.0, 0.7, 0.7),
		"size": 0.1,
		"speed": 12.0,
		"life": 0.3,
		"gravity": -15.0
	})


func _spawn_heal_effect(pos: Vector3, intensity: int) -> void:
	# Layer 1: Rising soft particles
	spawn_particles_advanced(pos, {
		"count": intensity,
		"texture": "soft",
		"color": Color(0.3, 1.0, 0.5),
		"end_color": Color(0.6, 1.0, 0.8),
		"size": 0.15,
		"end_size": 0.08,
		"speed": 3.0,
		"spread": 40.0,
		"upward_bias": 4.0,
		"life": 1.0,
		"gravity": 2.0  # Float upward
	})
	# Layer 2: Sparkles
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.5),
		"texture": "star",
		"color": Color(0.7, 1.0, 0.8),
		"size": 0.12,
		"speed": 2.0,
		"upward_bias": 3.0,
		"life": 0.8,
		"gravity": 1.0
	})


func _spawn_death_effect(pos: Vector3, intensity: int) -> void:
	# Layer 1: Core flash
	spawn_particles_advanced(pos, {
		"count": 1,
		"texture": "glow",
		"color": Color(1.0, 1.0, 1.0),
		"size": 0.6,
		"end_size": 0.1,
		"speed": 0.5,
		"life": 0.3,
		"gravity": 0.0
	})
	# Layer 2: Main burst
	spawn_particles_advanced(pos, {
		"count": int(intensity * 2),
		"texture": "soft",
		"color": Color(0.6, 0.6, 0.6),
		"end_color": Color(0.2, 0.2, 0.2),
		"size": 0.2,
		"end_size": 0.05,
		"speed": 13.0,
		"spread": 80.0,
		"life": 0.7,
		"gravity": -11.0
	})
	# Layer 3: Sparks
	spawn_particles_advanced(pos, {
		"count": intensity,
		"texture": "spark",
		"color": Color(1.0, 1.0, 0.8),
		"size": 0.1,
		"speed": 18.0,
		"life": 0.4,
		"gravity": -15.0
	})
	# Layer 4: Stars
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.5),
		"texture": "star",
		"color": Color(0.8, 0.8, 0.8),
		"size": 0.15,
		"speed": 6.0,
		"life": 0.6
	})
	# Layer 5: Expanding ring
	spawn_particles_advanced(pos, {
		"count": 3,
		"texture": "ring",
		"color": Color(0.7, 0.7, 0.7),
		"size": 0.2,
		"end_size": 0.8,
		"speed": 8.0,
		"spread": 20.0,
		"life": 0.5,
		"gravity": 0.0
	})


func _spawn_fire_effect(pos: Vector3, intensity: int) -> void:
	# Layer 1: Core flash
	spawn_particles_advanced(pos, {
		"count": 1,
		"texture": "glow",
		"color": Color(1.0, 1.0, 0.9),
		"end_color": Color(1.0, 0.6, 0.2),
		"size": 0.5,
		"end_size": 0.1,
		"speed": 0.5,
		"life": 0.25,
		"gravity": 0.0
	})
	# Layer 2: Main fire burst (embers)
	spawn_particles_advanced(pos, {
		"count": intensity,
		"texture": "ember",
		"color": Color(1.0, 0.5, 0.1),
		"end_color": Color(1.0, 0.15, 0.0),
		"size": 0.18,
		"end_size": 0.06,
		"speed": 10.0,
		"spread": 65.0,
		"life": 0.6,
		"gravity": -8.0,
		"upward_bias": 1.5
	})
	# Layer 3: Flying sparks
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.8),
		"texture": "spark",
		"color": Color(1.0, 1.0, 0.6),
		"size": 0.08,
		"speed": 15.0,
		"life": 0.4,
		"gravity": -12.0
	})
	# Layer 4: Smoke (normal blend)
	spawn_particles_advanced(pos + Vector3.UP * 0.3, {
		"count": int(intensity * 0.4),
		"texture": "smoke",
		"color": Color(0.4, 0.4, 0.4, 0.6),
		"end_color": Color(0.2, 0.2, 0.2, 0.0),
		"size": 0.3,
		"end_size": 0.5,
		"speed": 2.0,
		"spread": 30.0,
		"upward_bias": 3.0,
		"life": 1.0,
		"gravity": 3.0,
		"additive": false
	})


func _spawn_ice_effect(pos: Vector3, intensity: int) -> void:
	# Layer 1: Core glow
	spawn_particles_advanced(pos, {
		"count": 1,
		"texture": "glow",
		"color": Color(0.8, 0.95, 1.0),
		"size": 0.5,
		"end_size": 0.1,
		"speed": 0.5,
		"life": 0.3,
		"gravity": 0.0
	})
	# Layer 2: Ice shards
	spawn_particles_advanced(pos, {
		"count": intensity,
		"texture": "soft",
		"color": Color(0.5, 0.8, 1.0),
		"end_color": Color(0.7, 0.9, 1.0),
		"size": 0.15,
		"end_size": 0.05,
		"speed": 9.0,
		"spread": 70.0,
		"life": 0.6,
		"gravity": -10.0
	})
	# Layer 3: Sparkles
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.6),
		"texture": "star",
		"color": Color(0.9, 0.95, 1.0),
		"size": 0.1,
		"speed": 5.0,
		"life": 0.5
	})
	# Layer 4: Frost ring
	spawn_particles_advanced(pos, {
		"count": 2,
		"texture": "ring",
		"color": Color(0.6, 0.85, 1.0),
		"size": 0.15,
		"end_size": 0.6,
		"speed": 6.0,
		"spread": 15.0,
		"life": 0.4,
		"gravity": 0.0
	})


func _spawn_magic_effect(pos: Vector3, intensity: int) -> void:
	# Layer 1: Core glow
	spawn_particles_advanced(pos, {
		"count": 1,
		"texture": "glow",
		"color": Color(0.7, 0.7, 1.0),
		"size": 0.4,
		"end_size": 0.1,
		"speed": 0.5,
		"life": 0.25,
		"gravity": 0.0
	})
	# Layer 2: Magic particles
	spawn_particles_advanced(pos, {
		"count": intensity,
		"texture": "soft",
		"color": Color(0.4, 0.5, 1.0),
		"end_color": Color(0.6, 0.4, 1.0),
		"size": 0.14,
		"end_size": 0.05,
		"speed": 7.0,
		"spread": 60.0,
		"life": 0.6,
		"gravity": -6.0
	})
	# Layer 3: Magic stars
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.5),
		"texture": "star",
		"color": Color(0.8, 0.7, 1.0),
		"size": 0.12,
		"speed": 4.0,
		"life": 0.7
	})
	# Layer 4: Streaks
	spawn_particles_advanced(pos, {
		"count": int(intensity * 0.3),
		"texture": "streak",
		"color": Color(0.6, 0.5, 1.0),
		"size": 0.1,
		"speed": 10.0,
		"life": 0.3
	})


func _spawn_generic_effect(pos: Vector3, count: int, color: Color) -> void:
	spawn_particles_advanced(pos, {
		"count": count,
		"texture": "soft",
		"color": color,
		"size": 0.15,
		"speed": 6.0,
		"life": 0.6
	})


func spawn_projectile(config: Dictionary) -> Node3D:
	var parent := get_tree().current_scene
	if not parent:
		return null

	# Load projectile script on first use to avoid circular dependency
	if not _projectile_script:
		_projectile_script = load("res://scenes/effects/projectile.gd")

	return _projectile_script.create(parent, config)
