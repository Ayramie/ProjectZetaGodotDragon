extends Node3D
class_name Projectile
## Base projectile class for arrows, magic bolts, and special projectiles.

signal hit_enemy(enemy: Node3D)
signal expired()

# Projectile properties
var direction: Vector3 = Vector3.FORWARD
var speed: float = 15.0
var damage: int = 10
var source: Node3D = null
var piercing: bool = false
var max_range: float = 30.0
var projectile_type: String = "arrow"

# Special properties for frozen orb
var tick_damage: int = 0
var explosion_damage: int = 0
var tick_timer: float = 0.0
var tick_interval: float = 0.2

# Internal state
var distance_traveled: float = 0.0
var hit_enemies: Array[Node3D] = []

# Visual
var mesh_instance: MeshInstance3D = null


func _ready() -> void:
	# Create visual mesh based on type
	mesh_instance = MeshInstance3D.new()
	_setup_visual()
	add_child(mesh_instance)


func _setup_visual() -> void:
	var mesh: Mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match projectile_type:
		"arrow", "giant_arrow":
			# Elongated cylinder for arrow
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.03 if projectile_type == "arrow" else 0.06
			cylinder.bottom_radius = 0.03 if projectile_type == "arrow" else 0.06
			cylinder.height = 0.6 if projectile_type == "arrow" else 1.2
			mesh = cylinder
			material.albedo_color = Color(0.6, 0.4, 0.2) if projectile_type == "arrow" else Color(0.8, 0.6, 0.3)
			# Rotate mesh to point forward
			mesh_instance.rotation.x = PI / 2
		"magic_bolt":
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			sphere.height = 0.3
			mesh = sphere
			material.albedo_color = Color(0.4, 0.6, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.3, 0.5, 1.0)
			material.emission_energy_multiplier = 2.0
		"frozen_orb":
			var sphere := SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.8
			mesh = sphere
			material.albedo_color = Color(0.5, 0.8, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.4, 0.7, 1.0)
			material.emission_energy_multiplier = 3.0
		_:
			var sphere := SphereMesh.new()
			sphere.radius = 0.1
			sphere.height = 0.2
			mesh = sphere
			material.albedo_color = Color.WHITE

	mesh.surface_set_material(0, material)
	mesh_instance.mesh = mesh


func _physics_process(delta: float) -> void:
	# Move projectile
	var move_distance := speed * delta
	global_position += direction * move_distance
	distance_traveled += move_distance

	# Check for enemy collisions using distance
	_check_enemy_collisions()

	# Frozen orb ticks damage in radius
	if projectile_type == "frozen_orb" and tick_damage > 0:
		tick_timer += delta
		if tick_timer >= tick_interval:
			tick_timer = 0.0
			_do_area_damage(tick_damage, 2.5, false)

	# Check max range
	if distance_traveled >= max_range:
		_on_expired()


func _check_enemy_collisions() -> void:
	var hit_radius := 0.8 if projectile_type == "giant_arrow" else 0.5

	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		# Skip already hit enemies (for piercing)
		if enemy in hit_enemies:
			continue

		var distance := global_position.distance_to(enemy.global_position + Vector3.UP)
		if distance <= hit_radius:
			_hit_enemy(enemy)
			if not piercing:
				return


func _hit_enemy(enemy: Node3D) -> void:
	hit_enemies.append(enemy)

	# Deal damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, source)

	# Spawn hit effect (use get_node to avoid circular dependency)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner and spawner.has_method("spawn_particles"):
		spawner.call("spawn_particles", "hit", global_position, 5)

	hit_enemy.emit(enemy)

	# Destroy if not piercing
	if not piercing:
		_destroy()


func _on_expired() -> void:
	# Frozen orb explodes at end
	if projectile_type == "frozen_orb" and explosion_damage > 0:
		_do_area_damage(explosion_damage, 4.0, true)
		var spawner := get_node_or_null("/root/EffectSpawner")
		if spawner and spawner.has_method("spawn_particles"):
			spawner.call("spawn_particles", "ice", global_position, 20)
		AudioManager.play_sound_3d("frost_nova", global_position)

	expired.emit()
	_destroy()


func _do_area_damage(dmg: int, radius: float, stun: bool) -> void:
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg, source)
			if stun and enemy.has_method("apply_stun"):
				enemy.apply_stun(1.0)


func _destroy() -> void:
	queue_free()


# Static factory method
static func create(parent: Node, config: Dictionary) -> Projectile:
	var projectile := Projectile.new()

	projectile.projectile_type = config.get("type", "arrow")
	projectile.direction = config.get("direction", Vector3.FORWARD).normalized()
	projectile.speed = config.get("speed", 15.0)
	projectile.damage = config.get("damage", 10)
	projectile.source = config.get("source", null)
	projectile.piercing = config.get("piercing", false)
	projectile.max_range = config.get("max_range", 30.0)
	projectile.tick_damage = config.get("tick_damage", 0)
	projectile.explosion_damage = config.get("explosion_damage", 0)

	# Add to tree first, then set position
	parent.add_child(projectile)
	projectile.global_position = config.get("position", Vector3.ZERO)

	# Face direction
	if projectile.direction.length() > 0.01:
		projectile.look_at(projectile.global_position + projectile.direction, Vector3.UP)

	return projectile
