class_name ProgressionSystem
extends Node
## ProgressionSystem — unlock, territory, reward. Pemilik state progresi.
##
## Aturan reward: diberikan TEPAT SATU KALI per source (dicatat di
## granted_rewards, ikut save) — AI_GOVERNANCE.md §8/§16.

var unlocked: Array[StringName] = []
var territories: Array[StringName] = []
var granted_rewards: Array[String] = []
var defense_wins: int = 0


func _ready() -> void:
	add_to_group("system_progression")
	var cfg := GameData.progression_config
	if cfg != null:
		unlocked = cfg.starting_unlocks.duplicate()
		territories = cfg.starting_territories.duplicate()
	EventBus.combat_finished.connect(_on_combat_finished)
	QaMarkers.marker("PROG", "INIT", {"unlocked": unlocked.size(), "territories": territories.size()})


func is_unlocked(id: StringName) -> bool:
	return id in unlocked


func unlock(id: StringName) -> void:
	if id in unlocked:
		return
	unlocked.append(id)
	QaMarkers.marker("PROG", "UNLOCK", {"id": id})


func is_territory_unlocked(sector_id: StringName) -> bool:
	return sector_id in territories


## Berikan reward tepat satu kali untuk source tertentu.
func grant_reward(rewards: Dictionary, source: String) -> bool:
	if source in granted_rewards:
		return false
	granted_rewards.append(source)
	for res_id in rewards.keys():
		Economy.earn(res_id, int(rewards[res_id]))
	EventBus.reward_granted.emit(rewards, source)
	QaMarkers.marker("PROG", "REWARD", {"source": source, "rewards": str(rewards)})
	return true


func _on_combat_finished(result: BattleResult) -> void:
	if result.winner != "defender":
		return
	defense_wins += 1
	# Buka sektor yang kondisinya terpenuhi (data-driven)
	for sector_id in GameData.sectors.keys():
		if sector_id in territories:
			continue
		var def := GameData.get_sector_def(sector_id)
		if def == null:
			continue
		if def.unlock_condition == "defend_home_base_%d" % defense_wins:
			territories.append(sector_id)
			grant_reward(def.rewards, "sector:%s" % sector_id)
			EventBus.territory_unlocked.emit(sector_id)
			QaMarkers.marker("PROG", "TERRITORY", {"sector": sector_id, "defense_wins": defense_wins})
			break


func get_state() -> Dictionary:
	return {
		"unlocked": unlocked.duplicate(),
		"territories": territories.duplicate(),
		"granted_rewards": granted_rewards.duplicate(),
		"defense_wins": defense_wins,
	}


func set_state(s: Dictionary) -> void:
	# Versi tanpa cast `as Array` (copy elemen satu per satu) — lebih robust
	# untuk array bertipe vs hasil parse JSON/save.
	var new_unlocked: Array[StringName] = []
	for v in s.get("unlocked", []):
		new_unlocked.append(StringName(v))
	unlocked = new_unlocked
	var new_territories: Array[StringName] = []
	for v in s.get("territories", []):
		new_territories.append(StringName(v))
	territories = new_territories
	var new_granted: Array[String] = []
	for v in s.get("granted_rewards", []):
		new_granted.append(String(v))
	granted_rewards = new_granted
	defense_wins = int(s.get("defense_wins", 0))
	QaMarkers.marker("PROG", "RESTORE", {"unlocked": unlocked.size(), "territories": territories.size(), "defense_wins": defense_wins})
