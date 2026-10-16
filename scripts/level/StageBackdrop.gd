class_name StageBackdrop
extends Control
## Procedural per-stage environment drawn under the track. Deterministic per
## level and redrawn only on resize, so it costs nothing per frame.

enum Look { BACKYARD, WILD_GARDEN, FORBIDDEN_COOP }

const BASES: Array[Color] = [
	Color(0.20, 0.36, 0.17),
	Color(0.11, 0.25, 0.21),
	Color(0.22, 0.14, 0.09),
]

var theme_kind: Look = Look.BACKYARD
var depth: float = 0.0
var boss_arena: bool = false
var _seed: int = 1


func configure(level_number: int, is_boss: bool) -> void:
	var n: int = maxi(level_number, 1)
	theme_kind = clampi((n - 1) / 5, 0, 2) as Look
	depth = float((n - 1) % 5) / 4.0
	boss_arena = is_boss
	_seed = n * 7919
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func base_color() -> Color:
	var c: Color = BASES[theme_kind].darkened(depth * 0.22)
	if boss_arena:
		c = c.darkened(0.12)
	return c


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, base_color(), true)
	match theme_kind:
		Look.BACKYARD:
			_draw_backyard(rng, r)
		Look.WILD_GARDEN:
			_draw_garden(rng, r)
		_:
			_draw_coop(rng, r)
	if boss_arena:
		# Spotlight on the arena centre.
		var c := Vector2(r.size.x * 0.5, r.size.y * 0.42)
		for i: int in range(6):
			draw_circle(c, r.size.y * (0.55 - float(i) * 0.07), Color(1.0, 0.95, 0.7, 0.018))
	_draw_vignette(r)


func _draw_backyard(rng: RandomNumberGenerator, r: Rect2) -> void:
	var base := base_color()
	# Mowed stripes.
	var stripe: float = 96.0
	var x: float = 0.0
	var k: int = 0
	while x < r.size.x:
		if k % 2 == 0:
			draw_rect(Rect2(x, 0, stripe, r.size.y), base.lightened(0.06), true)
		x += stripe
		k += 1
	# Grass tufts.
	for i: int in range(160):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var col := base.lightened(rng.randf_range(0.08, 0.2))
		col.a = 0.55
		for j: int in range(3):
			var a: float = -PI * 0.5 + (float(j) - 1.0) * 0.45
			draw_line(p, p + Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 11.0), col, 1.5, true)
	# Clover blossoms.
	for i: int in range(26):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var petal := Color(1, 1, 1, 0.5) if rng.randf() < 0.7 else Color(1.0, 0.86, 0.35, 0.55)
		for j: int in range(4):
			var a: float = float(j) * TAU / 4.0
			draw_circle(p + Vector2(cos(a), sin(a)) * 3.0, 2.6, petal)
		draw_circle(p, 1.6, Color(1.0, 0.8, 0.3, 0.7))
	# Pebbles.
	for i: int in range(14):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		draw_circle(p, rng.randf_range(3.0, 6.0), Color(0.62, 0.6, 0.52, 0.35))


func _draw_garden(rng: RandomNumberGenerator, r: Rect2) -> void:
	var base := base_color()
	# Dappled canopy light.
	for i: int in range(22):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var rad: float = rng.randf_range(40.0, 120.0)
		draw_circle(p, rad, Color(0.85, 1.0, 0.7, 0.035))
	# Fallen leaves.
	for i: int in range(90):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var a: float = rng.randf() * TAU
		var ln: float = rng.randf_range(8.0, 15.0)
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal() * ln * 0.38
		var col := base.lightened(rng.randf_range(0.05, 0.22))
		if rng.randf() < 0.15:
			col = Color(0.55, 0.42, 0.18)
		col.a = 0.6
		draw_colored_polygon(PackedVector2Array([p - dir * ln, p + side, p + dir * ln, p - side]), col)
		draw_line(p - dir * ln, p + dir * ln, col.darkened(0.3), 1.0, true)
	# Mushrooms.
	for i: int in range(9):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var s: float = rng.randf_range(0.8, 1.3)
		draw_rect(Rect2(p + Vector2(-2.5, 0) * s, Vector2(5, 9) * s), Color(0.93, 0.9, 0.82, 0.7), true)
		draw_circle(p, 8.0 * s, Color(0.78, 0.2, 0.18, 0.75))
		draw_circle(p + Vector2(-3, -2) * s, 1.8 * s, Color(1, 1, 1, 0.8))
		draw_circle(p + Vector2(3, -3) * s, 1.4 * s, Color(1, 1, 1, 0.8))
	# Fireflies (static glints).
	for i: int in range(18):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		draw_circle(p, 4.0, Color(0.95, 1.0, 0.5, 0.08))
		draw_circle(p, 1.4, Color(0.95, 1.0, 0.6, 0.5))


func _draw_coop(rng: RandomNumberGenerator, r: Rect2) -> void:
	var base := base_color()
	# Floor planks.
	var plank_h: float = 54.0
	var y: float = 0.0
	var row: int = 0
	while y < r.size.y:
		var tone: Color = base.lightened(0.04 if row % 2 == 0 else 0.0)
		draw_rect(Rect2(0, y, r.size.x, plank_h), tone, true)
		draw_line(Vector2(0, y), Vector2(r.size.x, y), base.darkened(0.35), 2.0)
		var seam: float = rng.randf_range(80.0, 260.0)
		while seam < r.size.x:
			draw_line(Vector2(seam, y), Vector2(seam, y + plank_h), base.darkened(0.3), 1.5)
			draw_circle(Vector2(seam - 8, y + plank_h * 0.5), 1.6, base.darkened(0.4))
			seam += rng.randf_range(220.0, 420.0)
		y += plank_h
		row += 1
	# Straw.
	for i: int in range(220):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var a: float = rng.randf() * PI
		var ln: float = rng.randf_range(6.0, 16.0)
		var col := Color(0.92, 0.78, 0.38, rng.randf_range(0.18, 0.4))
		draw_line(p, p + Vector2(cos(a), sin(a)) * ln, col, 1.5, true)
	# Feathers.
	for i: int in range(10):
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var a: float = rng.randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		var col := Color(1.0, 0.95, 0.85, 0.45) if rng.randf() < 0.6 else Color(0.95, 0.55, 0.2, 0.5)
		draw_colored_polygon(PackedVector2Array([p - dir * 12, p + dir.orthogonal() * 4, p + dir * 12, p - dir.orthogonal() * 4]), col)
		draw_line(p - dir * 14, p + dir * 12, col.darkened(0.3), 1.0, true)
	# Lantern glow from the corners.
	for c: Vector2 in [Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
		for i: int in range(5):
			draw_circle(c, 420.0 - float(i) * 70.0, Color(1.0, 0.6, 0.25, 0.025))


func _draw_vignette(r: Rect2) -> void:
	var edge := Color(0, 0, 0, 0.0)
	var dark := Color(0, 0, 0, 0.32)
	var band: float = 90.0
	for side: int in range(4):
		var pts := PackedVector2Array()
		var cols := PackedColorArray([dark, dark, edge, edge])
		match side:
			0:
				pts = PackedVector2Array([Vector2(0, 0), Vector2(r.size.x, 0), Vector2(r.size.x, band), Vector2(0, band)])
			1:
				pts = PackedVector2Array([Vector2(0, r.size.y), Vector2(r.size.x, r.size.y), Vector2(r.size.x, r.size.y - band), Vector2(0, r.size.y - band)])
			2:
				pts = PackedVector2Array([Vector2(0, 0), Vector2(0, r.size.y), Vector2(band, r.size.y), Vector2(band, 0)])
			_:
				pts = PackedVector2Array([Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y), Vector2(r.size.x - band, r.size.y), Vector2(r.size.x - band, 0)])
		draw_polygon(pts, cols)
