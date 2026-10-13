extends CanvasLayer
## In-run HUD — score, lives, combo, next worm, worm progress, danger. Mobile-safe margins.

@onready var _root: Control = $Root
@onready var _top_bar: HBoxContainer = $Root/Safe/TopBar
@onready var _score_chip: PanelContainer = $Root/Safe/TopBar/ScoreChip
@onready var _score: Label = $Root/Safe/TopBar/ScoreChip/Margin/Score
@onready var _lives_chip: PanelContainer = $Root/Safe/TopBar/LivesChip
@onready var _lives: Label = $Root/Safe/TopBar/LivesChip/Margin/Lives
@onready var _pause_btn: Button = $Root/Safe/TopBar/PauseButton
@onready var _level: Label = $Root/Safe/LevelLabel
@onready var _combo: Label = $Root/Safe/ComboLabel
@onready var _next_chip: PanelContainer = $Root/Safe/BottomBar/NextChip
@onready var _next_label: Label = $Root/Safe/BottomBar/NextChip/Margin/Row/NextLabel
@onready var _swatch: Control = $Root/Safe/BottomBar/NextChip/Margin/Row/WormSwatch
@onready var _status: Label = $Root/Safe/StatusLabel
@onready var _progress_bar: ProgressBar = $Root/Safe/ProgressBar if has_node("Root/Safe/ProgressBar") else null

## Worm progress tracking.
var _total_worms: int = 0
var _worms_cleared: int = 0

## Danger animation.
var _danger_urgency: float = 0.0
var _danger_pulse: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style()
	_pause_btn.pressed.connect(_on_pause)
	EventBus.score_changed.connect(_on_score)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.lives_changed.connect(_on_lives)
	EventBus.level_started.connect(_on_level_started)
	EventBus.game_state_changed.connect(_on_state)
	EventBus.cascade_step.connect(_on_cascade)
	EventBus.shot_resolve_finished.connect(_on_shot_resolved)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.chicken_loadout_changed.connect(_on_loadout)
	EventBus.danger_warning.connect(_on_danger)
	EventBus.chain_worms_removed.connect(_on_worms_removed)
	_on_combo(0)


func _process(delta: float) -> void:
	if _danger_urgency > 0.0:
		_danger_pulse = sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
		var danger_alpha: float = 0.15 + _danger_urgency * 0.55 + _danger_pulse * _danger_urgency * 0.30
		_status.modulate.a = danger_alpha
		if _progress_bar:
			_progress_bar.queue_redraw()


func _style() -> void:
	var chip := UITheme.chip_style(Color(0.06, 0.12, 0.08, 0.88))
	_score_chip.add_theme_stylebox_override("panel", chip)
	_lives_chip.add_theme_stylebox_override("panel", chip)
	_next_chip.add_theme_stylebox_override(
		"panel", UITheme.chip_style(Color(0.08, 0.14, 0.10, 0.92))
	)
	UITheme.style_body(_score, 20, false)
	_score.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	UITheme.style_body(_lives, 18, false)
	_lives.add_theme_color_override("font_color", Color(1.0, 0.68, 0.65))
	UITheme.style_body(_level, 13, true)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(_combo, 19, false)
	_combo.add_theme_color_override("font_color", UITheme.YOLK)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(_status, 15, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	UITheme.style_body(_next_label, 13, true)
	_next_label.text = "NEXT"
	UITheme.apply_ghost_button(_pause_btn)
	_pause_btn.text = "Ⅱ"
	_pause_btn.custom_minimum_size = Vector2(UITheme.TOUCH_MIN, UITheme.TOUCH_MIN)
	_pause_btn.add_theme_font_size_override("font_size", 22)

	if _progress_bar:
		_progress_bar.show_percentage = false
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.04, 0.08, 0.05, 0.75)
		bg.set_corner_radius_all(4)
		_progress_bar.add_theme_stylebox_override("background", bg)
		var fill := StyleBoxFlat.new()
		fill.bg_color = UITheme.YOLK_HOT
		fill.set_corner_radius_all(4)
		_progress_bar.add_theme_stylebox_override("fill", fill)


func _on_state(_prev: int, next: int) -> void:
	var show: bool = (
		next == GameManager.State.PLAYING
		or next == GameManager.State.PAUSED
	)
	if show and not visible:
		visible = true
		_root.modulate.a = 0.0
		UIFx.fade_in(_root, 0.28)
	elif not show:
		visible = false


func _on_score(new_score: int, delta: int) -> void:
	_score.text = _format_score(new_score)
	if delta > 0:
		UIFx.pulse_label(_score_chip)


func _format_score(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _on_combo(combo: int) -> void:
	if combo <= 0:
		var tween := create_tween()
		tween.tween_property(_combo, "modulate:a", 0.0, 0.18)
	else:
		_combo.modulate.a = 1.0
		var mul: float = GameManager.get_combo_multiplier()
		if combo == 1:
			_combo.text = "COMBO ×1"
		else:
			_combo.text = "COMBO ×%d  (%.1fx)" % [combo, mul]
		# Color ramp: green → yellow → orange → red.
		var ramp_t: float = clampf(float(combo - 1) / 9.0, 0.0, 1.0)
		var combo_color: Color
		if ramp_t < 0.33:
			combo_color = UITheme.SUCCESS.lerp(UITheme.YOLK, ramp_t * 3.0)
		elif ramp_t < 0.66:
			combo_color = UITheme.YOLK.lerp(Color(1.0, 0.55, 0.15), (ramp_t - 0.33) * 3.0)
		else:
			combo_color = Color(1.0, 0.55, 0.15).lerp(UITheme.DANGER, (ramp_t - 0.66) * 3.0)
		_combo.add_theme_color_override("font_color", combo_color)
		UIFx.pulse_label(_combo)


func _on_lives(lives: int, max_lives: int) -> void:
	var hearts: String = ""
	for i: int in range(max_lives):
		hearts += "♥" if i < lives else "♡"
	_lives.text = hearts


func _on_level_started(_id: StringName, display_name: String) -> void:
	var stage: StageDef = GameManager.get_current_stage()
	var stage_name: String = stage.display_name if stage else "Stage"
	var num: int = 0
	if GameManager.current_level_def:
		num = GameManager.current_level_def.level_number
		_total_worms = GameManager.current_level_def.total_worms
	else:
		_total_worms = 0
	_worms_cleared = 0
	if num > 0:
		_level.text = "%s  ·  L%d  %s" % [stage_name, num, display_name]
	else:
		_level.text = "%s  ·  %s" % [stage_name, display_name]
	_status.text = ""
	_danger_urgency = 0.0
	_update_progress_bar()


func _on_worms_removed(_chain: WormChain, _index: int, count: int) -> void:
	_worms_cleared += count
	_update_progress_bar()


func _update_progress_bar() -> void:
	if _progress_bar == null:
		return
	_progress_bar.max_value = maxf(float(_total_worms), 1.0)
	_progress_bar.value = clampf(float(_worms_cleared), 0.0, _progress_bar.max_value)


func _on_loadout(_current: WormColor.Kind, next_color: WormColor.Kind) -> void:
	if _swatch and _swatch.has_method("set_color_kind"):
		_swatch.set_color_kind(next_color)
		UIFx.pulse_label(_next_chip)


func _on_cascade(_chain: WormChain, depth: int, count: int, color: WormColor.Kind) -> void:
	if depth <= 0:
		_status.text = "%s ×%d" % [WormColor.kind_name(color), count]
	else:
		_status.text = "✦ CASCADE %d!  %s ×%d" % [depth + 1, WormColor.kind_name(color), count]
	_status.add_theme_color_override("font_color",
		UITheme.YOLK_HOT if depth >= 1 else UITheme.SUCCESS
	)
	_status.modulate.a = 1.0
	UIFx.pulse_label(_status)
	# Fade status after a brief display.
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_status, "modulate:a", 0.0, 0.5)


func _on_shot_resolved(_chain: WormChain, scored: bool) -> void:
	if not scored and _danger_urgency <= 0.25:
		_status.text = "Combo reset"
		_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
		_status.modulate.a = 0.85
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(_status, "modulate:a", 0.0, 0.4)


func _on_life_lost(remaining: int) -> void:
	_status.text = "Life lost — %d left" % remaining
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	_status.modulate.a = 1.0


func _on_danger(urgency: float) -> void:
	_danger_urgency = urgency
	if urgency < 0.2:
		_danger_urgency = 0.0
		_status.text = ""
		_status.modulate.a = 0.0
		return
	var msg: String
	if urgency > 0.75:
		msg = "⚠ DANGER!"
	elif urgency > 0.45:
		msg = "Chain approaching…"
	else:
		msg = "Watch the pit…"
	_status.text = msg
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	_status.modulate.a = 1.0


func _on_pause() -> void:
	UIFx.punch_button(_pause_btn)
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.pause_game()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()
