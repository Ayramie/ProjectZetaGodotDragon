extends Node
## Quest manager singleton.
## Handles quest tracking, objectives, and rewards.

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

enum QuestType { MAIN, SIDE, DAILY, REPEATABLE }
enum ObjectiveType { KILL, COLLECT, INTERACT, REACH, ESCORT, DEFEND }

# All available quests (id -> quest data)
var quest_database: Dictionary = {}

# Active quests (id -> quest state)
var active_quests: Dictionary = {}

# Completed quest IDs
var completed_quests: Array[String] = []


func _ready() -> void:
	_init_quest_database()

	# Connect to events for automatic objective tracking
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.item_picked_up.connect(_on_item_picked_up)


func _init_quest_database() -> void:
	## Initialize all quests. In a full game, load from JSON.

	# Tutorial quest
	_add_quest({
		"id": "tutorial_combat",
		"name": "First Blood",
		"description": "Defeat your first skeleton enemy.",
		"type": QuestType.MAIN,
		"level": 1,
		"objectives": [
			{"id": "kill_skeleton", "type": ObjectiveType.KILL, "target": "skeleton", "amount": 1, "description": "Kill a skeleton"}
		],
		"rewards": {"gold": 25, "xp": 50, "items": [{"id": "health_potion_small", "amount": 3}]},
		"prerequisites": [],
		"auto_complete": true
	})

	# Combat quest chain
	_add_quest({
		"id": "skeleton_hunt",
		"name": "Skeleton Hunt",
		"description": "Clear out the skeleton infestation.",
		"type": QuestType.MAIN,
		"level": 1,
		"objectives": [
			{"id": "kill_skeletons", "type": ObjectiveType.KILL, "target": "skeleton", "amount": 5, "description": "Kill 5 skeletons"}
		],
		"rewards": {"gold": 75, "xp": 150, "items": [{"id": "iron_sword", "amount": 1}]},
		"prerequisites": ["tutorial_combat"],
		"auto_complete": true
	})

	_add_quest({
		"id": "elite_warrior",
		"name": "The Elite Warrior",
		"description": "A powerful skeleton warrior has been spotted. Defeat it.",
		"type": QuestType.MAIN,
		"level": 3,
		"objectives": [
			{"id": "kill_warrior", "type": ObjectiveType.KILL, "target": "Skeleton Warrior", "amount": 1, "description": "Defeat the Skeleton Warrior"}
		],
		"rewards": {"gold": 150, "xp": 300, "items": [{"id": "health_potion_large", "amount": 2}]},
		"prerequisites": ["skeleton_hunt"],
		"auto_complete": true
	})

	_add_quest({
		"id": "boss_battle",
		"name": "The Skeleton Lord",
		"description": "The Skeleton Lord awaits. End his reign of terror.",
		"type": QuestType.MAIN,
		"level": 5,
		"objectives": [
			{"id": "kill_boss", "type": ObjectiveType.KILL, "target": "Skeleton Lord", "amount": 1, "description": "Defeat the Skeleton Lord"}
		],
		"rewards": {"gold": 500, "xp": 1000, "items": [{"id": "steel_sword", "amount": 1}]},
		"prerequisites": ["elite_warrior"],
		"auto_complete": true
	})

	# Collection quests
	_add_quest({
		"id": "bone_collector",
		"name": "Bone Collector",
		"description": "Gather bone fragments for the alchemist.",
		"type": QuestType.SIDE,
		"level": 1,
		"objectives": [
			{"id": "collect_bones", "type": ObjectiveType.COLLECT, "target": "bone_fragment", "amount": 10, "description": "Collect 10 bone fragments"}
		],
		"rewards": {"gold": 50, "xp": 100, "items": [{"id": "health_potion_small", "amount": 5}]},
		"prerequisites": [],
		"auto_complete": true
	})

	_add_quest({
		"id": "mining_start",
		"name": "Mining Basics",
		"description": "Learn the basics of mining by gathering iron ore.",
		"type": QuestType.SIDE,
		"level": 2,
		"objectives": [
			{"id": "collect_iron", "type": ObjectiveType.COLLECT, "target": "iron_ore", "amount": 5, "description": "Mine 5 iron ore"}
		],
		"rewards": {"gold": 75, "xp": 125, "items": [{"id": "iron_bar", "amount": 2}]},
		"prerequisites": [],
		"auto_complete": true
	})

	# Daily/repeatable quests
	_add_quest({
		"id": "daily_hunt",
		"name": "Daily Hunt",
		"description": "Clear out some skeletons for a reward.",
		"type": QuestType.DAILY,
		"level": 1,
		"objectives": [
			{"id": "daily_kills", "type": ObjectiveType.KILL, "target": "skeleton", "amount": 10, "description": "Kill 10 skeletons"}
		],
		"rewards": {"gold": 100, "xp": 200, "items": []},
		"prerequisites": [],
		"auto_complete": true,
		"repeatable": true
	})


func _add_quest(quest_data: Dictionary) -> void:
	quest_database[quest_data.id] = quest_data


func start_quest(quest_id: String) -> bool:
	## Start a quest by ID.
	if not quest_database.has(quest_id):
		push_warning("Quest not found: " + quest_id)
		return false

	if active_quests.has(quest_id):
		return false  # Already active

	if quest_id in completed_quests:
		var quest: Dictionary = quest_database[quest_id]
		if not quest.get("repeatable", false):
			return false  # Already completed and not repeatable

	var quest: Dictionary = quest_database[quest_id]

	# Check prerequisites
	for prereq in quest.get("prerequisites", []):
		if prereq not in completed_quests:
			EventBus.show_message.emit("Quest requirements not met", Color.RED, 2.0)
			return false

	# Initialize quest state
	var quest_state := {
		"objectives": {}
	}

	for objective in quest.objectives:
		quest_state.objectives[objective.id] = {
			"current": 0,
			"required": objective.amount,
			"completed": false
		}

	active_quests[quest_id] = quest_state
	quest_started.emit(quest_id)

	EventBus.show_message.emit("Quest Started: " + quest.name, Color.YELLOW, 3.0)
	AudioManager.play_sound("quest_accept")

	return true


func update_objective(quest_id: String, objective_id: String, amount: int = 1) -> void:
	## Update progress on a quest objective.
	if not active_quests.has(quest_id):
		return

	var quest_state: Dictionary = active_quests[quest_id]
	if not quest_state.objectives.has(objective_id):
		return

	var obj_state: Dictionary = quest_state.objectives[objective_id]
	if obj_state.completed:
		return

	obj_state.current = min(obj_state.current + amount, obj_state.required)

	if obj_state.current >= obj_state.required:
		obj_state.completed = true

	quest_updated.emit(quest_id, objective_id)

	# Check if all objectives complete
	_check_quest_completion(quest_id)


func _check_quest_completion(quest_id: String) -> void:
	var quest_state: Dictionary = active_quests[quest_id]
	var quest: Dictionary = quest_database[quest_id]

	var all_complete := true
	for obj_id in quest_state.objectives:
		if not quest_state.objectives[obj_id].completed:
			all_complete = false
			break

	if all_complete and quest.get("auto_complete", false):
		complete_quest(quest_id)


func complete_quest(quest_id: String) -> void:
	## Complete a quest and grant rewards.
	if not active_quests.has(quest_id):
		return

	var quest: Dictionary = quest_database[quest_id]

	# Grant rewards
	var rewards: Dictionary = quest.get("rewards", {})

	if rewards.has("gold") and GameManager.inventory:
		GameManager.inventory.add_gold(rewards.gold)
		EventBus.show_message.emit("+" + str(rewards.gold) + " Gold", Color(1.0, 0.85, 0.3), 2.0)

	for item_reward in rewards.get("items", []):
		if GameManager.inventory:
			GameManager.inventory.add_item(item_reward.id, item_reward.amount)
			var item_def: Dictionary = ItemDatabase.get_item(item_reward.id)
			var item_name: String = item_def.get("name", item_reward.id)
			EventBus.show_message.emit("+" + str(item_reward.amount) + " " + item_name, Color.GREEN, 2.0)

	# TODO: Grant XP when leveling system exists

	# Remove from active, add to completed
	active_quests.erase(quest_id)
	if quest_id not in completed_quests:
		completed_quests.append(quest_id)

	quest_completed.emit(quest_id)

	EventBus.show_message.emit("Quest Complete: " + quest.name, Color.GREEN, 3.0)
	AudioManager.play_sound("quest_complete")


func fail_quest(quest_id: String) -> void:
	## Fail a quest.
	if not active_quests.has(quest_id):
		return

	var quest: Dictionary = quest_database[quest_id]
	active_quests.erase(quest_id)

	quest_failed.emit(quest_id)
	EventBus.show_message.emit("Quest Failed: " + quest.name, Color.RED, 3.0)


func abandon_quest(quest_id: String) -> void:
	## Abandon an active quest.
	if active_quests.has(quest_id):
		active_quests.erase(quest_id)


func get_quest(quest_id: String) -> Dictionary:
	return quest_database.get(quest_id, {})


func get_quest_state(quest_id: String) -> Dictionary:
	return active_quests.get(quest_id, {})


func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests


func get_available_quests() -> Array:
	## Get quests that can be started (prerequisites met, not active/completed).
	var available: Array = []
	for quest_id in quest_database:
		if active_quests.has(quest_id):
			continue
		if quest_id in completed_quests:
			var quest: Dictionary = quest_database[quest_id]
			if not quest.get("repeatable", false):
				continue

		var quest: Dictionary = quest_database[quest_id]
		var prereqs_met := true
		for prereq in quest.get("prerequisites", []):
			if prereq not in completed_quests:
				prereqs_met = false
				break

		if prereqs_met:
			available.append(quest)

	return available


func get_active_quests() -> Array:
	## Get all active quests with their state.
	var quests: Array = []
	for quest_id in active_quests:
		quests.append({
			"quest": quest_database[quest_id],
			"state": active_quests[quest_id]
		})
	return quests


# Event handlers for automatic objective tracking
func _on_enemy_killed(enemy: Node3D, _killer: Node3D) -> void:
	var enemy_name: String = enemy.name if enemy else "skeleton"

	for quest_id in active_quests:
		var quest: Dictionary = quest_database[quest_id]
		for objective in quest.objectives:
			if objective.type == ObjectiveType.KILL:
				# Check if target matches (partial match for flexibility)
				if objective.target.to_lower() in enemy_name.to_lower() or enemy_name.to_lower() in objective.target.to_lower():
					update_objective(quest_id, objective.id, 1)


func _on_item_picked_up(item_id: String, amount: int) -> void:
	for quest_id in active_quests:
		var quest: Dictionary = quest_database[quest_id]
		for objective in quest.objectives:
			if objective.type == ObjectiveType.COLLECT:
				if objective.target == item_id:
					update_objective(quest_id, objective.id, amount)


# Save/Load support
func get_save_data() -> Dictionary:
	return {
		"active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("active_quests"):
		active_quests = data.active_quests.duplicate(true)
	if data.has("completed_quests"):
		completed_quests.assign(data.completed_quests)
