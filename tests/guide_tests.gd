extends Node
## Integration contract for the nonblocking field guide, touch swap and persisted replay.

const SAVE_PATH := "user://test_field_guide.cfg"
var _failed: int = 0


func _ready() -> void:
	SaveService.save_path = SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	SaveService.load_save()
	SaveService.profile_setup_done = true
	SaveService.tutorial_done = true
	SaveService.reduced_fx = true
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	GameManager.start_run(0, 0)
	await get_tree().create_timer(0.8).timeout
	var hud: Node = main.find_child("HUD", true, false)
	var chicken: Chicken = main.get_node("LevelHost").find_child("Chicken", true, false) as Chicken
	var chain: WormChain = main.get_node("LevelHost").find_child("WormChain", true, false) as WormChain
	_expect(hud != null and bool(hud.get("_guide_active")), "first campaign shows field training")
	_expect(GameManager.can_player_act() and not get_tree().paused, "training preserves live gameplay")
	_expect((hud.get("_guide_label") as Label).text.contains("1 / 3"), "first step explains firing")
	_expect(chicken.shoot_now(), "live shot is accepted during training")
	_expect((hud.get("_guide_label") as Label).text.contains("2 / 3"), "real shot advances the guide")
	var previous_next: WormColor.Kind = chicken.next_color
	(hud.get("_swap_btn") as Button).pressed.emit()
	_expect(chicken.current_color == previous_next, "HUD swap exchanges live ammunition")
	_expect(bool(hud.get("_guide_swapped")), "live swap advances training")
	_expect(int((hud.get("_current_swatch") as Control).get("worm_color")) == chicken.current_color, "current HUD swatch follows swapped ammo")
	_expect((hud.get("_current_label") as Label).text.contains(WormColor.kind_name(chicken.current_color)), "HUD names current color alongside its symbol")
	EventBus.chain_match_found.emit(chain, 0, 3, chicken.current_color)
	_expect(not bool(hud.get("_guide_active")) and SaveService.field_guide_done, "match completes the three event-driven lessons")
	SaveService.field_guide_done = false
	SaveService.load_save()
	_expect(SaveService.field_guide_done, "completed training survives a save reload")
	GameManager.restart_current_challenge()
	await get_tree().create_timer(0.2).timeout
	_expect(not bool(hud.get("_guide_active")), "completed tutorial stays dismissed on retry")
	GameManager.go_to_main_menu()
	await get_tree().create_timer(0.2).timeout
	var instructions: Control = main.find_child("InstructionsUI", true, false)
	(instructions.get("_training_btn") as Button).pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_expect(bool(hud.get("_guide_active")) and not SaveService.field_guide_done, "How To Play training button resets and starts the live lesson")
	(hud.get("_guide_skip") as Button).pressed.emit()
	_expect(not bool(hud.get("_guide_active")) and SaveService.field_guide_done, "skip remains available and persists")
	SaveService.save_path = "user://missing_field_guide_test_directory/save.cfg"
	SaveService.save()
	_expect(SaveService._stats_dirty, "failed save remains queued for retry")
	SaveService.save_path = SAVE_PATH
	SaveService.save()
	_expect(not SaveService._stats_dirty, "successful retry clears queued writes")
	GameManager.go_to_main_menu()
	AudioManager.stop_music()
	AudioManager._music_player.stream = null
	main.queue_free()
	GameManager.current_level_def = null
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("Field guide tests: ALL PASSED" if _failed == 0 else "Field guide tests: %d FAILED" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	if ok:
		print("  OK  ", message)
	else:
		_failed += 1
		printerr("  FAIL  ", message)
