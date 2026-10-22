extends Node
## Renders the real game screens to PNG for visual review (needs a GPU window).
## Run: godot --path . res://tests/VisualCapture.tscn -- --out=C:/tmp/caps [--size=1920x1080]

var _out_dir: String = "user://captures"
var _scenario: String = "flow"
var _main: Node
var _allow_pause: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--scenario="):
			_scenario = arg.substr(11)
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.substr(7).split("x")
			get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	SaveService.save_path = "user://capture_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.save_path))
	SaveService.load_save()
	SaveService.profile_setup_done = true
	SaveService.tutorial_done = true
	SaveService.set("field_guide_done", true)
	if _scenario == "bosses":
		await _run_bosses()
	else:
		await _run()
	await _teardown()
	get_tree().quit(0)


func _run_bosses() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)
	await _wait(0.5)
	SaveService.max_level_unlocked = 15
	SaveService.stages_cleared = 2
	for stage: int in range(3):
		GameManager.start_run(stage, 4)
		await _wait(1.0)
		await _snap("b%d_1_intro" % stage)
		var boss := _main.find_child("BossController", true, false) as BossController
		await _wait(boss.boss_def.intro_duration)
		await _shoot_at_chain(2)
		await _wait(0.4)
		await _snap("b%d_2_fight" % stage)
		var attack: StringName = &"egg_barrage" if stage == 2 else (&"royal_decree" if stage == 1 else &"root_surge")
		boss._begin_telegraph(attack)
		await _wait(boss.boss_def.telegraph_duration * 0.6)
		await _snap("b%d_3_telegraph" % stage)
		await _wait(boss.boss_def.telegraph_duration * 0.4 + 0.5)
		await _snap("b%d_4_attack" % stage)
		if stage == 0:
			await _wait(1.8)
			await _snap("b0_5_weak")
		var guard: int = 0
		while not boss.is_defeated and guard < 100:
			boss._armor_timer = 0.0
			boss.mode = BossController.Mode.IDLE
			boss.is_vulnerable = true
			EventBus.cascade_step.emit(_find_chain(), 1, 6, WormColor.Kind.RED)
			guard += 1
		await _wait(0.5)
		await _snap("b%d_6_defeat" % stage)
		await _wait(BossController.DEFEAT_SEQUENCE_TIME + 1.2)
		await _snap("b%d_7_stage_complete" % stage)
		GameManager.go_to_main_menu()
		await _wait(0.3)


func _run() -> void:
	var loading: Node = load("res://scenes/ui/LoadingScreen.tscn").instantiate()
	loading.set("auto_enter", false)
	add_child(loading)
	await _wait(0.35)
	await _snap("01_loading")
	# auto_enter=false deliberately skips the loader's handoff. Consume its
	# threaded requests here so screenshot-only resource handles are released.
	for preload_path: String in ["res://scenes/main/Main.tscn", "res://scenes/level/Level.tscn", "res://scenes/worm/Worm.tscn"]:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(preload_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(preload_path)
	loading.queue_free()

	_main = load("res://scenes/main/Main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)
	await _wait(1.6)
	await _snap("02_main_menu")

	var select: Node = _main.find_child("LevelSelectUI", true, false)
	if select and select.has_method("open_select"):
		select.call("open_select")
		await _wait(0.8)
		await _snap("03_level_select")
		select.set("visible", false)

	GameManager.start_run(0, 0)
	await _wait(2.6)
	await _shoot_at_chain(3)
	await _wait(0.12)
	await _snap("04_gameplay")
	await _wait(1.0)
	await _snap("05_gameplay_later")

	_allow_pause = true
	GameManager.pause_game()
	await _wait(0.6)
	await _snap("06_pause")
	_allow_pause = false
	GameManager.resume_game()
	await _wait(0.3)

	_force_clear()
	await _wait(1.4)
	await _snap("07_level_complete")

	SaveService.max_level_unlocked = 5
	GameManager.start_run(0, 4)
	await _wait(0.9)
	await _snap("08_boss_intro")
	await _wait(3.5)
	await _shoot_at_chain(2)
	await _wait(0.5)
	await _snap("09_boss_fight")

	GameManager.go_to_main_menu()
	await _wait(0.2)
	SaveService.max_level_unlocked = 15
	GameManager.start_run(2, 2)
	await _wait(3.0)
	await _snap("10_stage3_level")

	for i: int in range(GameManager.lives):
		EventBus.chain_reached_end.emit(_find_chain())
		await _wait(0.4)
	await _wait(1.0)
	await _snap("11_game_over")
	GameManager.go_to_main_menu()
	await _wait(0.2)
	SaveService.field_guide_done = false
	GameManager.start_run(0, 0)
	await _wait(3.0)
	await _snap("12_tutorial")



func _find_chain() -> WormChain:
	return _main.find_child("WormChain", true, false) as WormChain


func _shoot_at_chain(shots: int) -> void:
	for i: int in range(shots):
		var chain := _find_chain()
		var chicken := _main.find_child("Chicken", true, false) as Chicken
		if chain == null or chicken == null:
			return
		var targets: Array[Worm] = []
		for w: Worm in chain.get_worms():
			if chain.is_worm_targetable(w):
				targets.append(w)
		if targets.is_empty():
			return
		chicken.aim_at(targets[targets.size() / 2].global_position)
		chicken.shoot_now()
		await _wait(0.25)


func _force_clear() -> void:
	var chain := _find_chain()
	if chain == null:
		return
	chain.spawns_remaining = 0
	chain.auto_spawn = false
	chain.clear_all()
	EventBus.chain_cleared.emit(chain)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _snap(label: String) -> void:
	if not _allow_pause and GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()
		await _wait(0.3)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [_out_dir, label]
	img.save_png(path)
	print("captured ", path, " state=", GameManager.State.keys()[GameManager.state])

func _process(_delta: float) -> void:
	# Capture runs in the background while tools inspect the workspace. Keep
	# this exception in the harness; the game still pauses on actual focus loss.
	if not _allow_pause and GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()


func _teardown() -> void:
	_allow_pause = false
	GameManager.go_to_main_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_main):
		_main.queue_free()
		_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	AudioManager.stop_music()
	for child: Node in AudioManager.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
	# Let deferred scene frees and audio playback references settle before quit.
	await _wait(0.15)
