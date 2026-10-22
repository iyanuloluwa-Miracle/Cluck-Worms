extends Node2D
## Original cream-feathered garden defender. Beak faces local +X.
## Every part is vector artwork, keeping the character crisp at any viewport.

const INK := Color("51452e")
const FEATHER := Color("fff3c7")
const FEATHER_SHADE := Color("d6c58e")
const COMB := Color("e55944")
var _wing_phase: float = 0.0
var _tail_phase: float = 0.0
var _redraw_accum: float = 0.0


func _process(delta: float) -> void:
	var chicken: Chicken = get_parent().get_parent() as Chicken
	var celebrating: bool = chicken != null and chicken.is_celebrating()
	if not SaveService.reduced_fx:
		_wing_phase += delta * (9.0 if celebrating else 3.5)
		_tail_phase += delta * 1.8
	_redraw_accum += delta
	if _redraw_accum >= maxf(QualitySettings.chicken_redraw_interval, 0.025):
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var chicken: Chicken = get_parent().get_parent() as Chicken
	var blinking: bool = chicken != null and chicken.is_blinking()
	var peck: float = chicken.get_peck_amount() if chicken else 0.0
	var celebrating: bool = chicken != null and chicken.is_celebrating()
	_ellipse(Vector2(2, 28), Vector2(36, 10), Color(0.03, 0.07, 0.04, 0.26))

	# Layered fan tail, in the same cream family as the body.
	for i: int in range(3):
		var sway: float = sin(_tail_phase + i * 0.5) * 1.6
		var tip := Vector2(-43 + i * 4, -20 + i * 12 + sway)
		draw_line(Vector2(-21, 0), tip, INK, 14, true)
		draw_circle(tip, 7, INK)
		draw_line(Vector2(-21, 0), tip, FEATHER_SHADE, 10.5, true)
		draw_circle(tip, 5.2, FEATHER)
		draw_line(Vector2(-26, -1), tip + Vector2(3, 1), Color("b6a875"), 1.0, true)

	# Compact orange feet sit behind the plump body.
	for x: float in [-9.0, 7.0]:
		draw_line(Vector2(x, 21), Vector2(x + 2, 30), INK, 4.0, true)
		draw_line(Vector2(x + 2, 30), Vector2(x + 10, 31), Color("e5a44c"), 3.0, true)
		draw_line(Vector2(x + 2, 30), Vector2(x - 3, 33), Color("e5a44c"), 2.5, true)
	_ellipse(Vector2.ZERO, Vector2(34, 28), INK)
	_ellipse(Vector2(0, -1), Vector2(31.5, 25.5), FEATHER_SHADE)
	_ellipse(Vector2(-1, -5), Vector2(30, 21.5), FEATHER)
	_ellipse(Vector2(-7, -14), Vector2(17, 7), Color("fffbe5"))

	# A forest-green kerchief is the hero's signature.
	var scarf := PackedVector2Array([Vector2(14, -14), Vector2(31, -10), Vector2(30, 7), Vector2(17, 15), Vector2(11, 9)])
	draw_colored_polygon(scarf, Color("305c48"))
	draw_polyline(PackedVector2Array([scarf[0], scarf[1], scarf[2], scarf[3], scarf[4], scarf[0]]), INK, 1.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(19, 11), Vector2(23, 26), Vector2(31, 18), Vector2(26, 8)]), Color("46765a"))
	draw_circle(Vector2(24, 10), 4.0, Color("bca65c"))
	draw_circle(Vector2(24, 9), 2.3, Color("f4dc81"))

	var head := Vector2(25.0 + peck * 7.0, -13.0 - peck * 2.5 - (2.0 if celebrating else 0.0))
	# Large scalloped comb forms a memorable silhouette.
	for i: int in range(3):
		var p: Vector2 = head + Vector2(-8 + i * 7, -20 - (4 if i == 1 else 0))
		draw_circle(p, 6.8, Color("833a2c"))
		draw_circle(p + Vector2(0, -0.5), 4.9, COMB)
		draw_circle(p + Vector2(-1.5, -2), 1.7, Color("f99774"))
	_ellipse(head, Vector2(20, 19), INK)
	_ellipse(head + Vector2(0, -1), Vector2(17.8, 16.8), FEATHER)
	_ellipse(head + Vector2(-4, -8), Vector2(9, 5), Color("fffbe8"))

	# Amber beak has a clear point and opens on the firing impulse.
	var beak: Vector2 = head + Vector2(16, 3)
	var jaw: float = peck * 4.0
	var outline := PackedVector2Array([beak + Vector2(-1, -7), beak + Vector2(19, 0), beak + Vector2(0, 8 + jaw)])
	draw_colored_polygon(outline, Color("8b592d"))
	draw_colored_polygon(PackedVector2Array([beak + Vector2(1, -4.5), beak + Vector2(15.5, -0.5), beak + Vector2(1, 1.5)]), Color("ffd177"))
	draw_colored_polygon(PackedVector2Array([beak + Vector2(1, 3 + jaw * 0.2), beak + Vector2(13, 2), beak + Vector2(1, 5.5 + jaw)]), Color("e9a340"))
	draw_circle(head + Vector2(8, 15), 5.0, Color("a24a35"))
	draw_circle(head + Vector2(7, 14), 3.6, COMB)

	# One oversized readable eye with a determined brow.
	var eye: Vector2 = head + Vector2(7, -5)
	if blinking:
		draw_arc(eye + Vector2(0, -1), 5.5, 0.1, PI - 0.1, 12, INK, 2.2, true)
	else:
		_ellipse(eye, Vector2(6.3, 7), INK)
		_ellipse(eye + Vector2(0, -0.2), Vector2(4.8, 5.7), Color("fffef2"))
		draw_circle(eye + Vector2(1.4, 0.8), 2.9, Color("263c30"))
		draw_circle(eye + Vector2(0.6, -0.4), 1.2, Color.WHITE)
	draw_line(head + Vector2(2, -14), head + Vector2(11, -12), INK, 2.0, true)
	_ellipse(head + Vector2(4, 5.5), Vector2(4.2, 2.5), Color(0.91, 0.43, 0.29, 0.45))

	# Scalloped wing covers the body with three feather tips.
	var wing_y: float = sin(_wing_phase) * (4.0 if celebrating else 1.8)
	var wing := PackedVector2Array([Vector2(-20, 1 + wing_y), Vector2(-8, -5 + wing_y), Vector2(11, 3 + wing_y), Vector2(7, 17 + wing_y), Vector2(2, 20 + wing_y), Vector2(-4, 19 + wing_y), Vector2(-8, 21 + wing_y), Vector2(-16, 17 + wing_y), Vector2(-22, 9 + wing_y)])
	draw_colored_polygon(wing, Color("e7d69e"))
	wing.append(wing[0])
	draw_polyline(wing, Color("aa9560"), 1.8, true)
	draw_arc(Vector2(-7, 3 + wing_y), 10, 0.2, 2.2, 14, Color("fff3c7"), 2.5, true)
	for i: int in range(2):
		draw_line(Vector2(-7 + i * 7, 17 + wing_y), Vector2(-3 + i * 7, 10 + wing_y), Color("b6a16d"), 1.2, true)

	if celebrating and not SaveService.reduced_fx:
		for i: int in range(4):
			var a: float = _wing_phase * 0.5 + float(i) * TAU / 4.0
			var p: Vector2 = head + Vector2.from_angle(a) * 29.0
			draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color("ffe7a0"), 1.7, true)
			draw_line(p - Vector2(0, 3), p + Vector2(0, 3), Color("ffe7a0"), 1.7, true)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(32):
		var a: float = float(i) * TAU / 32.0
		points.append(center + Vector2(cos(a), sin(a)) * radii)
	draw_colored_polygon(points, color)
