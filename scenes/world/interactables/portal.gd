extends InteractableBase
class_name Portal
## Portal for traveling between scenes (town <-> adventure areas).

@export var destination_scene: String = ""
@export var destination_spawn: String = ""
@export var portal_name: String = "Portal"
@export var portal_color: Color = Color(0.3, 0.5, 1.0)

var portal_mesh: MeshInstance3D = null
var portal_light: OmniLight3D = null


func _ready() -> void:
	prompt_text = "Press F to enter " + portal_name
	super._ready()
	_create_visual()


func _setup_collision() -> void:
	# Portal doesn't need collision - player can walk through
	pass


func _create_visual() -> void:
	# Create torus portal ring
	portal_mesh = MeshInstance3D.new()
	portal_mesh.name = "PortalMesh"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.8
	portal_mesh.mesh = torus
	portal_mesh.rotation_degrees.x = 90
	portal_mesh.position.y = 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = portal_color
	mat.emission_enabled = true
	mat.emission = portal_color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	portal_mesh.material_override = mat
	add_child(portal_mesh)

	# Create inner glow plane
	var inner_mesh := MeshInstance3D.new()
	inner_mesh.name = "InnerGlow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	inner_mesh.mesh = plane
	inner_mesh.rotation_degrees.x = 90
	inner_mesh.position.y = 2.0

	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.4)
	inner_mat.emission_enabled = true
	inner_mat.emission = portal_color
	inner_mat.emission_energy_multiplier = 2.0
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_mesh.material_override = inner_mat
	add_child(inner_mesh)

	# Add point light
	portal_light = OmniLight3D.new()
	portal_light.name = "PortalLight"
	portal_light.position.y = 2.0
	portal_light.light_color = portal_color
	portal_light.light_energy = 2.5
	portal_light.omni_range = 8.0
	add_child(portal_light)

	# Add base pedestal
	var base := MeshInstance3D.new()
	base.name = "Base"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.0
	cylinder.bottom_radius = 2.2
	cylinder.height = 0.3
	base.mesh = cylinder
	base.position.y = 0.15

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.3, 0.3, 0.35)
	base.material_override = base_mat
	add_child(base)


func _process(delta: float) -> void:
	# Rotate portal ring slowly
	if portal_mesh:
		portal_mesh.rotate_z(delta * 0.5)


func _start_interaction() -> void:
	if destination_scene.is_empty():
		EventBus.show_message.emit("This portal leads nowhere...", Color.YELLOW, 2.0)
		return

	# Show travel message
	EventBus.show_message.emit("Traveling to " + portal_name + "...", Color.WHITE, 1.0)
	AudioManager.play_sound("portal_enter")

	# Transition after short delay
	await get_tree().create_timer(0.5).timeout
	_transition_to_destination()


func _transition_to_destination() -> void:
	# Save spawn point for destination scene
	if not destination_spawn.is_empty():
		SaveManager.set_spawn_point(destination_spawn)

	# Preserve player state before scene change
	if GameManager.player:
		SaveManager.prepare_scene_transition()

	# Transition to destination scene
	get_tree().change_scene_to_file(destination_scene)
