extends RefCounted
## TestQuestTracker — M3 #1: progress objektif via EventBus + reward-once +
## save/load round-trip (QA_PLAN.md §3). Ekspektasi dari state aktual.


func run(t) -> void:
	TestUtil.reset_all()
	var qt: QuestTracker = SystemRefs.quest_tracker()
	t.check("qt.present", qt != null)
	if qt == null:
		return

	# --- awal: 4 objektif slice, progress 0 ---
	t.check_eq("qt.count", 4, qt.get_all().size())
	t.check_eq("qt.q_power_start", 0, qt.get_progress(&"q_power"))

	# --- bangun reactor → q_power complete + reward masuk ke Economy ---
	var bs: BuildingSystem = SystemRefs.building_system()
	var e0 := Economy.get_amount(&"energy")
	bs.place_building(&"energy_reactor", Vector3(10, 0, 10))
	t.check_eq("qt.q_power_progress", 1, qt.get_progress(&"q_power"))
	t.check("qt.q_power_done", qt.is_done(&"q_power"))
	t.check_eq("qt.q_power_reward", e0 + 100, Economy.get_amount(&"energy"))

	# --- produksi 2 interceptor → q_squad complete ---
	EventBus.ship_built.emit(&"shp_001_interceptor", "t1")
	t.check_eq("qt.q_squad_mid", 1, qt.get_progress(&"q_squad"))
	t.check("qt.q_squad_not_done", not qt.is_done(&"q_squad"))
	EventBus.ship_built.emit(&"shp_001_interceptor", "t2")
	t.check("qt.q_squad_done", qt.is_done(&"q_squad"))

	# --- wave_1 menang → q_defend complete; reward-once (tidak double) ---
	EventBus.wave_incoming.emit(&"wave_1", 100)
	var res := BattleResult.new()
	res.winner = "defender"
	EventBus.combat_finished.emit(res)
	t.check("qt.q_defend_done", qt.is_done(&"q_defend"))
	var e1 := Economy.get_amount(&"energy")
	EventBus.combat_finished.emit(res)  ## ulang — tidak boleh double reward
	t.check_eq("qt.reward_once", e1, Economy.get_amount(&"energy"))

	# --- objektif lain belum terpenuhi ---
	t.check_eq("qt.q_hangar_start", 0, qt.get_progress(&"q_hangar"))

	# --- save/load round-trip ---
	var snap := qt.get_state()
	qt.set_state({})
	t.check_eq("qt.reset_progress", 0, qt.get_progress(&"q_power"))
	qt.set_state(snap)
	t.check("qt.restore_done", qt.is_done(&"q_power"))
	t.check_eq("qt.restore_progress", 1, qt.get_progress(&"q_power"))
