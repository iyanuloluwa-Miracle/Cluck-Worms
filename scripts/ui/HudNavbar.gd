extends Control
## Carved stone HUD bar — Zuma-inspired frame with Cluck & Worms polish.

@export var ember_theme: bool = false

const STONE := Color(0.58, 0.56, 0.52)
const STONE_LIGHT := Color(0.78, 0.76, 0.70)
const STONE_DARK := Color(0.32, 0.30, 0.28)
const GOLD := Color(0.92, 0.78, 0.28)
const EMBER_STONE := Color(0.55, 0.38, 0.28)
const EMBER_LIGHT := Color(0.85, 0.62, 0.32)


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
	var mid := EMBER_STONE if ember_theme else STONE
	var lit := EMBER_LIGHT if ember_theme else STONE_LIGHT
	var dark := STONE_DARK

	# Drop shadow
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.4), true)
	# Slab
	draw_rect(r, mid, true)
	# Bevel
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), lit, true)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 5), Vector2(r.size.x, 5)), dark, true)
	draw_rect(Rect2(r.position, Vector2(5, r.size.y)), lit, true)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 5, 0), Vector2(5, r.size.y)), dark, true)
	# Gold inner trim
	draw_rect(r.grow(-6), GOLD if not ember_theme else Color(1.0, 0.72, 0.22), false, 2.5)
	# Notch rhythm
	var x := r.position.x + 28.0
	while x < r.end.x - 28.0:
		draw_rect(Rect2(x, r.position.y + 7.0, 9.0, 4.0), dark, true)
		draw_rect(Rect2(x, r.end.y - 11.0, 9.0, 4.0), lit, true)
		x += 16.0
	# Corner bosses
	var c := 18.0
	for p: Vector2 in [
		r.position + Vector2(4, 4),
		Vector2(r.end.x - c - 4, r.position.y + 4),
		Vector2(r.position.x + 4, r.end.y - c - 4),
		Vector2(r.end.x - c - 4, r.end.y - c - 4),
	]:
		var cr := Rect2(p, Vector2(c, c))
		draw_rect(cr, lit, true)
		draw_rect(cr.grow(-3), mid, true)
		draw_rect(cr.grow(-6), dark, true)
