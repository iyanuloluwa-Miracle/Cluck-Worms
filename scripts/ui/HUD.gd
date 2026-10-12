extends CanvasLayer
## In-run HUD — score, lives, level, next worm, pause. Mobile-safe margins.

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
	_on_combo(0)


func _style() -> void:
	var chip := UITheme.chip_style(Color(0.06, 0.12, 0.08, 0.82))
	_score_chip.add_theme_stylebox_override("panel", chip)
	_lives_chip.add_theme_stylebox_override("panel", chip)
	_next_chip.add_theme_stylebox_override(
		"panel", UITheme.chip_style(Color(0.08, 0.14, 0.10, 0.88))
	)
	UITheme.style_body(_score, 20, false)
	UITheme.style_body(_lives, 18, false)
	_lives.add_theme_color_override("font_color", Color(1.0, 0.72, 0.68))
	UITheme.style_body(_level, 14, true)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(_combo, 18, false)
	_combo.add_theme_color_override("font_color", UITheme.YOLK)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(_status, 14, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(_next_label, 14, true)
	_next_label.text = "NEXT"
	UITheme.apply_ghost_button(_pause_btn)
	_pause_btn.text = "Ⅱ"
	_pause_btn.custom_minimum_size = Vector2(UITheme.TOUCH_MIN, UITheme.TOUCH_MIN)
	_pause_btn.add_theme_font_size_override("font_size", 22)


func _on_state(_prev: int, next: int) -> void:
	var show: bool = (
		next == GameManager.State.PLAYING
		or next == GameManager.State.PAUSED
	)
	if show and not visible:
		visible = true
		_root.modulate.a = 0.0
		UIFx.fade_in(_root, 0.25)
	elif not show:
		visible = false


func _on_score(new_score: int, delta: int) -> void:
	_score.text = "%d" % new_score
	if delta > 0:
		UIFx.pulse_label(_score_chip)


func _on_combo(combo: int) -> void:
	if combo <= 0:
		_combo.text = ""
		_combo.modulate.a = 0.0
	else:
		_combo.text = "COMBO ×%d" % combo
		_combo.modulate.a = 1.0
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
	if num > 0:
		_level.text = "%s  ·  L%d  %s" % [stage_name, num, display_name]
	else:
		_level.text = "%s  ·  %s" % [stage_name, display_name]
	_status.text = ""


func _on_loadout(_current: WormColor.Kind, next_color: WormColor.Kind) -> void:
	if _swatch and _swatch.has_method("set_color_kind"):
		_swatch.set_color_kind(next_color)
		UIFx.pulse_label(_next_chip)


func _on_cascade(_chain: WormChain, depth: int, count: int, color: WormColor.Kind) -> void:
	if depth <= 0:
		_status.text = "%s ×%d" % [WormColor.kind_name(color), count]
	else:
		_status.text = "Cascade %d!  %s ×%d" % [depth + 1, WormColor.kind_name(color), count]
	UIFx.pulse_label(_status)


func _on_shot_resolved(_chain: WormChain, scored: bool) -> void:
	if not scored:
		_status.text = "Combo reset"


func _on_life_lost(remaining: int) -> void:
	_status.text = "Life lost — %d left" % remaining


func _on_danger(urgency: float) -> void:
	if urgency < 0.25:
		return
	_status.text = "DANGER!" if urgency > 0.7 else "Watch the pit…"
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	UIFx.pulse_label(_status)


func _on_pause() -> void:
	UIFx.punch_button(_pause_btn)
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.pause_game()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()
