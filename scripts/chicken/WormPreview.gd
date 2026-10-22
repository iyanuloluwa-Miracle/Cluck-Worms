extends Node2D
## Loaded and reserve worms share the chain's shape code and visual language.

@export var preview_scale: float = 1.0
@export var show_label: bool = false
var _color: WormColor.Kind = WormColor.Kind.RED


func set_preview_color(color: WormColor.Kind) -> void:
	_color = color
	queue_redraw()


func _draw() -> void:
	var fill: Color = WormColor.get_fill(_color)
	var outline: Color = WormColor.get_outline(_color).darkened(0.2)
	var highlight: Color = WormColor.get_highlight(_color)
	var s: float = preview_scale
	# Cream keyline keeps the tiny ammunition readable against feathers.
	draw_line(Vector2(-8, 0) * s, Vector2(5, 0) * s, Color("fff3c7"), 17.0 * s, true)
	draw_circle(Vector2(6, 0) * s, 10.0 * s, Color("fff3c7"))
	draw_line(Vector2(-8, 0) * s, Vector2(5, 0) * s, outline, 13.0 * s, true)
	draw_circle(Vector2(6, 0) * s, 8.3 * s, outline)
	draw_line(Vector2(-8, 0) * s, Vector2(5, 0) * s, fill, 9.5 * s, true)
	draw_circle(Vector2(6, 0) * s, 6.6 * s, fill)
	draw_line(Vector2(-6, -2.2) * s, Vector2(2, -2.2) * s, highlight, 2.2 * s, true)
	draw_circle(Vector2(5, -3.8) * s, 1.5 * s, highlight)
	WormColor.draw_symbol(self, Vector2(-3, 0.8) * s, _color, s * 0.55, outline)
	draw_circle(Vector2(9, -1.5) * s, 2.3 * s, outline)
	draw_circle(Vector2(9, -1.5) * s, 1.7 * s, Color("fffef0"))
	draw_circle(Vector2(9.6, -1.5) * s, 0.85 * s, Color("25382c"))
