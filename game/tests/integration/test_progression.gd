extends RefCounted
## TestProgression — reward tepat satu kali, territory unlock setelah defense.


func run(t) -> void:
	TestUtil.reset_all()
	var pr: ProgressionSystem = SystemRefs.progression_system()
	t.check("pr.system_present", pr != null)
	if pr == null:
		return

	# Starting unlock dari data
	var cfg := GameData.progression_config
	t.check("pr.starting_unlocked_loaded", pr.unlocked.size() == cfg.starting_unlocks.size())
	t.check("pr.command_core_unlocked", pr.is_unlocked(&"command_core"))

	# Reward diberikan tepat satu kali
	Economy.reset()
	var e0 := Economy.get_amount(&"energy")
	var ok1 := pr.grant_reward({"energy": 100}, "test_source")
	t.check("pr.reward_granted", ok1)
	t.check_eq("pr.reward_applied", e0 + 100, Economy.get_amount(&"energy"))
	var ok2 := pr.grant_reward({"energy": 100}, "test_source")
	t.check("pr.reward_once_only", not ok2)
	t.check_eq("pr.reward_not_duplicated", e0 + 100, Economy.get_amount(&"energy"))

	# Territory unlock setelah kemenangan defense (via event combat_finished)
	t.check("pr.sector2_locked_initially", not pr.is_territory_unlocked(&"sector_2"))
	var result := BattleResult.new()
	result.winner = "defender"
	EventBus.combat_finished.emit(result)
	t.check("pr.sector2_unlocked_after_defense", pr.is_territory_unlocked(&"sector_2"))
	# Reward sektor dari data masuk ke ekonomi
	var sector2 := GameData.get_sector_def(&"sector_2")
	var expected_e := e0 + 100 + int(sector2.rewards.get("energy", 0))
	t.check_eq("pr.sector_reward_energy_from_data", expected_e, Economy.get_amount(&"energy"))

	# Kemenangan kedua: defense_wins naik, tapi tidak ada reward duplikat
	var wins_before := pr.defense_wins
	EventBus.combat_finished.emit(result)
	t.check_eq("pr.defense_wins_increment", wins_before + 1, pr.defense_wins)
	t.check_eq("pr.no_duplicate_sector_reward", expected_e, Economy.get_amount(&"energy"))
