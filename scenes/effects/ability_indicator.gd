extends Node3D
class_name AbilityIndicator
## Visual indicator for ability targeting.
## Shows range circles, cones, and lines for aiming abilities.

enum IndicatorType {
	CIRCLE,      # AOE circle (Blizzard, Trap, Heroic Leap target)
	CONE,        # Directional cone (Cleave, Flame Wave, Arrow Wave)
	LINE,        # Linear path (Giant Arrow, Sunder)
	RING         # Range ring around player (Heroic Leap range, Frost Nova)
}

@export var indicator_type: IndicatorType = IndicatorType.CIRCLE
@export var radius: float = 5.0
@export var angle: float = 60.0  # For cones, in degrees
@export var length: float = 10.0  # For lines
@export var width: float = 1.5   # For lines
@export var color: Color = Color(0.5, 0.8, 1.0, 0.3)
@export var edge_color: Color = Color(0.8, 0.9, 1.0, 0.8)

var mesh_instance: MeshInstance3D = null
var edge_mesh: MeshInstance3D = null
var material: StandardMaterial3D = null
var edge_material: StandardMaterial3D = null

# Animation
var pulse_time: float = 0.0
const PULSE_SPEED: float = 6.0


func _ready() -> void:
	_create_indicator()


func _process(delta: float) -> void:
	pulse_time += delta
	_update_pulse()


func _create_indicator() -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()

	# Create material
	material = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 5

	# Create edge material
	edge_material = StandardMaterial3D.new()
	edge_material.albedo_color = edge_color
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	edge_material.no_depth_test = true
	edge_material.render_priority = 6

	match indicator_type:
		IndicatorType.CIRCLE:
			_create_circle()
		IndicatorType.CONE:
			_create_cone()
		IndicatorType.LINE:
			_create_line()
		IndicatorType.RING:
			_create_ring()


func _create_circle() -> void:
	# Create filled circle
	mesh_instance = MeshInstance3D.new()
	var circle_mesh := _generate_circle_mesh(radius, 32)
	mesh_instance.mesh = circle_mesh
	mesh_instance.material_override = material
	mesh_instance.rotation.x = -PI / 2  # Lay flat
	mesh_instance.position.y = 0.05  # Slightly above ground
	add_child(mesh_instance)

	# Create edge ring
	edge_mesh = MeshInstance3D.new()
	var ring_mesh := _generate_ring_mesh(radius - 0.1, radius, 32)
	edge_mesh.mesh = ring_mesh
	edge_mesh.material_override = edge_material
	edge_mesh.rotation.x = -PI / 2
	edge_mesh.position.y = 0.06
	add_child(edge_mesh)


func _create_cone() -> void:
	# Create filled cone
	mesh_instance = MeshInstance3D.new()
	var cone_mesh := _generate_cone_mesh(radius, deg_to_rad(angle), 16)
	mesh_instance.mesh = cone_mesh
	mesh_instance.material_override = material
	mesh_instance.rotation.x = -PI / 2
	mesh_instance.position.y = 0.05
	add_child(mesh_instance)

	# Create edge
	edge_mesh = MeshInstance3D.new()
	var edge := _generate_cone_edge_mesh(radius, deg_to_rad(angle), 16)
	edge_mesh.mesh = edge
	edge_mesh.material_override = edge_material
	edge_mesh.rotation.x = -PI / 2
	edge_mesh.position.y = 0.06
	add_child(edge_mesh)


func _create_line() -> void:
	# Create rectangle for line indicator
	mesh_instance = MeshInstance3D.new()
	var line_mesh := _generate_line_mesh(length, width)
	mesh_instance.mesh = line_mesh
	mesh_instance.material_override = material
	mesh_instance.rotation.x = -PI / 2
	mesh_instance.position.y = 0.05
	add_child(mesh_instance)

	# Create edge
	edge_mesh = MeshInstance3D.new()
	var edge := _generate_line_edge_mesh(length, width)
	edge_mesh.mesh = edge
	edge_mesh.material_override = edge_material
	edge_mesh.rotation.x = -PI / 2
	edge_mesh.position.y = 0.06
	add_child(edge_mesh)


func _create_ring() -> void:
	# Create ring (hollow circle)
	mesh_instance = MeshInstance3D.new()
	var ring_mesh := _generate_ring_mesh(radius - 0.3, radius, 32)
	mesh_instance.mesh = ring_mesh
	mesh_instance.material_override = material
	mesh_instance.rotation.x = -PI / 2
	mesh_instance.position.y = 0.05
	add_child(mesh_instance)

	# Outer edge
	edge_mesh = MeshInstance3D.new()
	var edge := _generate_ring_mesh(radius - 0.05, radius + 0.05, 32)
	edge_mesh.mesh = edge
	edge_mesh.material_override = edge_material
	edge_mesh.rotation.x = -PI / 2
	edge_mesh.position.y = 0.06
	add_child(edge_mesh)


func _generate_circle_mesh(r: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	# Center vertex
	vertices.append(Vector3.ZERO)

	# Edge vertices
	for i in range(segments + 1):
		var a := float(i) / segments * TAU
		vertices.append(Vector3(cos(a) * r, sin(a) * r, 0))

	# Triangles
	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append(i + 2)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _generate_ring_mesh(inner_r: float, outer_r: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	for i in range(segments + 1):
		var a := float(i) / segments * TAU
		var cos_a := cos(a)
		var sin_a := sin(a)
		vertices.append(Vector3(cos_a * inner_r, sin_a * inner_r, 0))
		vertices.append(Vector3(cos_a * outer_r, sin_a * outer_r, 0))

	for i in range(segments):
		var idx := i * 2
		indices.append(idx)
		indices.append(idx + 1)
		indices.append(idx + 2)
		indices.append(idx + 1)
		indices.append(idx + 3)
		indices.append(idx + 2)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _generate_cone_mesh(r: float, angle_rad: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	# Center vertex (at player position)
	vertices.append(Vector3.ZERO)

	# Arc vertices
	var half_angle := angle_rad / 2
	for i in range(segments + 1):
		var t := float(i) / segments
		var a := -half_angle + t * angle_rad
		vertices.append(Vector3(sin(a) * r, cos(a) * r, 0))

	# Triangles
	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append(i + 2)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _generate_cone_edge_mesh(r: float, angle_rad: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	var half_angle := angle_rad / 2
	var edge_width := 0.1

	# Arc edge (outer ring of the cone edge)
	for i in range(segments + 1):
		var t := float(i) / segments
		var a := -half_angle + t * angle_rad
		var inner_r := r - edge_width
		vertices.append(Vector3(sin(a) * inner_r, cos(a) * inner_r, 0))
		vertices.append(Vector3(sin(a) * r, cos(a) * r, 0))

	for i in range(segments):
		var idx := i * 2
		indices.append(idx)
		indices.append(idx + 1)
		indices.append(idx + 2)
		indices.append(idx + 1)
		indices.append(idx + 3)
		indices.append(idx + 2)

	# Side lines
	var base_idx := vertices.size()
	# Left side
	vertices.append(Vector3.ZERO)
	vertices.append(Vector3(sin(-half_angle) * r, cos(-half_angle) * r, 0))
	# Right side
	vertices.append(Vector3.ZERO)
	vertices.append(Vector3(sin(half_angle) * r, cos(half_angle) * r, 0))

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _generate_line_mesh(len: float, w: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	var half_w := w / 2
	vertices.append(Vector3(-half_w, 0, 0))
	vertices.append(Vector3(half_w, 0, 0))
	vertices.append(Vector3(-half_w, len, 0))
	vertices.append(Vector3(half_w, len, 0))

	indices.append(0)
	indices.append(1)
	indices.append(2)
	indices.append(1)
	indices.append(3)
	indices.append(2)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _generate_line_edge_mesh(len: float, w: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	var half_w := w / 2
	var edge := 0.1

	# Bottom edge
	vertices.append(Vector3(-half_w, -edge, 0))
	vertices.append(Vector3(half_w, -edge, 0))
	vertices.append(Vector3(-half_w, 0, 0))
	vertices.append(Vector3(half_w, 0, 0))

	# Top edge
	vertices.append(Vector3(-half_w, len, 0))
	vertices.append(Vector3(half_w, len, 0))
	vertices.append(Vector3(-half_w, len + edge, 0))
	vertices.append(Vector3(half_w, len + edge, 0))

	# Left edge
	vertices.append(Vector3(-half_w - edge, 0, 0))
	vertices.append(Vector3(-half_w, 0, 0))
	vertices.append(Vector3(-half_w - edge, len, 0))
	vertices.append(Vector3(-half_w, len, 0))

	# Right edge
	vertices.append(Vector3(half_w, 0, 0))
	vertices.append(Vector3(half_w + edge, 0, 0))
	vertices.append(Vector3(half_w, len, 0))
	vertices.append(Vector3(half_w + edge, len, 0))

	for i in range(4):
		var base := i * 4
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _update_pulse() -> void:
	if edge_material:
		var pulse := 0.5 + 0.5 * sin(pulse_time * PULSE_SPEED)
		var c := edge_color
		edge_material.albedo_color = Color(c.r, c.g, c.b, c.a * (0.5 + 0.5 * pulse))


func set_indicator_color(fill: Color, edge: Color) -> void:
	color = fill
	edge_color = edge
	if material:
		material.albedo_color = fill
	if edge_material:
		edge_material.albedo_color = edge


func point_at(target_position: Vector3) -> void:
	## Rotate indicator to point at target position (for cones/lines)
	var direction := target_position - global_position
	direction.y = 0
	if direction.length() > 0.1:
		var angle_y := atan2(direction.x, direction.z)
		rotation.y = angle_y + PI
