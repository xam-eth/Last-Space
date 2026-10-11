extends Node
## EventBus — hub signal global. Seluruh komunikasi antarmodul game melewati
## sini (TECH_ARCHITECTURE.md §5). UI hanya mendengar, tidak pernah memancarkan
## perubahan state.

# Ekonomi
signal resource_changed(resource_id: StringName, old_amount: int, new_amount: int, delta: int)

# Bangunan
signal building_placed(building_id: StringName, instance_id: String, position: Vector3)
signal building_upgraded(instance_id: String, old_level: int, new_level: int)
signal building_damaged(instance_id: String, hp: int, state: String)
signal building_destroyed(instance_id: String)
signal building_repaired(instance_id: String, hp: int)

# Produksi
signal production_completed(kind: String, id: StringName, amount: int)

# Armada
signal ship_built(ship_id: StringName, instance_id: String)
signal ship_destroyed(instance_id: String)
signal fleet_changed()

# Pertempuran
signal wave_incoming(wave_id: StringName, eta_ticks: int)
signal combat_started(seed: int)
signal combat_finished(result: BattleResult)
signal combat_visual_done(result: BattleResult)

# Progresi
signal territory_unlocked(sector_id: StringName)
signal reward_granted(rewards: Dictionary, source: String)

# Quest (M3 #1 — quest panel kiri tengah, pola Doomsday F3/F8)
signal quest_progress(quest_id: StringName, current: int, target: int)
signal quest_completed(quest_id: StringName)

# Save/load
signal game_saved(slot: String)
signal game_loaded(slot: String)
