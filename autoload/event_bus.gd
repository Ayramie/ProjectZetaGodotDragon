@warning_ignore("unused_signal")
extends Node
## Global event bus for decoupled communication between game systems.
## Signals here are emitted/connected by other scripts, not within this file.

# Combat signals - emitted by player.gd, enemy_base.gd
signal enemy_damaged(enemy: Node3D, damage: int, source: Node3D)
signal enemy_killed(enemy: Node3D, killer: Node3D)
signal player_damaged(damage: int, source: Node3D)
signal player_healed(amount: int)
signal player_died()

# Targeting signals - emitted by player.gd
signal target_changed(new_target: Node3D)
signal target_cleared()

# Inventory signals - emitted by inventory.gd
signal item_picked_up(item_id: String, quantity: int)
signal item_used(item_id: String)
signal equipment_changed(slot: String, item_id: String)
signal inventory_changed()
signal hotbar_changed()
signal gold_changed(new_amount: int)

# Game state signals - emitted by game_manager.gd
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over()
signal boss_spawned(boss: Node3D)

# UI signals - emitted by various systems
signal show_message(text: String, color: Color, duration: float)
signal screen_shake(intensity: float)

# Life skill signals - emitted by life_skill_station.gd and minigame UIs
signal life_skill_started(skill_type: String, station: Node3D)
signal life_skill_completed(skill_type: String, results: Dictionary)
signal life_skill_cancelled(skill_type: String)
signal recipe_crafted(recipe_id: String, result_id: String)

# Dialogue signals - emitted by dialogue_ui.gd
signal dialogue_started(npc: Node3D)
signal dialogue_ended()

# Shop signals - emitted by shop_ui.gd
signal shop_opened(shop_id: String)
signal shop_closed()
signal item_purchased(item_id: String, price: int)
signal item_sold(item_id: String, price: int)

# Bank signals - emitted by bank_ui.gd
signal bank_opened()
signal bank_closed()

# Portal signals - emitted by portal.gd
signal portal_entered(destination: String)
