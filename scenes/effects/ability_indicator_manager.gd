extends Node3D
class_name AbilityIndicatorManager
## Manages ability indicators for targeting skills.
## Shows/hides indicators based on ability key states.

# Reference to camera for mouse world position
var camera: Node3D = null

# Active indicators (keyed by ability key)
var indicators: Dictionary = {}

# Current aiming state
var aiming_ability: String = ""
var aiming_indicator: AbilityIndicator = null

# Colors for different ability types
const COLORS := {
	"damage": {
		"fill": Color(1.0, 0.3, 0.2, 0.25),
		"edge": Color(1.0, 0.5, 0.3, 0.8)
	},
	"ice": {
		"fill": Color(0.3, 0.7, 1.0, 0.25),
		"edge": Color(0.5, 0.8, 1.0, 0.8)
	},
	"fire": {
		"fill": Color(1.0, 0.5, 0.1, 0.25),
		"edge": Color(1.0, 0.7, 0.3, 0.8)
	},
	"utility": {
		"fill": Color(0.5, 1.0, 0.5, 0.25),
		"edge": Color(0.7, 1.0, 0.7, 0.8)
	},
	"range": {
		"fill": Color(0.8, 0.8, 0.8, 0.15),
		"edge": Color(0.9, 0.9, 0.9, 0.5)
	}
}


func setup(cam: Node3D) -> void:
	camera = cam


func create_indicator(ability_key: String, config: Dictionary) -> AbilityIndicator:
	## Create an indicator for an ability.
	## Config: { type: IndicatorType, radius/angle/length/width, color_type }

	var indicator := AbilityIndicator.new()
	indicator.indicator_type = config.get("type", AbilityIndicator.IndicatorType.CIRCLE)
	indicator.radius = config.get("radius", 5.0)
	indicator.angle = config.get("angle", 60.0)
	indicator.length = config.get("length", 10.0)
	indicator.width = config.get("width", 1.5)

	# Apply colors
	var color_type: String = config.get("color_type", "damage")
	var colors: Dictionary = COLORS.get(color_type, COLORS.damage)
	indicator.color = colors.fill
	indicator.edge_color = colors.edge

	indicator.visible = false
	add_child(indicator)

	indicators[ability_key] = indicator
	return indicator


func create_range_indicator(ability_key: String, range_radius: float) -> AbilityIndicator:
	## Create a range ring indicator (shows max range).
	return create_indicator(ability_key + "_range", {
		"type": AbilityIndicator.IndicatorType.RING,
		"radius": range_radius,
		"color_type": "range"
	})


func show_indicator(ability_key: String) -> void:
	## Show indicator for ability and start aiming mode.
	if not indicators.has(ability_key):
		return

	# Hide previous indicator if any
	if aiming_indicator and is_instance_valid(aiming_indicator):
		aiming_indicator.visible = false

	# Also hide range indicator if exists
	var range_key := aiming_ability + "_range"
	if indicators.has(range_key):
		indicators[range_key].visible = false

	aiming_ability = ability_key
	aiming_indicator = indicators[ability_key]
	aiming_indicator.visible = true

	# Show range indicator if exists
	range_key = ability_key + "_range"
	if indicators.has(range_key):
		indicators[range_key].visible = true


func hide_indicator(ability_key: String = "") -> void:
	## Hide indicator and exit aiming mode.
	if ability_key.is_empty():
		ability_key = aiming_ability

	if indicators.has(ability_key):
		indicators[ability_key].visible = false

	# Hide range indicator if exists
	var range_key := ability_key + "_range"
	if indicators.has(range_key):
		indicators[range_key].visible = false

	if aiming_ability == ability_key:
		aiming_ability = ""
		aiming_indicator = null


func hide_all() -> void:
	## Hide all indicators.
	for key in indicators:
		indicators[key].visible = false
	aiming_ability = ""
	aiming_indicator = null


func is_aiming() -> bool:
	return not aiming_ability.is_empty()


func get_aiming_ability() -> String:
	return aiming_ability


func update_indicator_position(player_pos: Vector3) -> void:
	## Update indicator position based on ability type.
	if not aiming_indicator or not is_instance_valid(aiming_indicator):
		return

	var mouse_world := _get_mouse_world_position()

	match aiming_indicator.indicator_type:
		AbilityIndicator.IndicatorType.CIRCLE:
			# Circle follows mouse (for targeted AoE like Blizzard, Trap)
			aiming_indicator.global_position = mouse_world
			aiming_indicator.global_position.y = 0.05

		AbilityIndicator.IndicatorType.CONE:
			# Cone starts at player, points at mouse
			aiming_indicator.global_position = player_pos
			aiming_indicator.global_position.y = 0.05
			aiming_indicator.point_at(mouse_world)

		AbilityIndicator.IndicatorType.LINE:
			# Line starts at player, points at mouse
			aiming_indicator.global_position = player_pos
			aiming_indicator.global_position.y = 0.05
			aiming_indicator.point_at(mouse_world)

		AbilityIndicator.IndicatorType.RING:
			# Ring stays centered on player
			aiming_indicator.global_position = player_pos
			aiming_indicator.global_position.y = 0.05

	# Update range indicators (always centered on player)
	var range_key := aiming_ability + "_range"
	if indicators.has(range_key):
		indicators[range_key].global_position = player_pos
		indicators[range_key].global_position.y = 0.04


func _get_mouse_world_position() -> Vector3:
	if camera and camera.has_method("get_mouse_world_position"):
		return camera.get_mouse_world_position()

	# Fallback: raycast from camera
	var viewport := get_viewport()
	if not viewport:
		return Vector3.ZERO

	var mouse_pos := viewport.get_mouse_position()
	var cam := viewport.get_camera_3d()
	if not cam:
		return Vector3.ZERO

	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 1000

	# Intersect with ground plane (y=0)
	if to.y != from.y:
		var t := -from.y / (to.y - from.y)
		if t > 0:
			return from + (to - from) * t

	return Vector3.ZERO


func get_aim_direction(player_pos: Vector3) -> Vector3:
	## Get direction from player to mouse.
	var mouse_world := _get_mouse_world_position()
	var direction := mouse_world - player_pos
	direction.y = 0
	return direction.normalized() if direction.length() > 0.1 else Vector3.FORWARD


func get_aim_position() -> Vector3:
	## Get mouse world position for placement abilities.
	return _get_mouse_world_position()
