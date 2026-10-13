extends Control
## Floating HUD chrome — wells carry readability; bar stays see-through over the path.

@export var ember_theme: bool = false

const GOLD := Color(0.92, 0.78, 0.28, 0.55)
const EMBER_GOLD := Color(1.0, 0.72, 0.22, 0.55)
const ORNAMENT := Color(0.78, 0.76, 0.70, 0.35)
const EMBER_ORNAMENT := Color(0.85, 0.62, 0.32, 0.40)
const ORNAMENT_DARK := Color(0.32, 0.30, 0.28, 0.30)


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func set_ember(on: bool) -> void:
	ember_theme = on
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 8.0:
		return
	var gold := EMBER_GOLD if ember_theme else GOLD
	var lit := EMBER_ORNAMENT if ember_theme else ORNAMENT
	var dark := ORNAMENT_DARK

	# Soft wash only — worms/track stay visible underneath.
	draw_rect(r, Color(0.05, 0.05, 0.04, 0.12), true)

	# Thin gold hairline under the well row (not a full slab).
	var line_y: float = r.end.y - 2.0
	draw_line(Vector2(r.position.x + 12.0, line_y), Vector2(r.end.x - 12.0, line_y), gold, 1.5)

	# Corner bosses as light ornaments (alpha kept low).
	var c := 14.0
	for p: Vector2 in [
		r.position + Vector2(2, 2),
		Vector2(r.end.x - c - 2, r.position.y + 2),
	]:
		var cr := Rect2(p, Vector2(c, c))
		draw_rect(cr, lit, false, 1.5)
		draw_rect(cr.grow(-4), dark, false, 1.0)
