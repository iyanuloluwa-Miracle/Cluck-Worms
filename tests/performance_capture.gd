
extends Node
## Native GPU profile. Run without other game/browser benchmark processes.
var _main: Node
var _lines: PackedStringArray = []
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveService.save_path = "user://test_performance.cfg"
	SaveService.profile_setup_done = true
	SaveService.tutorial_done = true
	SaveService.field_guide_done = true
	_main = load("res://scenes/main/Main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)
	GameManager.get_rng().seed = 20261019
	GameManager.start_run(0, 0)
	await get_tree().create_timer(10.0).timeout
	var level: Node = _main.get_node("LevelHost").get_child(0)
	var backdrop: CanvasItem = level.get_node("Background/StageBackdrop")
	var path: CanvasItem = level.get_node("PathGuide")
	await _sample("live gameplay")
	# Keep the same geometry for layer isolation: no further spawns or movement.
	var chain: WormChain = level.get_node("WormChain")
	chain.set_process(false)
	_lines.append("Frozen isolation worm count: %d" % chain.get_worms().size())
	await _sample("frozen full scene")
	backdrop.visible = false
	await _sample("without backdrop")
	backdrop.visible = true
	path.visible = false
	await _sample("without track")
	path.visible = true
	_lines.append("Renderer: " + RenderingServer.get_video_adapter_name())
	var file := FileAccess.open("res://docs/native-performance.txt", FileAccess.WRITE)
	if file: file.store_string("\n".join(_lines))
	GameManager.go_to_main_menu()
	AudioManager.stop_music()
	AudioManager._music_player.stream = null
	_main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.save_path))
	get_tree().quit(0)
func _process(_delta: float) -> void:
	# Background benchmark windows must not accidentally measure a paused menu.
	if GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()


func _sample(label: String) -> void:
	for i: int in range(15): await get_tree().process_frame
	var frames: Array[float] = []
	var draws: float = 0.0
	var process_ms: float = 0.0
	var last: int = Time.get_ticks_usec()
	for i: int in range(120):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now-last)/1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	frames.sort()
	var line: String = "%s: frame median %.2fms p95 %.2fms; process %.2fms; draw calls %.0f" % [label, frames[60], frames[114], process_ms/120.0, draws/120.0]
	print(line)
	_lines.append(line)
