class_name FloatText
extends Node2D
## Rising feedback label (GOOD!, NICE!, NEAR!, COMBO).

var _label: Label
var _lifetime: float = 0.7
var _age: float = 0.0
var _rise: float = 48.0


func setup(text: String, color: Color, lifetime: float = 0.7) -> void:
	_lifetime = lifetime
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", color)
	_label.position = Vector2(-60, -12)
	_label.size = Vector2(120, 28)
	add_child(_label)
	z_index = 50
	scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / _lifetime
	position.y -= _rise * delta
	modulate.a = 1.0 - clampf((t - 0.45) / 0.55, 0.0, 1.0)
	if t >= 1.0:
		queue_free()
