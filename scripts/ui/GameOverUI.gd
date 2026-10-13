extends OverlayBase
## Lives depleted — score + high score callout.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _body: Label = $Center/Panel/VBox/Body
@onready var _retry: Button = $Center/Panel/VBox/RetryButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	visible_state = GameManager.State.GAME_OVER
	super._ready()
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.add_theme_color_override("font_color", UITheme.DANGER)
	_title.text = "Game Over"
	UITheme.style_body(_body, UITheme.BODY_SIZE)
	UITheme.apply_primary_button(_retry)
	UITheme.apply_ghost_button(_menu)
	_retry.text = "Retry Level"
	_menu.text = "Main Menu"
	_retry.pressed.connect(func() -> void:
		UIFx.punch_button(_retry)
		# Restart the failed level with a fresh life pool (same stage/level).
		GameManager.start_run(GameManager.stage_index, GameManager.level_index)
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(final_score: int, high_score: int, is_new_high: bool) -> void:
	var formatted_score: String = _format_score(final_score)
	var formatted_high: String = _format_score(high_score)
	if is_new_high:
		_body.add_theme_color_override("font_color", UITheme.YOLK_HOT)
		_body.text = "%s pts\n★ NEW BEST  ·  %s! ★" % [formatted_score, formatted_high]
		UIFx.pulse_label(_body)
	else:
		_body.add_theme_color_override("font_color", UITheme.CREAM)
		_body.text = "%s pts\nBest  ·  %s" % [formatted_score, formatted_high]


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
