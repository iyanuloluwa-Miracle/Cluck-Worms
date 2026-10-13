class_name InstructionIcon
extends Control
## Hand-drawn instruction glyphs for the how-to-play plaque.

enum Kind { SHOOT, MATCH, NEST, BONUS, SWAP }

@export var kind: Kind = Kind.SHOOT

var _t: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(120, 90)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 100.0
	var c := Vector2(size.x * 0.5, size.y * 0.55)
	match kind:
		Kind.SHOOT:
			_draw_shoot(c, s)
		Kind.MATCH:
			_draw_match(c, s)
		Kind.NEST:
			_draw_nest(c, s)
		Kind.BONUS:
			_draw_bonus(c, s)
		Kind.SWAP:
			_draw_swap(c, s)


func _draw_shoot(c: Vector2, s: float) -> void:
	var bob := sin(_t * 2.4) * 2.0 * s
	var o := c + Vector2(0, bob)
	# Pedestal
	draw_circle(o + Vector2(0, 28 * s), 28 * s, Color(0.45, 0.42, 0.35))
	draw_circle(o + Vector2(0, 28 * s), 22 * s, Color(0.62, 0.58, 0.48))
	# Body
	_oval(o + Vector2(0, 6 * s), 26 * s, 22 * s, Color(0.55, 0.42, 0.18))
	_oval(o + Vector2(0, 6 * s), 22 * s, 18 * s, Color(1.0, 0.9, 0.35))
	# Comb
	draw_circle(o + Vector2(-4 * s, -18 * s), 6 * s, Color(0.9, 0.22, 0.2))
	draw_circle(o + Vector2(4 * s, -20 * s), 7 * s, Color(0.95, 0.28, 0.22))
	# Beak + held worm
	draw_colored_polygon(
		PackedVector2Array([
			o + Vector2(18 * s, 0),
			o + Vector2(36 * s, -4 * s),
			o + Vector2(18 * s, 8 * s),
		]),
		Color(1.0, 0.6, 0.15)
	)
	draw_circle(o + Vector2(40 * s, 2 * s), 10 * s, Color(0.92, 0.28, 0.28))
	draw_circle(o + Vector2(40 * s, 2 * s), 6 * s, Color(1.0, 0.45, 0.4))
	# Next-color gem on back
	var gem_pulse := 0.85 + 0.15 * sin(_t * 5.0)
	draw_circle(o + Vector2(-14 * s, 2 * s), 8 * s * gem_pulse, Color(0.25, 0.85, 0.35))
	draw_circle(o + Vector2(-14 * s, 2 * s), 4 * s, Color(0.7, 1.0, 0.75))
	# Eye
	draw_circle(o + Vector2(8 * s, -6 * s), 4 * s, Color(0.1, 0.1, 0.1))


func _draw_match(c: Vector2, s: float) -> void:
	var cols: Array[Color] = [
		Color(0.98, 0.82, 0.2),
		Color(0.98, 0.82, 0.2),
		Color(0.92, 0.28, 0.28),
	]
	var base_y := c.y + 4.0 * s
	for i: int in range(3):
		var x: float = c.x + float(i - 1) * 28.0 * s
		var bounce := sin(_t * 3.0 + float(i) * 0.8) * 3.0 * s
		var p := Vector2(x, base_y + bounce)
		# Attraction spark between first two
		if i == 1:
			draw_line(p + Vector2(-18 * s, 0), p + Vector2(18 * s, 0), Color(1, 1, 0.6, 0.35), 3.0 * s, true)
		draw_circle(p, 16 * s, cols[i].darkened(0.25))
		draw_circle(p, 13 * s, cols[i])
		draw_circle(p + Vector2(-4 * s, -4 * s), 4 * s, Color(1, 1, 1, 0.45))
		# Segment rings (worm feel)
		draw_arc(p, 10 * s, 0.2, PI + 0.2, 12, cols[i].darkened(0.35), 2.0 * s, true)


func _draw_nest(c: Vector2, s: float) -> void:
	var pulse := 1.0 + 0.04 * sin(_t * 2.5)
	# Shadow
	_oval(c + Vector2(1 * s, 8 * s), 28 * s, 10 * s, Color(0, 0, 0, 0.3))
	# Straw bowl
	_oval(c + Vector2(0, 2 * s), 26 * s * pulse, 20 * s * pulse, Color(0.4, 0.24, 0.1))
	_oval(c, 22 * s, 16 * s, Color(0.55, 0.36, 0.14))
	# Fiber hints
	for i: int in range(10):
		var a: float = float(i) / 10.0 * TAU
		var p0: Vector2 = c + Vector2(cos(a), sin(a) * 0.7) * 16 * s
		var p1: Vector2 = c + Vector2(cos(a + 0.2), sin(a + 0.2) * 0.7) * 23 * s
		draw_line(p0, p1, Color(0.72, 0.52, 0.22, 0.8), 1.5 * s, true)
	# Soft bed
	_oval(c, 14 * s, 10 * s, Color(0.35, 0.42, 0.2))
	# Eggs
	_oval(c + Vector2(-5 * s, 1 * s), 4.5 * s, 5.5 * s, Color(0.97, 0.94, 0.84))
	_oval(c + Vector2(5 * s, 2 * s), 4 * s, 5 * s, Color(0.99, 0.96, 0.88))
	_oval(c + Vector2(0, -3 * s), 4.8 * s, 6 * s, Color(1.0, 0.97, 0.9))
	draw_circle(c + Vector2(-6 * s, -1 * s), 1.2 * s, Color(1, 1, 1, 0.5))


func _draw_bonus(c: Vector2, s: float) -> void:
	var spin := _t * 1.5
	var pts := PackedVector2Array()
	for i: int in range(10):
		var a: float = spin + float(i) * TAU / 10.0 - PI * 0.5
		var r: float = (18.0 if i % 2 == 0 else 9.0) * s
		pts.append(c + Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, Color(0.55, 0.4, 0.08))
	var pts2 := PackedVector2Array()
	for i: int in range(10):
		var a: float = spin + float(i) * TAU / 10.0 - PI * 0.5
		var r: float = (15.0 if i % 2 == 0 else 7.0) * s
		pts2.append(c + Vector2.from_angle(a) * r)
	draw_colored_polygon(pts2, Color(1.0, 0.88, 0.25))
	draw_circle(c, 6 * s, Color(1.0, 0.95, 0.7))
	# Rainbow badge hint
	draw_arc(c, 28 * s, 0, TAU, 24, Color(0.4, 0.9, 1.0, 0.5), 3.0 * s, true)


func _draw_swap(c: Vector2, s: float) -> void:
	# Mini chicken
	_oval(c + Vector2(-28 * s, 4 * s), 16 * s, 14 * s, Color(1.0, 0.9, 0.35))
	draw_circle(c + Vector2(-20 * s, -2 * s), 7 * s, Color(0.35, 0.75, 1.0))
	draw_circle(c + Vector2(-36 * s, 2 * s), 7 * s, Color(0.95, 0.35, 0.85))
	# Swap arrows
	var flash := 0.5 + 0.5 * sin(_t * 6.0)
	draw_arc(c + Vector2(-28 * s, 4 * s), 22 * s, -0.4, PI * 0.8, 16, Color(1, 0.9, 0.3, flash), 3.0 * s, true)
	# Mouse
	var m := c + Vector2(30 * s, 2 * s)
	_oval(m, 16 * s, 22 * s, Color(0.55, 0.55, 0.58))
	_oval(m, 13 * s, 19 * s, Color(0.78, 0.78, 0.8))
	draw_line(m + Vector2(0, -8 * s), m + Vector2(0, 6 * s), Color(0.4, 0.4, 0.42), 2.0 * s, true)
	# Right button highlight
	draw_colored_polygon(
		PackedVector2Array([
			m + Vector2(1 * s, -16 * s),
			m + Vector2(12 * s, -14 * s),
			m + Vector2(12 * s, -2 * s),
			m + Vector2(1 * s, -2 * s),
		]),
		Color(0.35, 0.85, 0.4, 0.7 + 0.3 * flash)
	)


func _oval(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(24):
		var a: float = float(i) / 24.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
