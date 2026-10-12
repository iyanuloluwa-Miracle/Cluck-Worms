extends OverlayBase
## Pause overlay with resume / retry / menu.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _resume: Button = $Center/Panel/VBox/ResumeButton
@onready var _retry: Button = $Center/Panel/VBox/RetryButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	visible_state = GameManager.State.PAUSED
	super._ready()
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.text = "Paused"
	UITheme.apply_primary_button(_resume)
	UITheme.apply_ghost_button(_retry)
	UITheme.apply_ghost_button(_menu)
	_resume.text = "Resume"
	_retry.text = "Retry Level"
	_menu.text = "Main Menu"
	_resume.pressed.connect(func() -> void:
		UIFx.punch_button(_resume)
		GameManager.resume_game()
	)
	_retry.pressed.connect(func() -> void:
		UIFx.punch_button(_retry)
		GameManager.retry_level()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
