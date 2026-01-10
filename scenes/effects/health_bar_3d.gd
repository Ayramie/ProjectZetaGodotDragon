extends Node3D
class_name HealthBar3D
## 3D health bar that billboards toward camera.

@export var max_value: float = 100.0
@export var current_value: float = 100.0
@export var bar_width: float = 1.0
@export var bar_height: float = 0.15
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var fill_color: Color = Color(0.8, 0.2, 0.2, 1.0)
@export var border_color: Color = Color(0.1, 0.1, 0.1, 1.0)

var background_mesh: MeshInstance3D
var fill_mesh: MeshInstance3D


func _ready() -> void:
	_create_bar()


func _create_bar() -> void:
	# Background
	background_mesh = MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(bar_width, bar_height)
	background_mesh.mesh = bg_quad

	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = background_color
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 10
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	background_mesh.material_override = bg_mat
	add_child(background_mesh)

	# Fill bar
	fill_mesh = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(bar_width, bar_height)
	fill_mesh.mesh = fill_quad

	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = fill_color
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.no_depth_test = true
	fill_mat.render_priority = 11
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mesh.material_override = fill_mat
	# Use layer offset via render priority instead of z position for billboard
	add_child(fill_mesh)

	_update_fill()


# Billboard mode is handled by the material, no _process needed


func set_value(value: float) -> void:
	current_value = clamp(value, 0, max_value)
	_update_fill()


func set_max_value(value: float) -> void:
	max_value = value
	_update_fill()


func _update_fill() -> void:
	if not fill_mesh:
		return

	var percent := current_value / max_value if max_value > 0 else 0.0
	var fill_width := bar_width * percent

	# Update mesh size
	var fill_quad := fill_mesh.mesh as QuadMesh
	if fill_quad:
		fill_quad.size = Vector2(fill_width, bar_height)

	# Offset to align left
	fill_mesh.position.x = (fill_width - bar_width) / 2.0

	# Color based on health
	var mat := fill_mesh.material_override as StandardMaterial3D
	if mat:
		if percent > 0.5:
			mat.albedo_color = Color(0.2, 0.8, 0.2)  # Green
		elif percent > 0.25:
			mat.albedo_color = Color(0.8, 0.8, 0.2)  # Yellow
		else:
			mat.albedo_color = Color(0.8, 0.2, 0.2)  # Red
