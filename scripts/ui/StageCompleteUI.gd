extends OverlayBase
## Stage clear — bigger celebration beat.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _body: Label = $Center/Panel/VBox/Body
@onready var _next: Button = $Center/Panel/VBox/NextButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	visible_state = GameManager.State.STAGE_COMPLETE
	super._ready()
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.text = "Stage Complete!"
	UITheme.style_body(_body, UITheme.BODY_SIZE)
	UITheme.apply_primary_button(_next)
	UITheme.apply_ghost_button(_menu)
	_menu.text = "Main Menu"
	_next.pressed.connect(func() -> void:
		UIFx.punch_button(_next)
		GameManager.advance_after_stage_complete()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
	EventBus.stage_completed.connect(_on_stage_completed)


func show_overlay() -> void:
	var has_next: bool = GameManager.stage_index + 1 < GameManager.catalog.get_stage_count()
	_next.text = "Next Stage" if has_next else "Back to Menu"
	super.show_overlay()


func _on_stage_completed(stage_id: StringName, stage_index: int, score: int) -> void:
	var stage: StageDef = GameManager.catalog.get_stage(stage_index)
	var name_str: String = stage.display_name if stage else str(stage_id)
	_body.text = "%s\n%d pts" % [name_str, score]
