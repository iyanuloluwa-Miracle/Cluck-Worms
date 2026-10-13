extends OverlayBase
## Level clear celebration — stars, score comparison, cascade highlight, replay/next.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _level_name: Label = $Center/Panel/VBox/LevelName
@onready var _stars: Label = $Center/Panel/VBox/Stars
@onready var _score: Label = $Center/Panel/VBox/Score
@onready var _best: Label = $Center/Panel/VBox/Best
@onready var _cascade_hint: Label = $Center/Panel/VBox/CascadeHint
@onready var _next: Button = $Center/Panel/VBox/NextButton
@onready var _replay: Button = $Center/Panel/VBox/ReplayButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton

## Preserve old node name aliases so overlay still works with original .tscn.
@onready var _lives: Label = $Center/Panel/VBox/Lives if has_node("Center/Panel/VBox/Lives") else null


func _ready() -> void:
	visible_state = GameManager.State.LEVEL_COMPLETE
	super._ready()

	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.add_theme_color_override("font_color", UITheme.SUCCESS)
	_title.text = "Level Clear!"
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.22, 0.08, 0.8))
	_title.add_theme_constant_override("outline_size", 6)

	_level_name.add_theme_font_size_override("font_size", 18)
	_level_name.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	_level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_stars.add_theme_font_size_override("font_size", 38)
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.style_body(_score, UITheme.BODY_SIZE + 2)
	_score.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.style_body(_best, UITheme.CAPTION_SIZE + 2, true)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.style_body(_cascade_hint, UITheme.CAPTION_SIZE, true)
	_cascade_hint.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 0.85))
	_cascade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_primary_button(_next)
	_next.text = "Next Level  →"
	_next.add_theme_font_size_override("font_size", 20)

	UITheme.apply_ghost_button(_replay)
	_replay.text = "↺  Replay"

	UITheme.apply_ghost_button(_menu)
	_menu.text = "Main Menu"

	_next.pressed.connect(func() -> void:
		UIFx.punch_button(_next)
		GameManager.advance_after_level_complete()
	)
	_replay.pressed.connect(func() -> void:
		UIFx.punch_button(_replay)
		GameManager.retry_level()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
	EventBus.level_completed.connect(_on_level_completed)


func _on_level_completed(_level_id: StringName, score: int, _lives: int) -> void:
	# Level name.
	var display_name: String = "Level"
	var level_num: int = 0
	if GameManager.current_level_def:
		display_name = GameManager.current_level_def.display_name
		level_num = GameManager.current_level_def.level_number
	_level_name.text = "Level %d  ·  %s" % [level_num, display_name] if level_num > 0 else display_name

	# Stars with animation.
	var stars: int = GameManager.last_level_stars
	_show_stars_animated(stars)

	# Score.
	_score.text = "%s pts" % _format_score(score)

	# Best comparison.
	var prev_best: int = 0
	if GameManager.current_level_def:
		prev_best = SaveService.get_level_best_score(GameManager.current_level_def.id)
	if prev_best > 0 and score > prev_best:
		_best.text = "New Best! (was %s)" % _format_score(prev_best)
		_best.add_theme_color_override("font_color", UITheme.YOLK_HOT)
		UIFx.pulse_label(_best)
	elif prev_best > 0:
		_best.text = "Personal Best  ·  %s" % _format_score(prev_best)
		_best.add_theme_color_override("font_color", Color(0.82, 0.88, 0.78, 0.75))
	else:
		_best.text = "First clear!"
		_best.add_theme_color_override("font_color", UITheme.SUCCESS)

	# Cascade highlight.
	var cascades: int = GameManager.cascades_this_level
	if cascades >= 3:
		_cascade_hint.text = "✦ %d cascades triggered!" % cascades
	elif cascades >= 1:
		_cascade_hint.text = "✦ %d cascade" % cascades + ("s" if cascades > 1 else "") + " triggered"
	else:
		_cascade_hint.text = ""

	# Next label.
	var stage: StageDef = GameManager.get_current_stage()
	if stage != null and GameManager.level_index + 1 >= stage.get_level_count():
		_next.text = "Stage Complete!"
	else:
		_next.text = "Next Level  →"


func _show_stars_animated(stars: int) -> void:
	_stars.text = "☆☆☆"
	_stars.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52, 0.5))
	await get_tree().create_timer(0.25).timeout
	var star_str: String = ""
	for i: int in range(3):
		if i < stars:
			star_str += "★"
		else:
			star_str += "☆"
		_stars.text = star_str + "☆".repeat(maxi(3 - star_str.length(), 0))
		if i < stars:
			_stars.add_theme_color_override("font_color", UITheme.YOLK_HOT)
			UIFx.pulse_label(_stars)
		await get_tree().create_timer(0.2).timeout
	if stars == 3:
		_stars.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	elif stars >= 1:
		_stars.add_theme_color_override("font_color", UITheme.YOLK)
	else:
		_stars.add_theme_color_override("font_color", UITheme.CREAM_DIM)


func _format_score(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var c: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		if c > 0 and c % 3 == 0:
			out = "," + out
		out = s[i] + out
		c += 1
	return out
