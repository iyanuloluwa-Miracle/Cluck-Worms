extends OverlayBase
## Level clear celebration.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _score: Label = $Center/Panel/VBox/Score
@onready var _lives: Label = $Center/Panel/VBox/Lives
@onready var _stars: Label = $Center/Panel/VBox/Stars
@onready var _next: Button = $Center/Panel/VBox/NextButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	visible_state = GameManager.State.LEVEL_COMPLETE
	super._ready()
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.add_theme_color_override("font_color", UITheme.SUCCESS)
	_title.text = "Level Clear!"
	UITheme.style_body(_score, UITheme.BODY_SIZE)
	UITheme.style_body(_lives, UITheme.CAPTION_SIZE + 2, true)
	UITheme.apply_primary_button(_next)
	UITheme.apply_ghost_button(_menu)
	_next.text = "Next Level"
	_menu.text = "Main Menu"
	_next.pressed.connect(func() -> void:
		UIFx.punch_button(_next)
		GameManager.advance_after_level_complete()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
	EventBus.level_completed.connect(_on_level_completed)


func _on_level_completed(_level_id: StringName, score: int, lives: int) -> void:
	var name_str: String = "Level"
	if GameManager.current_level_def:
		name_str = GameManager.current_level_def.display_name
	_score.text = "%s\n%d pts" % [name_str, score]
	_lives.text = "Lives remaining  ·  %d" % lives
	var stars: int = GameManager.last_level_stars
	_stars.text = "★".repeat(stars) + "☆".repeat(maxi(3 - stars, 0))
