extends StaticBody3D
class_name Building
## Base class for all buildings in the game.
## Buildings have collision, can be placed, moved, and saved.

signal building_placed(building: Building)
signal building_removed(building: Building)

@export var building_id: String = "building"
@export var building_name: String = "Building"
@export var building_size: Vector3 = Vector3(6, 4, 5)  # Width, Height, Depth
@export var roof_color: Color = Color(0.55, 0.25, 0.2)
@export var wall_color: Color = Color(0.85, 0.8, 0.7)
@export var has_sign: bool = true
@export var sign_text: String = ""

# Building components
var base_mesh: MeshInstance3D = null
var roof_mesh: MeshInstance3D = null
var door_mesh: MeshInstance3D = null
var sign_label: Label3D = null
var collision_shape: CollisionShape3D = null

# Placement state
var is_placed: bool = true
var is_preview: bool = false  # True when showing placement preview


func _ready() -> void:
	_build_structure()
	_setup_collision()


func _build_structure() -> void:
	# Create base/walls
	base_mesh = MeshInstance3D.new()
	base_mesh.name = "Base"
	var base_box := BoxMesh.new()
	base_box.size = building_size
	base_mesh.mesh = base_box
	base_mesh.position.y = building_size.y / 2

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = wall_color
	wall_mat.roughness = 0.9
	base_mesh.material_override = wall_mat
	add_child(base_mesh)

	# Create roof
	roof_mesh = MeshInstance3D.new()
	roof_mesh.name = "Roof"
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(building_size.x + 1, 0.5, building_size.z + 1)
	roof_mesh.mesh = roof_box
	roof_mesh.position.y = building_size.y + 0.25

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_color
	roof_mat.roughness = 0.75
	roof_mesh.material_override = roof_mat
	add_child(roof_mesh)

	# Create door
	door_mesh = MeshInstance3D.new()
	door_mesh.name = "Door"
	var door_box := BoxMesh.new()
	door_box.size = Vector3(1.2, 2.2, 0.2)
	door_mesh.mesh = door_box
	door_mesh.position = Vector3(0, 1.1, building_size.z / 2 + 0.05)

	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.35, 0.25, 0.15)
	door_mat.roughness = 0.7
	door_mesh.material_override = door_mat
	add_child(door_mesh)

	# Create sign if enabled
	if has_sign and not sign_text.is_empty():
		sign_label = Label3D.new()
		sign_label.name = "Sign"
		sign_label.text = sign_text
		sign_label.font_size = 48
		sign_label.position = Vector3(0, building_size.y - 0.5, building_size.z / 2 + 0.1)
		sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		add_child(sign_label)


func _setup_collision() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var box_shape := BoxShape3D.new()
	box_shape.size = building_size
	collision_shape.shape = box_shape
	collision_shape.position.y = building_size.y / 2
	add_child(collision_shape)

	# Set collision layers - buildings should block characters
	collision_layer = 1  # Default layer
	collision_mask = 0  # Buildings don't detect collisions


func set_preview_mode(enabled: bool) -> void:
	is_preview = enabled
	is_placed = not enabled

	# Make semi-transparent in preview mode
	var alpha := 0.5 if enabled else 1.0
	if base_mesh and base_mesh.material_override:
		var mat: StandardMaterial3D = base_mesh.material_override
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color.a = alpha

	# Disable collision in preview mode
	collision_shape.disabled = enabled


func place() -> void:
	set_preview_mode(false)
	is_placed = true
	building_placed.emit(self)


func remove() -> void:
	building_removed.emit(self)
	queue_free()


func get_save_data() -> Dictionary:
	return {
		"building_id": building_id,
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"rotation_y": rotation.y,
		"building_name": building_name,
		"sign_text": sign_text
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = Vector3(data.position.x, data.position.y, data.position.z)
	if data.has("rotation_y"):
		rotation.y = data.rotation_y
	if data.has("sign_text"):
		sign_text = data.sign_text
		if sign_label:
			sign_label.text = sign_text


static func create_building(id: String) -> Building:
	## Factory method to create buildings by ID
	var building: Building = null
	match id:
		"general_store":
			building = GeneralStoreBuilding.new()
		"blacksmith":
			building = BlacksmithBuilding.new()
		"healer":
			building = HealerBuilding.new()
		"bank":
			building = BankBuilding.new()
		"inn":
			building = InnBuilding.new()
		"house_small":
			building = SmallHouseBuilding.new()
		_:
			building = Building.new()
			building.building_id = id
	return building


static func get_available_building_ids() -> Array[String]:
	return ["general_store", "blacksmith", "healer", "bank", "inn", "house_small"]
