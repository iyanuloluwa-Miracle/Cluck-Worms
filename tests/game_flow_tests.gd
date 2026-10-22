extends Node
## End-to-end flow tests against the real Main scene: start, shoot, pause,
## retry, clear, unlock, persistence, lock enforcement, boss, game over, menu.
## Run: godot --headless --path . res://tests/GameFlowTestRunner.tscn

const SAVE_PATH := "user://test_flow_save.cfg"

var _failed: int = 0
var _main: Node


func _ready() -> void:
	print("--- Running Cluck & Worms Game Flow Tests ---")
	SaveService.save_path = SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	SaveService.load_save()
	SaveService.profile_setup_done = true
	SaveService.tutorial_done = true
	SaveService.field_guide_done = true
	Engine.time_scale = 2.0
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _wait(0.2)

	await _test_start_and_shoot()
	await _test_pause_freezes_gameplay()
	await _test_retry_cleans_up()
	await _test_level_clear_unlocks_and_persists()
	await _test_locked_level_refused()
	await _test_corrupt_save_defaults()
	await _test_boss_encounter()
	await _test_game_over_and_menu()
	await _test_queen_shell()
	await _test_rooster_eggs()
	await _test_campaign_finale()
	await _test_keyboard_focus()
	await _test_retry_score_and_challenge_modes()
	await _test_practice_high_score_isolation()
	await _test_objective_refill_and_local_combo()
	await _test_focus_loss_pauses()
	await _test_final_shot_resolution()
	await _test_cosmetic_rng_isolation()
	_expect(AudioManager.composed_tracks == AudioManager.STAGE_TRACKS.size(), "composed stage music replaced every fallback drone")
	var boss_stream := AudioManager._streams[&"stage_boss"] as AudioStreamWAV
	_expect(boss_stream != null and boss_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and boss_stream.data.size() > 22050 * 2 * 10, "boss track is a long seamless loop")

	# Release fixture scenes and active streamed audio before engine teardown.
	AudioManager.stop_music()
	AudioManager._music_player.stream = null
	_main.queue_free()
	GameManager.current_level_def = null
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _failed == 0:
		print("Cluck & Worms game flow tests: ALL PASSED")
		get_tree().quit(0)
	else:
		printerr("Cluck & Worms game flow tests: %d FAILED" % _failed)
		get_tree().quit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _level_host() -> Node:
	return _main.get_node("LevelHost")


func _chain() -> WormChain:
	return _level_host().find_child("WormChain", true, false) as WormChain


func _chicken() -> Chicken:
	return _level_host().find_child("Chicken", true, false) as Chicken


func _live_levels() -> int:
	var n: int = 0
	for child: Node in _level_host().get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n


func _shoot_at_chain() -> bool:
	var chain := _chain()
	var chicken := _chicken()
	if chain == null or chicken == null:
		return false
	for w: Worm in chain.get_worms():
		if chain.is_worm_targetable(w):
			chicken.aim_at(w.global_position)
			return chicken.shoot_now()
	return false


func _clear_level() -> void:
	var chain := _chain()
	chain.spawns_remaining = 0
	chain.auto_spawn = false
	chain.clear_all()
	EventBus.chain_cleared.emit(chain)


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("  OK  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _test_start_and_shoot() -> void:
	_expect(GameManager.start_run(0, 0), "level 1 starts")
	await _wait(0.2)
	_expect(GameManager.state == GameManager.State.PLAYING, "state is PLAYING")
	_expect(_live_levels() == 1, "exactly one level instance")
	await _wait(2.5)
	var chain := _chain()
	var before: int = chain.get_worm_count()
	var hits: Array[int] = [0]
	var on_hit := func(_p: ShootingWorm, _w: Worm, _c: WormChain) -> void: hits[0] += 1
	EventBus.projectile_hit_chain.connect(on_hit)
	_expect(_shoot_at_chain(), "chicken fires a projectile")
	await _wait(1.2)
	EventBus.projectile_hit_chain.disconnect(on_hit)
	_expect(hits[0] == 1, "projectile hits the chain exactly once")
	_expect(GameManager.shots_fired == 1, "shot counted once")
	_expect(chain.get_worm_count() != before or GameManager.score > 0, "hit inserted or matched")


func _test_pause_freezes_gameplay() -> void:
	var chain := _chain()
	_shoot_at_chain()
	GameManager.pause_game()
	await _wait(0.05)
	var lead: float = chain.get_leader().target_path_distance
	var projectiles: Node = _level_host().get_child(0).get_node("Projectiles")
	var shot_pos: Array[Vector2] = []
	for p: Node in projectiles.get_children():
		shot_pos.append((p as Node2D).global_position)
	await _wait(0.6)
	_expect(GameManager.state == GameManager.State.PAUSED and get_tree().paused, "pause sets PAUSED + tree pause")
	_expect(is_equal_approx(chain.get_leader().target_path_distance, lead), "chain frozen while paused")
	var moved: bool = false
	var i: int = 0
	for p: Node in projectiles.get_children():
		if i < shot_pos.size() and (p as Node2D).global_position != shot_pos[i]:
			moved = true
		i += 1
	_expect(not moved, "projectiles frozen while paused")
	GameManager.resume_game()
	await _wait(0.3)
	_expect(GameManager.state == GameManager.State.PLAYING and not get_tree().paused, "resume restores play")


func _test_retry_cleans_up() -> void:
	var old_level: Node = _level_host().get_child(0)
	GameManager.retry_level()
	await _wait(0.1)
	_expect(not is_instance_valid(old_level), "old level freed on retry")
	_expect(_live_levels() == 1, "retry leaves exactly one level")
	_expect(GameManager.shots_fired == 0, "retry resets shot counter")
	for _n: int in range(2):
		GameManager.retry_level()
		await _wait(0.05)
	await _wait(0.1)
	_expect(_live_levels() == 1, "rapid retries never duplicate the level")


func _test_level_clear_unlocks_and_persists() -> void:
	await _wait(0.5)
	_clear_level()
	await _wait(0.2)
	_expect(GameManager.state == GameManager.State.LEVEL_COMPLETE, "chain clear completes level")
	_expect(SaveService.max_level_unlocked == 2, "level 2 unlocked")
	_expect(SaveService.get_level_stars(&"s1_l1") >= 1, "stars recorded")
	SaveService.load_save()
	GameManager.sanitize_save()
	_expect(SaveService.max_level_unlocked == 2, "unlock survives a reload from disk")
	GameManager.advance_after_level_complete()
	await _wait(0.2)
	_expect(GameManager.level_index == 1 and _live_levels() == 1, "next level loads")


func _test_locked_level_refused() -> void:
	_expect(not GameManager.can_start_level(0, 3), "level 4 is locked")
	_expect(not GameManager.start_run(2, 0), "start_run refuses a locked level")
	_expect(GameManager.level_index == 1, "refused start leaves current level alone")


func _test_corrupt_save_defaults() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string("[progress]\nmax_level_unlocked=\"lots\"\nhigh_score=-50\n[levels]\nrecords=[1,2]\n@@garbage[[{")
	f.close()
	SaveService.load_save()
	GameManager.sanitize_save()
	_expect(SaveService.max_level_unlocked >= 1 and SaveService.max_level_unlocked <= 15, "corrupt unlock falls back to a valid value")
	_expect(SaveService.high_score >= 0, "negative high score rejected")
	_expect(SaveService.level_records is Dictionary, "bad records become an empty dictionary")
	var old := ConfigFile.new()
	old.set_value("progress", "max_level_unlocked", 99)
	old.set_value("levels", "records", {"s1_l1": {"stars": 7, "best_score": 900}})
	old.save(SAVE_PATH)
	SaveService.load_save()
	GameManager.sanitize_save()
	_expect(SaveService.loaded_version == 1, "versionless save detected as legacy")
	_expect(SaveService.max_level_unlocked == 15, "legacy unlock clamped to campaign size")
	_expect(SaveService.get_level_stars(&"s1_l1") == 3, "star count clamped to 3")
	SaveService.max_level_unlocked = 2
	SaveService.level_records = {"s1_l1": {"stars": 1, "best_score": 800}}
	SaveService.save()


func _test_boss_encounter() -> void:
	SaveService.max_level_unlocked = 5
	_expect(GameManager.start_run(0, 4), "boss level starts when unlocked")
	await _wait(0.3)
	var boss := _level_host().find_child("BossController", true, false) as BossController
	_expect(boss != null and boss.is_active, "boss controller active")
	var hud_panel: Control = _main.find_child("BossPanel", true, false) as Control
	_expect(hud_panel != null and hud_panel.visible, "boss health bar visible")
	var hp: float = boss.health
	EventBus.cascade_step.emit(_chain(), 0, 3, WormColor.Kind.RED)
	_expect(is_equal_approx(boss.health, hp), "boss ignores damage during its intro")
	await _wait(boss.boss_def.intro_duration + 0.3)
	_expect(boss.mode == BossController.Mode.IDLE and boss.is_vulnerable, "intro finished, boss vulnerable")
	_expect(not _chain().is_holding(), "chain released after intro")
	EventBus.cascade_step.emit(_chain(), 0, 3, WormColor.Kind.RED)
	_expect(boss.health < hp, "a match damages the vulnerable boss")

	var boss_hits: Array[int] = [0]
	var on_boss_hit := func(_p: Node2D) -> void: boss_hits[0] += 1
	EventBus.projectile_hit_boss.connect(on_boss_hit)
	hp = boss.health
	_chicken().aim_at(boss.global_position)
	_chicken().shoot_now()
	await _wait(0.6)
	EventBus.projectile_hit_boss.disconnect(on_boss_hit)
	_expect(boss_hits[0] == 1, "direct shot strikes the boss body")

	var guard: int = 0
	while boss.mode != BossController.Mode.TELEGRAPH and guard < 300:
		await _wait(0.05)
		guard += 1
	_expect(boss.mode == BossController.Mode.TELEGRAPH, "boss telegraphs an attack")
	hp = boss.health
	EventBus.cascade_step.emit(_chain(), 0, 3, WormColor.Kind.RED)
	_expect(is_equal_approx(boss.health, hp) and not boss.is_vulnerable, "telegraphing Guardian is shielded")
	guard = 0
	while not (boss.mode == BossController.Mode.IDLE and boss.is_vulnerable) and guard < 300:
		await _wait(0.05)
		guard += 1
	boss.health = boss.boss_def.max_health
	hp = boss.health
	EventBus.cascade_step.emit(_chain(), 0, 3, WormColor.Kind.RED)
	var weak_dmg: float = hp - boss.health
	_expect(weak_dmg > boss.boss_def.damage_per_worm * 3.0 + 0.01, "post-attack weak window multiplies damage")

	var phases_seen: Array[int] = [0]
	var on_phase := func(_id: StringName, p: int) -> void: if p > 1: phases_seen[0] += 1
	EventBus.boss_phase_changed.connect(on_phase)
	guard = 0
	while not boss.is_defeated and guard < 400:
		if boss.is_vulnerable:
			EventBus.cascade_step.emit(_chain(), 1, 5, WormColor.Kind.RED)
		else:
			await _wait(0.05)
		guard += 1
	EventBus.boss_phase_changed.disconnect(on_phase)
	_expect(boss.is_defeated, "boss can be defeated")
	_expect(boss.phase == boss.boss_def.phases, "boss went through every phase")
	_expect(phases_seen[0] == boss.boss_def.phases - 1, "each phase transition fired once")
	_expect(_chain().get_worm_count() == 0, "defeat pops the remaining chain")
	_expect(GameManager.state == GameManager.State.PLAYING, "stage completes only after the defeat sequence")
	await _wait(BossController.DEFEAT_SEQUENCE_TIME + 0.6)
	_expect(GameManager.state == GameManager.State.STAGE_COMPLETE, "boss defeat completes the stage")
	_expect(SaveService.stages_cleared >= 1 and SaveService.max_level_unlocked >= 6, "stage 2 unlocked")
	GameManager.advance_after_stage_complete()
	await _wait(0.2)
	_expect(GameManager.stage_index == 1 and GameManager.level_index == 0, "next stage begins")


func _test_game_over_and_menu() -> void:
	await _wait(0.3)
	for _i: int in range(GameManager.starting_lives):
		EventBus.chain_reached_end.emit(_chain())
		await _wait(0.15)
	_expect(GameManager.state == GameManager.State.GAME_OVER, "losing all lives ends the run")
	GameManager.go_to_main_menu()
	await _wait(0.2)
	_expect(GameManager.state == GameManager.State.MAIN_MENU, "menu state")
	_expect(_live_levels() == 0, "returning to menu unloads the level")
	_expect(not get_tree().paused, "menu is not paused")


func _start_boss(stage: int) -> BossController:
	SaveService.max_level_unlocked = 15
	SaveService.stages_cleared = 2
	GameManager.start_run(stage, 4)
	await _wait(0.3)
	var boss := _level_host().find_child("BossController", true, false) as BossController
	await _wait(boss.boss_def.intro_duration + 0.3)
	return boss


func _test_queen_shell() -> void:
	var boss: BossController = await _start_boss(1)
	_expect(boss.boss_def.kind == BossDef.Kind.WORM_QUEEN, "stage 2 boss is the Worm Queen")
	_expect(not boss.is_vulnerable, "Queen starts the fight shelled")
	var crest: WormColor.Kind = boss._crest_color
	_expect(_chain().get_present_colors().has(int(crest)), "crest color exists on the chain")
	var other: WormColor.Kind = WormColor.Kind.RED if crest != WormColor.Kind.RED else WormColor.Kind.BLUE
	var hp: float = boss.health
	EventBus.cascade_step.emit(_chain(), 0, 3, other)
	_expect(is_equal_approx(boss.health, hp), "off-color match is blocked by the shell")
	EventBus.cascade_step.emit(_chain(), 0, 3, crest)
	_expect(boss.health < hp and boss._armor_timer == 0.0, "crest-color match shatters the shell and deals damage")
	GameManager.go_to_main_menu()
	await _wait(0.2)


func _test_rooster_eggs() -> void:
	var boss: BossController = await _start_boss(2)
	_expect(boss.boss_def.kind == BossDef.Kind.GOLDEN_ROOSTER, "stage 3 boss is the Golden Rooster")
	boss._begin_telegraph(&"egg_barrage")
	await _wait(boss.boss_def.telegraph_duration + 0.2)
	_expect(boss._eggs.size() >= 2, "egg barrage lays golden eggs")
	var eggs_before: int = boss._eggs.size()
	var hp: float = boss.health
	var egg_world: Vector2 = boss.to_global(boss._eggs[0]["pos"] as Vector2)
	var t: float = boss.try_absorb_projectile(egg_world + Vector2(0, 60), egg_world, WormColor.Kind.RED)
	_expect(t >= 0.0 and boss._eggs.size() == eggs_before - 1, "shooting an egg smashes it")
	_expect(boss.health < hp, "smashing an egg chips the boss")
	_chain().auto_spawn = false
	_chain().march_speed = 0.0
	boss._attack_timer = 999.0
	var worms_before: int = _chain().get_worm_count()
	await _wait(BossController.EGG_HATCH_TIME + 0.4)
	_expect(boss._eggs.is_empty(), "remaining eggs hatch on their timer")
	_expect(_chain().get_worm_count() > worms_before, "hatched eggs add worms to the chain")
	GameManager.go_to_main_menu()
	await _wait(0.2)


func _test_campaign_finale() -> void:
	var boss: BossController = await _start_boss(2)
	var guard: int = 0
	while not boss.is_defeated and guard < 400:
		boss._armor_timer = 0.0
		if boss.is_vulnerable:
			EventBus.cascade_step.emit(_chain(), 1, 6, WormColor.Kind.RED)
		else:
			await _wait(0.05)
		guard += 1
	await _wait(BossController.DEFEAT_SEQUENCE_TIME + 0.8)
	_expect(GameManager.state == GameManager.State.STAGE_COMPLETE, "final boss completes the last stage")
	var ui: Node = _main.find_child("StageCompleteUI", true, false)
	var title: Label = ui.get_node("Center/Panel/VBox/Title") as Label
	var menu_btn: Button = ui.get_node("Center/Panel/VBox/MenuButton") as Button
	_expect(title.text == "Campaign Complete!", "finale shows the campaign complete screen")
	_expect(not menu_btn.visible, "finale has a single exit button")
	_expect(get_viewport().gui_get_focus_owner() is Button, "finale button has keyboard focus")
	GameManager.advance_after_stage_complete()
	await _wait(0.3)
	_expect(GameManager.state == GameManager.State.MAIN_MENU, "finale returns to the menu")


func _test_keyboard_focus() -> void:
	await _wait(0.2)
	var focus: Control = get_viewport().gui_get_focus_owner()
	_expect(focus != null and focus.name == "AdventureButton", "menu focuses Adventure for keyboard play")
	SaveService.max_level_unlocked = 1
	SaveService.level_records = {}
	_expect(GameManager.start_run(0, 0), "level 1 starts for best-score check")
	await _wait(0.3)
	_expect(get_viewport().gui_get_focus_owner() == null, "gameplay releases GUI focus (Space stays swap)")
	GameManager.score = GameManager.level_start_score + 1234
	_clear_level()
	await _wait(0.3)
	_expect(GameManager.last_level_score >= 1234 and GameManager.last_level_previous_best == 0, "first clear reports level score and no previous best")
	var first: int = GameManager.last_level_score
	GameManager.retry_level()
	await _wait(0.3)
	GameManager.score = GameManager.level_start_score + 10
	_clear_level()
	await _wait(0.3)
	_expect(GameManager.last_level_previous_best == first, "replay compares against the earlier best")
	GameManager.go_to_main_menu()
	await _wait(0.2)


func _test_retry_score_and_challenge_modes() -> void:
	GameManager.start_run(0, 0)
	await _wait(0.1)
	GameManager.level_start_score = 1500
	GameManager.score = 4100
	GameManager.retry_level()
	await _wait(0.1)
	_expect(GameManager.score == 1500 and GameManager.level_start_score == 1500, "retry rolls back points earned during the failed attempt")
	GameManager.start_practice(1, 1)
	await _wait(0.1)
	GameManager.restart_current_challenge()
	await _wait(0.1)
	_expect(GameManager.challenge_mode == &"practice" and GameManager.suppress_progress_save and GameManager.stage_index == 1 and GameManager.level_index == 1, "practice retry keeps its mode, level and save isolation")
	_expect(_chain().spawns_remaining == -1, "restarted practice retains unlimited spawning")
	GameManager.start_daily_challenge()
	await _wait(0.1)
	var daily_location := Vector2i(GameManager.stage_index, GameManager.level_index)
	GameManager.restart_current_challenge()
	await _wait(0.1)
	_expect(GameManager.challenge_mode == &"daily" and Vector2i(GameManager.stage_index, GameManager.level_index) == daily_location, "daily retry keeps the daily challenge selection")
	GameManager.start_run(0, 0, true)
	await _wait(0.1)
	GameManager.restart_current_challenge()
	await _wait(0.1)
	_expect(GameManager.challenge_mode == &"gauntlet" and GameManager.is_gauntlet_run, "gauntlet retry preserves gauntlet mode")
	GameManager.go_to_main_menu()
	await _wait(0.1)


func _test_practice_high_score_isolation() -> void:
	var before: int = SaveService.high_score
	GameManager.start_practice(0, 0)
	await _wait(0.1)
	GameManager.score = before + 50000
	GameManager.lives = 1
	EventBus.chain_reached_end.emit(_chain())
	await _wait(0.1)
	_expect(GameManager.state == GameManager.State.GAME_OVER, "practice can finish through the normal game-over flow")
	_expect(SaveService.high_score == before, "practice game over cannot overwrite the competitive high score")
	GameManager.go_to_main_menu()
	await _wait(0.1)


func _test_objective_refill_and_local_combo() -> void:
	var stage: StageDef = GameManager.catalog.get_stage(0)
	var original: LevelData = stage.levels[0]
	for kind: LevelObjective.Kind in [LevelObjective.Kind.SCORE_TARGET, LevelObjective.Kind.COMBO_TARGET, LevelObjective.Kind.SURVIVE_TIME]:
		var fixture: LevelData = original.duplicate() as LevelData
		fixture.objective = kind
		fixture.target_score = 100000
		fixture.target_combo = 3
		fixture.survive_seconds = 60.0
		stage.levels[0] = fixture
		GameManager.start_run(0, 0)
		await _wait(0.1)
		var chain := _chain()
		_clear_level()
		_expect(GameManager.state == GameManager.State.PLAYING and chain.auto_spawn and chain.spawns_remaining == 12, "%s replenishes an empty chain while the goal is unmet" % LevelObjective.short_label(kind))
		await _wait(1.0)
		_expect(chain.get_worm_count() > 0, "%s replacement wave actually enters the playfield" % LevelObjective.short_label(kind))
		if kind == LevelObjective.Kind.COMBO_TARGET:
			GameManager.peak_combo = 20
			GameManager.combo = 0
			GameManager.level_peak_combo = 0
			GameManager.register_match(3, WormColor.Kind.RED, 0)
			_expect(GameManager.state == GameManager.State.PLAYING and not GameManager.objective_met and GameManager.level_peak_combo == 1, "an earlier level's peak cannot satisfy the new combo objective")
			GameManager.register_match(3, WormColor.Kind.RED, 0)
			GameManager.register_match(3, WormColor.Kind.RED, 0)
			_expect(GameManager.state == GameManager.State.LEVEL_COMPLETE, "earning the combo in the current level completes its objective")
		GameManager.go_to_main_menu()
		await _wait(0.1)
	stage.levels[0] = original


func _test_focus_loss_pauses() -> void:
	GameManager.start_run(0, 0)
	await _wait(0.1)
	GameManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(GameManager.state == GameManager.State.PAUSED and get_tree().paused, "browser focus loss pauses the current game")
	GameManager.resume_game()
	_expect(GameManager.state == GameManager.State.PLAYING and not get_tree().paused, "focus-paused game resumes through the normal pause control")
	GameManager.go_to_main_menu()
	await _wait(0.1)


func _test_final_shot_resolution() -> void:
	var stage: StageDef = GameManager.catalog.get_stage(0)
	var original: LevelData = stage.levels[0]
	var fixture: LevelData = original.duplicate() as LevelData
	fixture.objective = LevelObjective.Kind.LIMITED_SHOTS
	fixture.shot_limit = 1
	fixture.initial_worm_count = 2
	fixture.total_worms = 2
	fixture.march_speed = 0.0
	fixture.path_points = PackedVector2Array([Vector2(200, 200), Vector2(1080, 200)])
	fixture.chicken_position = Vector2(640, 500)
	fixture.intro_tip = ""
	stage.levels[0] = fixture
	for saving_match: bool in [true, false]:
		GameManager.start_run(0, 0)
		await _wait(0.1)
		var chain := _chain()
		var chicken := _chicken()
		var worms: Array[Worm] = chain.get_worms()
		for i: int in range(worms.size()):
			worms[i].worm_color = WormColor.Kind.RED if saving_match else (WormColor.Kind.BLUE if i == 0 else WormColor.Kind.GREEN)
			worms[i].target_path_distance = 600.0 - float(i) * chain.worm_spacing
			worms[i].path_distance = worms[i].target_path_distance
		chain.step(0.0)
		# Real projectiles continue, but hold the simulation to inspect the
		# pending insertion before allowing its match check to settle.
		chain.set_process(false)
		chicken.current_color = WormColor.Kind.RED
		chicken.aim_at(worms[0].global_position)
		var lives_before: int = GameManager.lives
		_expect(chicken.shoot_now() and GameManager.shots_fired == 1, "the final permitted shot launches")
		chicken.set("_cooldown_left", 0.0)
		_expect(not chicken.shoot_now() and GameManager.shots_fired == 1, "shot budget blocks an extra shot even with cooldown ready")
		GameManager._check_shot_limit_fail()
		_expect(GameManager.lives == lives_before and GameManager.state == GameManager.State.PLAYING, "exhausting the shot budget does not kill a projectile in flight")
		var guard: int = 0
		while not chain.is_busy() and guard < 120 and GameManager.state == GameManager.State.PLAYING:
			await _wait(0.01)
			guard += 1
		_expect(chain.is_busy(), "last shot reaches a real chain insertion")
		GameManager._check_shot_limit_fail()
		_expect(GameManager.lives == lives_before, "shot-budget judgment waits for the pending match")
		chain.set_process(true)
		await _wait(0.4)
		if saving_match:
			_expect(GameManager.state == GameManager.State.LEVEL_COMPLETE and GameManager.lives == lives_before, "the final permitted shot can match and win the level")
		else:
			_expect(GameManager.lives == lives_before - 1 and GameManager.shots_fired == 0 and GameManager.state == GameManager.State.PLAYING, "an unscored final shot costs one life only after resolution and retries cleanly")
		GameManager.go_to_main_menu()
		await _wait(0.1)
	stage.levels[0] = original


func _test_cosmetic_rng_isolation() -> void:
	GameManager.start_run(0, 0)
	await _wait(0.1)
	var chicken := _chicken()
	var cosmetic_worm: Worm = preload("res://scenes/worm/Worm.tscn").instantiate()
	_level_host().get_child(0).get_node("FX").add_child(cosmetic_worm)
	cosmetic_worm.setup(WormColor.Kind.RED, 0.0)
	var gameplay_state: int = GameManager.get_rng().state
	var fx_state: int = GameManager.get_fx_rng().state
	var sound_index: int = AudioManager._sfx_index
	AudioManager._on_chicken_shot(WormColor.Kind.RED, chicken.global_position, Vector2.RIGHT)
	_expect(AudioManager._sfx_index != sound_index and GameManager.get_rng().state == gameplay_state, "real shot sound variations leave the gameplay RNG unchanged")
	JuiceDirector.spawn_pop(chicken.global_position, WormColor.get_fill(WormColor.Kind.RED), 1.0)
	_expect(GameManager.get_rng().state == gameplay_state, "real particle generation leaves the next worm sequence unchanged")
	cosmetic_worm.begin_fall()
	_expect(cosmetic_worm.state == Worm.State.FALLING and GameManager.get_rng().state == gameplay_state, "random worm fall drift does not affect gameplay randomness")
	chicken.set("_is_blinking", true)
	chicken.set("_blink_left", 0.0)
	chicken.set("_idle_peck_timer", 0.0)
	chicken.reaction = &""
	chicken._update_idle(0.1)
	_expect(float(chicken.get("_blink_timer")) > 0.0 and GameManager.get_rng().state == gameplay_state, "blink and idle animation scheduling cannot alter future shot colors")
	_expect(GameManager.get_fx_rng().state != fx_state, "the exercised effects consumed their separate cosmetic RNG")
	GameManager.go_to_main_menu()
	await _wait(0.1)
