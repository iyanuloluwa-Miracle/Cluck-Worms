class_name PathFactory
extends RefCounted
## Builds smooth Curve2D paths from waypoints and ships campaign path presets.


static func build_smooth_curve(points: PackedVector2Array, smoothness: float = 0.42) -> Curve2D:
	var curve := Curve2D.new()
	var count: int = points.size()
	if count == 0:
		return curve
	if count == 1:
		curve.add_point(points[0])
		return curve

	smoothness = clampf(smoothness, 0.05, 1.0)
	for i: int in range(count):
		var pos: Vector2 = points[i]
		var in_h := Vector2.ZERO
		var out_h := Vector2.ZERO
		if i > 0 and i < count - 1:
			var prev_p: Vector2 = points[i - 1]
			var next_p: Vector2 = points[i + 1]
			var tangent: Vector2 = (next_p - prev_p) * (0.5 * smoothness)
			in_h = -tangent
			out_h = tangent
		elif i == 0 and count > 1:
			out_h = (points[1] - pos) * (0.35 * smoothness)
		elif i == count - 1 and count > 1:
			in_h = (points[count - 2] - pos) * (0.35 * smoothness)
		curve.add_point(pos, in_h, out_h)
	return curve


# ---------------------------------------------------------------------------
# Stage 1 — Farmyard Beginner (open, readable routes)
# ---------------------------------------------------------------------------

static func path_s1_l1_meadow_lane() -> PackedVector2Array:
	## Wide gentle arc — longest reaction time.
	return PackedVector2Array([
		Vector2(60, 520), Vector2(220, 420), Vector2(400, 500),
		Vector2(580, 380), Vector2(780, 460), Vector2(980, 320),
		Vector2(1180, 400),
	])


static func path_s1_l2_barn_bend() -> PackedVector2Array:
	## Soft U then rise — introduces a single decision corner.
	return PackedVector2Array([
		Vector2(80, 200), Vector2(200, 360), Vector2(180, 560),
		Vector2(400, 620), Vector2(640, 540), Vector2(880, 600),
		Vector2(1100, 480), Vector2(1200, 300),
	])


static func path_s1_l3_coop_curl() -> PackedVector2Array:
	## Double wave — players learn to lead targets.
	return PackedVector2Array([
		Vector2(70, 140), Vector2(260, 280), Vector2(180, 460),
		Vector2(360, 580), Vector2(560, 420), Vector2(760, 560),
		Vector2(960, 380), Vector2(1120, 500), Vector2(1220, 280),
	])


static func path_s1_l4_hay_spiral() -> PackedVector2Array:
	## Loose inward ribbon — stage-1 boss pacing.
	return PackedVector2Array([
		Vector2(100, 100), Vector2(420, 120), Vector2(700, 200),
		Vector2(1040, 160), Vector2(1180, 360), Vector2(980, 560),
		Vector2(640, 620), Vector2(280, 540), Vector2(160, 340),
		Vector2(320, 220), Vector2(560, 280), Vector2(820, 360),
	])


# ---------------------------------------------------------------------------
# Stage 2 — Backyard Mayhem (tighter, busier)
# ---------------------------------------------------------------------------

static func path_s2_l5_fence_zag() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(60, 600), Vector2(200, 420), Vector2(120, 240),
		Vector2(320, 140), Vector2(520, 280), Vector2(420, 480),
		Vector2(640, 580), Vector2(860, 440), Vector2(760, 220),
		Vector2(980, 140), Vector2(1180, 300), Vector2(1100, 520),
	])


static func path_s2_l6_sprinkler_coil() -> PackedVector2Array:
	## Partial spiral clockwise.
	return PackedVector2Array([
		Vector2(640, 80), Vector2(980, 160), Vector2(1160, 360),
		Vector2(1020, 580), Vector2(680, 660), Vector2(300, 580),
		Vector2(140, 360), Vector2(280, 160), Vector2(560, 180),
		Vector2(820, 300), Vector2(860, 480), Vector2(620, 520),
	])


static func path_s2_l7_figure_eight() -> PackedVector2Array:
	## Infinity / figure-8 around the chicken.
	return PackedVector2Array([
		Vector2(80, 360), Vector2(220, 180), Vector2(420, 220),
		Vector2(560, 360), Vector2(420, 520), Vector2(220, 560),
		Vector2(200, 400), Vector2(400, 360), Vector2(640, 300),
		Vector2(880, 360), Vector2(1040, 220), Vector2(1180, 300),
		Vector2(1100, 500), Vector2(900, 580), Vector2(720, 480),
		Vector2(880, 360), Vector2(1100, 200),
	])


static func path_s2_l8_hedge_maze() -> PackedVector2Array:
	## Aggressive switchbacks — stage-2 finale.
	return PackedVector2Array([
		Vector2(60, 120), Vector2(500, 100), Vector2(900, 140),
		Vector2(1180, 220), Vector2(1000, 360), Vector2(600, 320),
		Vector2(200, 380), Vector2(160, 560), Vector2(480, 620),
		Vector2(860, 580), Vector2(1160, 640), Vector2(1080, 480),
		Vector2(720, 440), Vector2(400, 500), Vector2(280, 300),
		Vector2(560, 200), Vector2(900, 280),
	])


# ---------------------------------------------------------------------------
# Stage 3 — Chicken Apocalypse (dense, punishing, fair)
# ---------------------------------------------------------------------------

static func path_s3_l9_storm_coil() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(1200, 80), Vector2(900, 60), Vector2(560, 100),
		Vector2(220, 80), Vector2(80, 220), Vector2(140, 420),
		Vector2(320, 560), Vector2(600, 640), Vector2(920, 600),
		Vector2(1140, 460), Vector2(1080, 260), Vector2(860, 180),
		Vector2(600, 240), Vector2(400, 360), Vector2(480, 520),
		Vector2(720, 560), Vector2(960, 440),
	])


static func path_s3_l10_nested_ribbons() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(40, 360), Vector2(160, 160), Vector2(400, 80),
		Vector2(700, 120), Vector2(980, 60), Vector2(1200, 180),
		Vector2(1100, 360), Vector2(1200, 540), Vector2(900, 660),
		Vector2(560, 620), Vector2(240, 680), Vector2(80, 520),
		Vector2(180, 340), Vector2(400, 280), Vector2(640, 340),
		Vector2(880, 280), Vector2(1040, 400), Vector2(860, 520),
		Vector2(600, 480), Vector2(400, 400),
	])


static func path_s3_l11_chaos_switch() -> PackedVector2Array:
	## Fast direction changes — apex skill check.
	return PackedVector2Array([
		Vector2(100, 640), Vector2(280, 480), Vector2(120, 300),
		Vector2(300, 140), Vector2(520, 260), Vector2(380, 440),
		Vector2(560, 600), Vector2(780, 480), Vector2(640, 280),
		Vector2(820, 120), Vector2(1040, 220), Vector2(920, 400),
		Vector2(1100, 560), Vector2(1240, 400), Vector2(1120, 200),
		Vector2(900, 80), Vector2(680, 160), Vector2(500, 80),
	])


static func path_s3_l12_apocalypse_spiral() -> PackedVector2Array:
	## Long inward spiral — campaign finale.
	return PackedVector2Array([
		Vector2(640, 40), Vector2(1040, 80), Vector2(1240, 280),
		Vector2(1180, 560), Vector2(860, 700), Vector2(360, 680),
		Vector2(60, 500), Vector2(80, 200), Vector2(320, 60),
		Vector2(700, 100), Vector2(1060, 200), Vector2(1120, 420),
		Vector2(900, 600), Vector2(520, 620), Vector2(220, 480),
		Vector2(240, 260), Vector2(480, 180), Vector2(780, 240),
		Vector2(900, 400), Vector2(720, 520), Vector2(480, 460),
		Vector2(420, 320), Vector2(600, 300), Vector2(740, 380),
	])
