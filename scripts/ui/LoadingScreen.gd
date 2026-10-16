extends Control
## Custom Cluck & Worms boot loader. Threads Main.tscn and shows real progress.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

const TIPS: Array[String] = [
	"Match 3 or more worms of the same color to pop them!",
	"After a match, the chain reverses to close the gap.",
	"Cascades score big — set up the next join!",
	"Right-click or tap Space to swap your next worm.",
	"Slow worms briefly ease the march — use them well.",
	"Bosses hate reverse windows — strike when the chain rolls back!",
	"Clear the train after spawns run out to finish a level.",
]

@onready var _title: Label = $Safe/VBox/Title
@onready var _subtitle: Label = $Safe/VBox/Subtitle
@onready var _tip: Label = $Safe/VBox/Tip
@onready var _bar: ProgressBar = $Safe/VBox/Bar
@onready var _percent: Label = $Safe/VBox/Percent
@onready var _mascot: Control = $Safe/VBox/MascotHost/Mascot
@onready var _spinner: Control = $Safe/VBox/Spinner

var _tip_timer: float = 0.0
var _tip_index: int = 0
var _spin_time: float = 0.0
var _load_started: bool = false
var _finished: bool = false
var _fake_floor: float = 0.0
## When false, loading completes without switching scenes (capture / tests).
var auto_enter: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style()
	_show_tip(0)
	_bar.value = 0.0
	_percent.text = "0%"
	# Warm a few common resources, then thread-load the main shell.
	call_deferred("_begin_load")


func _process(delta: float) -> void:
	_spin_time += delta
	_tip_timer += delta
	if _tip_timer >= 3.2:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_show_tip(_tip_index)

	if _mascot:
		_mascot.rotation = sin(_spin_time * 2.4) * 0.08
		_mascot.position.y = sin(_spin_time * 3.1) * 4.0
	if _spinner:
		_spinner.rotation = _spin_time * 2.8

	if _finished or not _load_started:
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		MAIN_SCENE_PATH, progress
	)
	var has_real_progress: bool = progress.size() > 0 and float(progress[0]) > 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_bar.value = 100.0
		_percent.text = "100%"
		_finish_and_enter()
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("LoadingScreen: failed to load %s — falling back to sync load." % MAIN_SCENE_PATH)
		_finished = true
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return

	if has_real_progress:
		var pct: float = clampf(float(progress[0]) * 100.0, 0.0, 99.0)
		_bar.value = pct
		_percent.text = "%d%%" % int(round(pct))
	else:
		# Indeterminate: pulse the bar instead of inventing a percentage.
		_fake_floor = fmod(_fake_floor + delta * 45.0, 100.0)
		_bar.value = 15.0 + absf(_fake_floor - 50.0) * 0.7
		_percent.text = "Loading…"


func _begin_load() -> void:
	# Thread-load the main shell. Avoid sync preloads that freeze the boot frame.
	var err: Error = ResourceLoader.load_threaded_request(MAIN_SCENE_PATH, "", true)
	if err != OK:
		push_warning("LoadingScreen: threaded request failed (%s), using sync." % error_string(err))
		_finished = true
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return
	_load_started = true
	# Warm gameplay scenes in parallel without blocking the UI thread.
	ResourceLoader.load_threaded_request("res://scenes/level/Level.tscn")
	ResourceLoader.load_threaded_request("res://scenes/worm/Worm.tscn")


func _finish_and_enter() -> void:
	if _finished:
		return
	_finished = true
	_bar.value = 100.0
	_percent.text = "100%"
	if not auto_enter:
		return
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return
	# Brief beat so 100% is readable, then hand off.
	await get_tree().create_timer(0.28).timeout
	get_tree().change_scene_to_packed(packed)


func _show_tip(index: int) -> void:
	if _tip == null:
		return
	_tip.text = TIPS[index]
	_tip.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tip, "modulate:a", 1.0, 0.25)


func _style() -> void:
	UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.16, 0.08, 0.95))
	_title.add_theme_constant_override("outline_size", 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_subtitle, UITheme.WEIGHT_SEMIBOLD)
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(0.92, 0.95, 0.85, 0.9))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_tip, UITheme.WEIGHT_REGULAR)
	_tip.add_theme_font_size_override("font_size", 17)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 0.92))
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UITheme.apply_font(_percent, UITheme.WEIGHT_BOLD)
	_percent.add_theme_font_size_override("font_size", 18)
	_percent.add_theme_color_override("font_color", UITheme.YOLK)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.12, 0.08, 0.95)
	bg.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.75, 0.25)
	fill.set_corner_radius_all(10)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
