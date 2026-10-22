class_name StageBackdrop
extends Control
## A hand-built garden diorama. All detail is seeded and rendered only on
## resize/configuration; the arena itself remains quiet behind moving worms.

enum Look { BACKYARD, WILD_GARDEN, FORBIDDEN_COOP }

const BASES: Array[Color] = [Color("405b36"), Color("244c43"), Color("473725")]
var theme_kind: Look = Look.BACKYARD
var depth: float = 0.0
var boss_arena: bool = false
var _seed: int = 1
var _bake_source: bool = false
var _level_context: Node
var _bake_viewport: SubViewport
var _bake_art: StageBackdrop


func configure(level_number: int, is_boss: bool) -> void:
	var n: int = maxi(level_number, 1)
	theme_kind = clampi((n - 1) / 5, 0, 2) as Look
	depth = float((n - 1) % 5) / 4.0
	boss_arena = is_boss
	_seed = n * 7919
	if is_node_ready() and not _bake_source:
		_rebake()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bake_source:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		resized.connect(queue_redraw)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_level_context = get_parent().get_parent()
	_bake_viewport = SubViewport.new()
	_bake_viewport.name = "SceneryCache"
	_bake_viewport.disable_3d = true
	_bake_viewport.transparent_bg = true
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_bake_viewport)
	_bake_art = StageBackdrop.new()
	_bake_art._bake_source = true
	_bake_art._level_context = _level_context
	_bake_viewport.add_child(_bake_art)
	var surface := TextureRect.new()
	surface.name = "CachedScenery"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.texture = _bake_viewport.get_texture()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	resized.connect(_rebake)
	_rebake()


func _rebake() -> void:
	if _bake_viewport == null or size.x < 1.0 or size.y < 1.0:
		return
	_bake_viewport.size = Vector2i(size)
	_bake_art.theme_kind = theme_kind
	_bake_art.depth = depth
	_bake_art.boss_arena = boss_arena
	_bake_art._seed = _seed
	_bake_art.size = size
	_bake_art.queue_redraw()
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func base_color() -> Color:
	return BASES[theme_kind].darkened(depth * 0.12 + (0.06 if boss_arena else 0.0))


func _draw() -> void:
	if not _bake_source or size.x < 1.0 or size.y < 1.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, base_color())
	if theme_kind == Look.FORBIDDEN_COOP:
		_draw_coop(rng)
	else:
		_draw_lawn(rng)
		_draw_garden_borders(rng)
	_draw_launcher_roost()
	_draw_light()
	_draw_vignette()


func _draw_lawn(rng: RandomNumberGenerator) -> void:
	var base: Color = base_color()
	# Broad overlapping scallops read as soft turf, never a checkerboard.
	for row: int in range(7):
		for col: int in range(11):
			var pos := Vector2(float(col) * 138.0 - 40.0, float(row) * 134.0 - 35.0)
			pos += Vector2(rng.randf_range(-34, 34), rng.randf_range(-24, 24))
			var tone: Color = base.lightened(rng.randf_range(0.015, 0.05))
			tone.a = 0.18
			_ellipse(pos, Vector2(rng.randf_range(76, 145), rng.randf_range(46, 95)), tone)
	# Individual grass flecks use paired shadow/highlight strokes.
	for i: int in range(470):
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var h: float = rng.randf_range(2.0, 5.0)
		var light := Color(0.73, 0.78, 0.42, rng.randf_range(0.05, 0.17))
		draw_line(p + Vector2(-2, 0), p + Vector2(-3, -h), light, 1.1, true)
		draw_line(p, p + Vector2(2, -h - 1), light, 1.1, true)
		if i % 4 == 0:
			_ellipse(p + Vector2(2, 3), Vector2(4, 1.2), Color(0.07, 0.15, 0.10, 0.12))
	# Tiny seed heads and low clover remain desaturated inside the shooting area.
	for i: int in range(70):
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var col := Color(0.68, 0.74, 0.48, 0.18)
		for j: int in range(3):
			draw_circle(p + Vector2.from_angle(float(j) * TAU / 3.0) * 2.3, 2.4, col)
	if theme_kind == Look.WILD_GARDEN:
		for i: int in range(22):
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, 7, Color(0.70, 0.95, 0.51, 0.045))
			draw_circle(p, 1.2, Color(0.85, 1.0, 0.60, 0.42))


func _draw_garden_borders(rng: RandomNumberGenerator) -> void:
	# Timber at the outer edge makes this feel like a tended kitchen garden.
	for side: int in range(2):
		var x: float = 5.0 if side == 0 else size.x - 11.0
		draw_line(Vector2(x + 5, 92), Vector2(x + 5, size.y - 36), Color("20352c"), 14, true)
		draw_line(Vector2(x, 92), Vector2(x, size.y - 36), Color("65543b"), 8, true)
		draw_line(Vector2(x - 2, 92), Vector2(x - 2, size.y - 36), Color("94815a"), 1.5, true)
		for y: int in range(106, int(size.y) - 35, 94):
			_ellipse(Vector2(x, y), Vector2(7, 10), Color("3d3c2b"))
			draw_circle(Vector2(x - 1, y - 3), 2.0, Color("b09a67"))
	# Edge foliage intentionally crops out of frame for depth.
	for side: int in range(2):
		for i: int in range(8):
			var p := Vector2(-9.0 if side == 0 else size.x + 9.0, 112.0 + i * 79.0)
			p.y += rng.randf_range(-13, 13)
			_draw_plant(p, rng.randf_range(0.65, 1.10), rng, false)
	# Four composed interior plantings. Skip any spot used by a later route.
	var beds := PackedVector2Array([
		Vector2(size.x * 0.23, size.y * 0.33), Vector2(size.x * 0.77, size.y * 0.33),
		Vector2(size.x * 0.24, size.y * 0.70), Vector2(size.x * 0.77, size.y * 0.70),
	])
	for i: int in range(beds.size()):
		var p: Vector2 = beds[i]
		if not _clear_of_track(p, 82.0):
			continue
		_ellipse(p + Vector2(3, 14), Vector2(53, 22), Color(0.07, 0.18, 0.12, 0.22))
		for j: int in range(3):
			var leaf_pos: Vector2 = p + Vector2(float(j - 1) * 23.0, float(j % 2) * 12.0)
			_draw_plant(leaf_pos, 0.73 + float(j % 2) * 0.16, rng, true)
		for j: int in range(3):
			var pebble: Vector2 = p + Vector2(-28 + j * 23, 26 + j % 2 * 4)
			_ellipse(pebble + Vector2(1, 2), Vector2(8, 4), Color(0.07, 0.13, 0.10, 0.25))
			_ellipse(pebble, Vector2(7, 3.6), Color("74785a"))
			_ellipse(pebble + Vector2(-1, -1), Vector2(4, 1.2), Color("96967a"))


func _draw_plant(p: Vector2, s: float, rng: RandomNumberGenerator, flowers: bool) -> void:
	_ellipse(p + Vector2(2, 10) * s, Vector2(34, 15) * s, Color(0.06, 0.15, 0.10, 0.30))
	for i: int in range(7):
		var angle: float = -PI + float(i) * PI / 6.0 + rng.randf_range(-0.10, 0.10)
		var tip: Vector2 = p + Vector2.from_angle(angle) * rng.randf_range(27, 43) * s
		var direction: Vector2 = tip - p
		var normal: Vector2 = direction.orthogonal().normalized() * 11.0 * s
		var points := PackedVector2Array([p, p + direction * 0.35 + normal, p + direction * 0.80 + normal * 0.55, tip, p + direction * 0.76 - normal * 0.45, p + direction * 0.3 - normal * 0.72])
		var leaf := Color("52774a") if i % 2 == 0 else Color("698251")
		if theme_kind == Look.WILD_GARDEN:
			leaf = Color("397064") if i % 2 == 0 else Color("538b6b")
		draw_colored_polygon(points, leaf.darkened(0.10 if flowers else 0.25))
		draw_line(p, tip, leaf.lightened(0.17), 1.0 * s, true)
	if flowers:
		for i: int in range(3):
			var blossom: Vector2 = p + Vector2(-13.0 + i * 14.0, -29.0 - float(i % 2) * 10.0) * s
			draw_line(p + Vector2(i * 3, 0), blossom, Color("8b985e"), 1.6 * s, true)
			var petal := Color("ead99a") if theme_kind == Look.BACKYARD else Color("b9a3cd")
			for pet: int in range(5):
				draw_circle(blossom + Vector2.from_angle(float(pet) * TAU / 5.0) * 4.0 * s, 3.3 * s, petal)
			draw_circle(blossom, 2.6 * s, Color("b68b38"))


func _draw_launcher_roost() -> void:
	var level: Node = _level_context
	var launcher: Node2D = level.get_node_or_null("Chicken") as Node2D if level != null else null
	if launcher == null:
		return
	var p: Vector2 = launcher.position
	# A moss-covered tree stump anchors the chicken to the world.
	_ellipse(p + Vector2(0, 20), Vector2(79, 52), Color(0.05, 0.12, 0.08, 0.22))
	_ellipse(p + Vector2(0, 9), Vector2(66, 51), Color("3c3929"))
	_ellipse(p + Vector2(0, 4), Vector2(65, 48), Color("6a6542"))
	_ellipse(p, Vector2(63, 45), Color("858153"))
	_ellipse(p + Vector2(0, -2), Vector2(56, 38), Color("737b4d"))
	for i: int in range(3):
		var radius: float = 20.0 + i * 12.0
		var ring := PackedVector2Array()
		for j: int in range(45):
			var a: float = float(j) / 44.0 * TAU
			ring.append(p + Vector2(cos(a) * radius, sin(a) * radius * 0.68) + Vector2(sin(a * 3) * 1.3, -1))
		draw_polyline(ring, Color(0.30, 0.35, 0.21, 0.30), 1.1, true)
	for a: float in [0.4, 2.1, 3.8, 5.5]:
		draw_line(p + Vector2(cos(a) * 52, sin(a) * 37), p + Vector2(cos(a) * 61, sin(a) * 44), Color("484c30"), 1.4, true)
	_ellipse(p + Vector2(-45, 20), Vector2(15, 7), Color("536940"))
	_ellipse(p + Vector2(47, -14), Vector2(12, 6), Color("6c8550"))


func _draw_coop(rng: RandomNumberGenerator) -> void:
	var base: Color = base_color()
	for row: int in range(int(size.y / 64.0) + 1):
		var y: float = float(row) * 64.0
		draw_rect(Rect2(0, y, size.x, 62), base.lightened(0.035 if row % 2 == 0 else 0.0))
		draw_line(Vector2(0, y), Vector2(size.x, y), base.darkened(0.35), 2.0)
		for i: int in range(16):
			var p := Vector2(rng.randf() * size.x, y + rng.randf_range(5, 58))
			draw_line(p, p + Vector2(rng.randf_range(25, 105), rng.randf_range(-1, 1)), base.lightened(0.08), 1.0, true)
		var seam: float = 90.0 + float(row % 3) * 130.0
		while seam < size.x:
			draw_line(Vector2(seam, y), Vector2(seam, y + 64), base.darkened(0.3), 1.5)
			draw_circle(Vector2(seam - 7, y + 8), 1.8, base.darkened(0.5))
			seam += 390.0
	for i: int in range(110):
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		draw_line(p, p + dir * rng.randf_range(7, 19), Color(0.85, 0.66, 0.33, 0.25), 1.3, true)


func _draw_light() -> void:
	# Large smooth vertex gradients are cheap and avoid concentric glow bands.
	var source := Vector2(size.x * 0.24, size.y * 0.20)
	var points := PackedVector2Array([source])
	var colors := PackedColorArray([Color(0.97, 0.89, 0.54, 0.12)])
	for i: int in range(33):
		var a: float = float(i) / 32.0 * TAU
		points.append(source + Vector2(cos(a) * size.x * 0.72, sin(a) * size.y * 0.94))
		colors.append(Color(0.92, 0.91, 0.60, 0.0))
	# Triangle fan prevents interpolation across a concave polygon.
	for i: int in range(1, points.size() - 1):
		draw_polygon(PackedVector2Array([points[0], points[i], points[i + 1]]), PackedColorArray([colors[0], colors[i], colors[i + 1]]))


func _draw_vignette() -> void:
	var clear := Color(0.04, 0.10, 0.08, 0.0)
	var dark := Color(0.04, 0.10, 0.08, 0.43)
	var band: float = 106.0
	for side: int in range(4):
		var points := PackedVector2Array()
		match side:
			0: points = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, band), Vector2(0, band)])
			1: points = PackedVector2Array([Vector2(0, size.y), size, Vector2(size.x, size.y - band), Vector2(0, size.y - band)])
			2: points = PackedVector2Array([Vector2.ZERO, Vector2(0, size.y), Vector2(band, size.y), Vector2(band, 0)])
			_: points = PackedVector2Array([Vector2(size.x, 0), size, Vector2(size.x - band, size.y), Vector2(size.x - band, 0)])
		draw_polygon(points, PackedColorArray([dark, dark, clear, clear]))


func _clear_of_track(p: Vector2, clearance: float) -> bool:
	var level: Node = _level_context
	var track: Path2D = level.get_node_or_null("WormPath") as Path2D if level != null else null
	if track == null or track.curve == null:
		return true
	return track.curve.get_closest_point(p).distance_squared_to(p) > clearance * clearance


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(32):
		var a: float = float(i) * TAU / 32.0
		points.append(center + Vector2(cos(a), sin(a)) * radii)
	draw_colored_polygon(points, color)
