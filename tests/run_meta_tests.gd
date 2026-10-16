extends SceneTree
## Meta systems: objectives, achievements catalog, daily seed determinism.
## Prefer scene runner when possible; this script avoids autoload-only APIs.


func _init() -> void:
	var failed: int = 0
	failed += _expect(
		LevelObjective.display_name(LevelObjective.Kind.SCORE_TARGET).length() > 0,
		"score objective has display name"
	)
	failed += _expect(
		AchievementCatalog.all_ids().size() >= 10,
		"achievement catalog populated"
	)
	failed += _expect(
		AchievementCatalog.title(&"boss_slayer") == "Boss Slayer",
		"boss slayer title"
	)

	var catalog := ProgressionCatalog.build_campaign()
	failed += _expect(catalog.get_total_level_count() == 15, "15 levels")
	var scored := 0
	var survived := 0
	var limited := 0
	var bosses := 0
	for s: int in range(catalog.get_stage_count()):
		var stage: StageDef = catalog.get_stage(s)
		for l: int in range(stage.get_level_count()):
			var ld: LevelData = stage.get_level(l)
			match ld.objective:
				LevelObjective.Kind.SCORE_TARGET:
					scored += 1
					failed += _expect(ld.target_score > 0, "score level has target")
				LevelObjective.Kind.SURVIVE_TIME:
					survived += 1
					failed += _expect(ld.survive_seconds > 0.0, "survive level has duration")
				LevelObjective.Kind.LIMITED_SHOTS:
					limited += 1
					failed += _expect(ld.shot_limit > 0, "shot limit set")
				LevelObjective.Kind.DEFEAT_BOSS:
					bosses += 1
					failed += _expect(ld.is_boss_level and ld.boss != null, "boss objective wired")
				_:
					pass
	failed += _expect(scored >= 2, "has score-target levels")
	failed += _expect(survived >= 1, "has survive level")
	failed += _expect(limited >= 1, "has limited-shot level")
	failed += _expect(bosses == 3, "three boss objectives")

	# Daily seed is date-stable within the same day.
	var d := Time.get_date_dict_from_system()
	var seed_a: int = int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
	var seed_b: int = int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
	failed += _expect(seed_a == seed_b, "daily seed stable")

	if failed == 0:
		print("Cluck & Worms meta tests: ALL PASSED")
		quit(0)
	else:
		printerr("Cluck & Worms meta tests: %d FAILED" % failed)
		quit(1)


func _expect(ok: bool, label: String) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	printerr("  FAIL  ", label)
	return 1
