class_name FancyButton
extends Button
## Primary / ghost button with press squash feedback.

@export var ghost: bool = false


func _ready() -> void:
	if ghost:
		UITheme.apply_ghost_button(self)
	else:
		UITheme.apply_primary_button(self)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(_update_pivot)
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_down() -> void:
	if SaveService.reduced_fx:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.94, 0.94), 0.05)


func _on_up() -> void:
	if SaveService.reduced_fx:
		scale = Vector2.ONE
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
