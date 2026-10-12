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
	_retry.text = "Try Again"
	_menu.text = "Main Menu"
	_retry.pressed.connect(func() -> void:
		UIFx.punch_button(_retry)
		GameManager.restart_run()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(final_score: int, high_score: int, is_new_high: bool) -> void:
	var high_line: String = "Best  ·  %d" % high_score
	if is_new_high:
		high_line = "NEW BEST  ·  %d!" % high_score
		_body.add_theme_color_override("font_color", UITheme.YOLK)
	else:
		_body.add_theme_color_override("font_color", UITheme.CREAM)
	_body.text = "%d pts\n%s" % [final_score, high_line]
