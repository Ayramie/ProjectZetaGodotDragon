extends Player
class_name Adventurer
## Adventurer class implementation.
## Dynamic class that gains abilities based on equipped weapon type.

enum WeaponType { MELEE, MAGIC, RANGED }

var current_weapon_type: WeaponType = WeaponType.MELEE

# References to ability implementations
var warrior_abilities: Dictionary = {}
var mage_abilities: Dictionary = {}
var hunter_abilities: Dictionary = {}


func _ready() -> void:
	super._ready()

	ability_cooldowns = {
		"q": 0.0,
		"f": 0.0,
		"e": 0.0,
		"r": 0.0,
		"c": 0.0
	}

	# Connect to equipment changes
	EventBus.equipment_changed.connect(_on_equipment_changed)


func _on_equipment_changed(slot: String, item_id: String) -> void:
	if slot != "weapon":
		return

	# Determine weapon type from item
	var item_def: Dictionary = ItemDatabase.get_item(item_id)
	if item_def.is_empty():
		current_weapon_type = WeaponType.MELEE
		return

	# Check class restriction to determine type
	var restrictions: Array = item_def.get("class_restriction", [])
	if "mage" in restrictions:
		current_weapon_type = WeaponType.MAGIC
		attack_range = 15.0
	elif "hunter" in restrictions:
		current_weapon_type = WeaponType.RANGED
		attack_range = 18.0
	else:
		current_weapon_type = WeaponType.MELEE
		attack_range = 2.5


func _input(event: InputEvent) -> void:
	if not is_alive:
		return

	if event.is_action_pressed("ability_q"):
		use_ability_q()
	elif event.is_action_pressed("ability_f"):
		use_ability_f()
	elif event.is_action_pressed("ability_e"):
		use_ability_e()
	elif event.is_action_pressed("ability_r"):
		use_ability_r()
	elif event.is_action_pressed("ability_c"):
		use_ability_c()


func perform_auto_attack() -> void:
	## Auto-attack based on weapon type.
	match current_weapon_type:
		WeaponType.MELEE:
			_melee_auto_attack()
		WeaponType.MAGIC:
			_magic_auto_attack()
		WeaponType.RANGED:
			_ranged_auto_attack()


func _melee_auto_attack() -> void:
	## Standard melee attack.
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	attack_cooldown = attack_cooldown_max

	var to_target := target_enemy.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.1:
		model.rotation.y = atan2(to_target.x, to_target.z)

	var damage := attack_damage + _get_damage_bonus()
	target_enemy.take_damage(damage, self)

	AudioManager.play_sound_3d("sword_swing", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("hit", global_position + Vector3.UP, 5)

	is_attacking = true
	await get_tree().create_timer(0.3).timeout
	is_attacking = false


func _magic_auto_attack() -> void:
	## Ranged magic bolt attack.
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	attack_cooldown = attack_cooldown_max

	var to_target := target_enemy.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.1:
		model.rotation.y = atan2(to_target.x, to_target.z)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "magic_bolt",
			"position": global_position + Vector3.UP,
			"direction": to_target.normalized(),
			"speed": 15.0,
			"damage": attack_damage + _get_damage_bonus(),
			"source": self
		})

	AudioManager.play_sound_3d("spell_cast", global_position)

	is_attacking = true
	await get_tree().create_timer(0.3).timeout
	is_attacking = false


func _ranged_auto_attack() -> void:
	## Ranged arrow attack.
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	attack_cooldown = attack_cooldown_max

	var to_target := target_enemy.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.1:
		model.rotation.y = atan2(to_target.x, to_target.z)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "arrow",
			"position": global_position + Vector3.UP,
			"direction": to_target.normalized(),
			"speed": 18.0,
			"damage": attack_damage + _get_damage_bonus(),
			"source": self
		})

	AudioManager.play_sound_3d("bow_shoot", global_position)

	is_attacking = true
	await get_tree().create_timer(0.2).timeout
	is_attacking = false


# Abilities change based on weapon type
func use_ability_q() -> void:
	match current_weapon_type:
		WeaponType.MELEE:
			_use_cleave()
		WeaponType.MAGIC:
			_use_flame_wave()
		WeaponType.RANGED:
			_use_arrow_wave()


func use_ability_f() -> void:
	match current_weapon_type:
		WeaponType.MELEE:
			_use_whirlwind()
		WeaponType.MAGIC:
			_use_blizzard()
		WeaponType.RANGED:
			_use_spin_dash()


func use_ability_e() -> void:
	match current_weapon_type:
		WeaponType.MELEE:
			_use_parry()
		WeaponType.MAGIC:
			_use_frost_nova()
		WeaponType.RANGED:
			_use_shotgun()


func use_ability_r() -> void:
	match current_weapon_type:
		WeaponType.MELEE:
			_use_heroic_leap()
		WeaponType.MAGIC:
			_use_frozen_orb()
		WeaponType.RANGED:
			_use_trap()


func use_ability_c() -> void:
	match current_weapon_type:
		WeaponType.MELEE:
			_use_sunder()
		WeaponType.MAGIC:
			_use_blink()
		WeaponType.RANGED:
			_use_giant_arrow()


# Warrior abilities (simplified versions)
func _use_cleave() -> void:
	if ability_cooldowns["q"] > 0:
		return
	ability_cooldowns["q"] = 4.0

	var direction := model.global_transform.basis.z.normalized()
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0
		if to_enemy.length() <= 8.0:
			var angle := direction.angle_to(to_enemy.normalized())
			if angle <= deg_to_rad(54.0):
				enemy.take_damage(35, self)

	AudioManager.play_sound_3d("cleave", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP * 0.5, 15)


func _use_whirlwind() -> void:
	if ability_cooldowns["f"] > 0:
		return
	ability_cooldowns["f"] = 6.0

	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) <= 3.5:
			enemy.take_damage(28, self)

	AudioManager.play_sound_3d("whirlwind", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP, 20)


func _use_parry() -> void:
	if ability_cooldowns["e"] > 0:
		return
	ability_cooldowns["e"] = 5.0
	AudioManager.play_sound_3d("parry", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position + Vector3.UP, 12)


func _use_heroic_leap() -> void:
	if ability_cooldowns["r"] > 0:
		return
	ability_cooldowns["r"] = 10.0
	AudioManager.play_sound_3d("heroic_leap", global_position)


func _use_sunder() -> void:
	if ability_cooldowns["c"] > 0:
		return
	ability_cooldowns["c"] = 5.0
	AudioManager.play_sound_3d("sunder", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("fire", global_position + Vector3.UP, 15)


# Mage abilities (simplified)
func _use_flame_wave() -> void:
	if ability_cooldowns["q"] > 0:
		return
	ability_cooldowns["q"] = 6.0

	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Cone damage
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0
		var distance := to_enemy.length()
		if distance <= 8.0:
			var angle := direction.angle_to(to_enemy.normalized())
			if angle <= deg_to_rad(54.0):
				enemy.take_damage(35, self)

	AudioManager.play_sound_3d("flame_wave", global_position)


func _use_blizzard() -> void:
	if ability_cooldowns["f"] > 0:
		return
	ability_cooldowns["f"] = 8.0
	var target_pos := global_position
	if camera:
		target_pos = camera.get_mouse_world_position()
	AudioManager.play_sound_3d("blizzard", target_pos)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("ice", target_pos, 25)


func _use_frost_nova() -> void:
	if ability_cooldowns["e"] > 0:
		return
	ability_cooldowns["e"] = 8.0
	for enemy in GameManager.enemies:
		if not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) <= 6.0:
			enemy.take_damage(20, self)
			enemy.apply_stun(2.0)
	AudioManager.play_sound_3d("frost_nova", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("ice", global_position, 30)


func _use_frozen_orb() -> void:
	if ability_cooldowns["r"] > 0:
		return
	ability_cooldowns["r"] = 10.0

	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "frozen_orb",
			"position": global_position + Vector3.UP,
			"direction": direction,
			"speed": 8.0,
			"damage": 15,
			"tick_damage": 15,
			"explosion_damage": 40,
			"max_range": 25.0,
			"source": self
		})

	AudioManager.play_sound_3d("spell_cast", global_position)


func _use_blink() -> void:
	if ability_cooldowns["c"] > 0:
		return
	ability_cooldowns["c"] = 5.0
	var back := -model.global_transform.basis.z.normalized()
	var target_pos := global_position + back * 6.0
	target_pos = GameManager.clamp_position_to_bounds(target_pos)
	global_position = target_pos
	AudioManager.play_sound_3d("blink", global_position)
	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_particles("magic", global_position, 15)


# Hunter abilities (simplified)
func _use_arrow_wave() -> void:
	if ability_cooldowns["q"] > 0:
		return
	ability_cooldowns["q"] = 6.0

	var center_direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			center_direction = to_mouse.normalized()
			model.rotation.y = atan2(center_direction.x, center_direction.z)

	# Spawn arrows in a fan pattern
	var arrow_count := 8
	var spread := deg_to_rad(90.0)
	var angle_step := spread / (arrow_count - 1)
	var start_angle := -spread / 2

	var spawner := get_node_or_null("/root/EffectSpawner")
	for i in arrow_count:
		var angle := start_angle + angle_step * i
		var rotated_dir := Vector3(
			center_direction.x * cos(angle) - center_direction.z * sin(angle),
			0,
			center_direction.x * sin(angle) + center_direction.z * cos(angle)
		)
		if spawner:
			spawner.spawn_projectile({
				"type": "arrow",
				"position": global_position + Vector3.UP,
				"direction": rotated_dir,
				"speed": 18.0,
				"damage": 20,
				"source": self
			})

	AudioManager.play_sound_3d("arrow_wave", global_position)


func _use_spin_dash() -> void:
	if ability_cooldowns["f"] > 0:
		return
	ability_cooldowns["f"] = 8.0

	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	# Shoot arrows in circle
	var arrow_count := 12
	var angle_step := TAU / arrow_count
	var spawner := get_node_or_null("/root/EffectSpawner")
	for i in arrow_count:
		var angle := angle_step * i
		var arrow_dir := Vector3(cos(angle), 0, sin(angle))
		if spawner:
			spawner.spawn_projectile({
				"type": "arrow",
				"position": global_position + Vector3.UP,
				"direction": arrow_dir,
				"speed": 18.0,
				"damage": 25,
				"source": self
			})

	# Dash
	var dash_target := global_position + direction * 10.0
	dash_target = GameManager.clamp_position_to_bounds(dash_target)

	var tween := create_tween()
	tween.tween_property(self, "global_position", dash_target, 0.3)
	tween.parallel().tween_property(model, "rotation:y", model.rotation.y + TAU * 2, 0.3)

	AudioManager.play_sound_3d("arrow_wave", global_position)


func _use_shotgun() -> void:
	if ability_cooldowns["e"] > 0:
		return
	ability_cooldowns["e"] = 5.0

	var center_direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			center_direction = to_mouse.normalized()
			model.rotation.y = atan2(center_direction.x, center_direction.z)

	# Spawn arrows in tight spread
	var arrow_count := 6
	var spread := deg_to_rad(72.0)
	var angle_step := spread / (arrow_count - 1)
	var start_angle := -spread / 2

	var spawner := get_node_or_null("/root/EffectSpawner")
	for i in arrow_count:
		var angle := start_angle + angle_step * i
		var rotated_dir := Vector3(
			center_direction.x * cos(angle) - center_direction.z * sin(angle),
			0,
			center_direction.x * sin(angle) + center_direction.z * cos(angle)
		)
		if spawner:
			spawner.spawn_projectile({
				"type": "arrow",
				"position": global_position + Vector3.UP,
				"direction": rotated_dir,
				"speed": 18.0,
				"damage": 40,
				"source": self
			})

	AudioManager.play_sound_3d("bow_shoot", global_position)


func _use_trap() -> void:
	if ability_cooldowns["r"] > 0:
		return
	ability_cooldowns["r"] = 12.0
	var trap_pos := global_position
	if camera:
		trap_pos = camera.get_mouse_world_position()
	AudioManager.play_sound_3d("trap_place", trap_pos)
	# Trap effect would be spawned here


func _use_giant_arrow() -> void:
	if ability_cooldowns["c"] > 0:
		return
	ability_cooldowns["c"] = 10.0

	var direction := model.global_transform.basis.z.normalized()
	if camera:
		var mouse_world: Vector3 = camera.get_mouse_world_position()
		var to_mouse: Vector3 = mouse_world - global_position
		to_mouse.y = 0
		if to_mouse.length() > 0.5:
			direction = to_mouse.normalized()
			model.rotation.y = atan2(direction.x, direction.z)

	var spawner := get_node_or_null("/root/EffectSpawner")
	if spawner:
		spawner.spawn_projectile({
			"type": "giant_arrow",
			"position": global_position + Vector3.UP,
			"direction": direction,
			"speed": 20.0,
			"damage": 50,
			"piercing": true,
			"source": self
		})

	AudioManager.play_sound_3d("bow_shoot", global_position)
