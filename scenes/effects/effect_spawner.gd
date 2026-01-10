extends Node
## Global effect spawner for damage numbers, particles, etc.

static var instance: Node = null
static var _projectile_script: GDScript = null
static var _damage_number_scene: PackedScene = null


func _ready() -> void:
	instance = self


static func spawn_damage_number(pos: Vector3, amount: int, critical: bool = false, heal: bool = false) -> void:
	if not instance:
		return
	var parent := instance.get_tree().current_scene
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


static func spawn_particles(effect_name: String, pos: Vector3, count: int = 10) -> void:
	if not instance:
		return

	# Create simple particle effect
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = count
	particles.lifetime = 0.8

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -10, 0)

	# Color based on effect type
	match effect_name:
		"hit":
			material.color = Color(1.0, 0.3, 0.3)
		"heal":
			material.color = Color(0.3, 1.0, 0.3)
		"death":
			material.color = Color(0.5, 0.5, 0.5)
			particles.amount = 20
		"magic":
			material.color = Color(0.3, 0.5, 1.0)
		"fire":
			material.color = Color(1.0, 0.5, 0.1)
		"ice":
			material.color = Color(0.5, 0.8, 1.0)
		_:
			material.color = Color(1.0, 1.0, 1.0)

	particles.process_material = material

	# Simple mesh for particles
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	instance.get_tree().current_scene.add_child(particles)
	particles.global_position = pos

	# Auto-remove after lifetime
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func():
		particles.queue_free()
		timer.queue_free()
	)
	particles.add_child(timer)


static func spawn_projectile(config: Dictionary) -> Node3D:
	if not instance:
		return null
	var parent := instance.get_tree().current_scene
	if not parent:
		return null

	# Load projectile script on first use to avoid circular dependency
	if not _projectile_script:
		_projectile_script = load("res://scenes/effects/projectile.gd")

	return _projectile_script.create(parent, config)
