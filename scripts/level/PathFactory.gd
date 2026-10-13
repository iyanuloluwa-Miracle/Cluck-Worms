class_name PathFactory
extends RefCounted
## Builds smooth Curve2D paths from waypoints and ships campaign path presets.
## All routes leave a clear nest around the chicken (classic Zuma arena).

## Default shooter nest — center of the 1280×720 playfield.
const CHICKEN_NEST: Vector2 = Vector2(640, 400)
## Path samples stay at least this far from the chicken (worm radius + aim room).
const NEST_CLEARANCE: float = 168.0
## Keep the train below the carved stone HUD bar (Safe top 10 + bar 72 + worm/nest pad).
const HUD_TOP_SAFE: float = 118.0
## Keep clear of the bottom NEXT chip / status strip.
const HUD_BOTTOM_SAFE: float = 648.0
const PLAYFIELD_WIDTH: float = 1280.0
const PLAYFIELD_MARGIN_X: float = 28.0


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


## Push any waypoint that invades the chicken nest outward.
static func ensure_chicken_clearance(
	points: PackedVector2Array,
	chicken: Vector2 = CHICKEN_NEST,
	min_radius: float = NEST_CLEARANCE
) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i: int in range(points.size()):
		var p: Vector2 = points[i]
		var delta: Vector2 = p - chicken
		var dist: float = delta.length()
		if dist < min_radius:
			if dist < 0.01:
				out[i] = chicken + Vector2(0.0, -min_radius)
			else:
				out[i] = chicken + delta.normalized() * min_radius
		else:
			out[i] = p
	return out


## Clamp waypoints so the chain never rides under the HUD chrome.
static func ensure_hud_clearance(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	var max_x: float = PLAYFIELD_WIDTH - PLAYFIELD_MARGIN_X
	for i: int in range(points.size()):
		var p: Vector2 = points[i]
		out[i] = Vector2(
			clampf(p.x, PLAYFIELD_MARGIN_X, max_x),
			clampf(p.y, HUD_TOP_SAFE, HUD_BOTTOM_SAFE)
		)
	return out


# ---------------------------------------------------------------------------
# Stage 1 — Farmyard Beginner (outer ribbons, wide nest)
# ---------------------------------------------------------------------------

static func path_s1_l1_meadow_lane() -> PackedVector2Array:
	## Gentle outer arc: enter left, exit right pit — nest stays open.
	return PackedVector2Array([
		Vector2(40, 560), Vector2(180, 640), Vector2(400, 680),
		Vector2(700, 660), Vector2(980, 620), Vector2(1180, 520),
		Vector2(1240, 340), Vector2(1120, 160), Vector2(860, 80),
		Vector2(560, 70), Vector2(280, 120), Vector2(100, 240),
		Vector2(60, 420),
	])


static func path_s1_l2_barn_bend() -> PackedVector2Array:
	## Bottom U then climb the right wall.
	return PackedVector2Array([
		Vector2(60, 180), Vector2(80, 400), Vector2(140, 600),
		Vector2(360, 680), Vector2(640, 700), Vector2(920, 680),
		Vector2(1140, 580), Vector2(1220, 380), Vector2(1160, 180),
		Vector2(920, 80), Vector2(640, 60), Vector2(360, 90),
		Vector2(140, 160),
	])


static func path_s1_l3_coop_curl() -> PackedVector2Array:
	## Double outer wave — still rings the nest.
	return PackedVector2Array([
		Vector2(50, 120), Vector2(220, 80), Vector2(480, 60),
		Vector2(780, 90), Vector2(1080, 140), Vector2(1240, 300),
		Vector2(1200, 500), Vector2(980, 660), Vector2(680, 700),
		Vector2(380, 670), Vector2(140, 560), Vector2(60, 380),
		Vector2(100, 200), Vector2(280, 100),
	])


static func path_s1_l4_hay_spiral() -> PackedVector2Array:
	## Loose outer spiral that never crosses the nest.
	return PackedVector2Array([
		Vector2(640, 50), Vector2(980, 70), Vector2(1220, 200),
		Vector2(1240, 420), Vector2(1100, 620), Vector2(800, 700),
		Vector2(460, 700), Vector2(160, 600), Vector2(50, 400),
		Vector2(80, 180), Vector2(300, 60), Vector2(620, 50),
		Vector2(940, 100), Vector2(1160, 260), Vector2(1120, 480),
		Vector2(880, 620), Vector2(560, 640),
	])


# ---------------------------------------------------------------------------
# Stage 2 — Backyard Mayhem (tighter rings)
# ---------------------------------------------------------------------------

static func path_s2_l5_fence_zag() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(50, 640), Vector2(200, 520), Vector2(80, 320),
		Vector2(160, 120), Vector2(420, 50), Vector2(720, 70),
		Vector2(1040, 120), Vector2(1240, 280), Vector2(1180, 500),
		Vector2(960, 660), Vector2(640, 710), Vector2(320, 660),
		Vector2(100, 520), Vector2(60, 300),
	])


static func path_s2_l6_sprinkler_coil() -> PackedVector2Array:
	## Clockwise ring that tightens slightly — nest remains clear.
	return PackedVector2Array([
		Vector2(640, 55), Vector2(980, 90), Vector2(1220, 240),
		Vector2(1240, 460), Vector2(1060, 640), Vector2(740, 710),
		Vector2(400, 700), Vector2(140, 580), Vector2(50, 380),
		Vector2(100, 160), Vector2(340, 50), Vector2(640, 55),
		Vector2(920, 120), Vector2(1140, 280), Vector2(1100, 500),
		Vector2(860, 640),
	])


static func path_s2_l7_figure_eight() -> PackedVector2Array:
	## Wide infinity loops that orbit the nest (never through it).
	return PackedVector2Array([
		Vector2(60, 360), Vector2(140, 160), Vector2(360, 70),
		Vector2(520, 160), Vector2(480, 320), Vector2(300, 420),
		Vector2(140, 520), Vector2(280, 640), Vector2(520, 680),
		Vector2(640, 560), Vector2(760, 680), Vector2(1000, 640),
		Vector2(1160, 500), Vector2(1000, 360), Vector2(820, 220),
		Vector2(980, 90), Vector2(1180, 160), Vector2(1240, 360),
	])


static func path_s2_l8_hedge_maze() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(50, 100), Vector2(360, 50), Vector2(720, 60),
		Vector2(1080, 100), Vector2(1240, 260), Vector2(1180, 460),
		Vector2(960, 620), Vector2(640, 700), Vector2(300, 640),
		Vector2(80, 500), Vector2(50, 280), Vector2(180, 100),
		Vector2(460, 50), Vector2(780, 80), Vector2(1100, 180),
		Vector2(1220, 380), Vector2(1080, 580), Vector2(760, 660),
	])


# ---------------------------------------------------------------------------
# Stage 3 — Chicken Apocalypse (dense outer coils)
# ---------------------------------------------------------------------------

static func path_s3_l9_storm_coil() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(1240, 80), Vector2(900, 45), Vector2(520, 55),
		Vector2(180, 90), Vector2(50, 240), Vector2(60, 460),
		Vector2(200, 640), Vector2(500, 710), Vector2(860, 700),
		Vector2(1160, 580), Vector2(1240, 360), Vector2(1120, 160),
		Vector2(820, 70), Vector2(480, 90), Vector2(180, 200),
		Vector2(80, 400), Vector2(180, 580), Vector2(480, 680),
		Vector2(820, 650),
	])


static func path_s3_l10_nested_ribbons() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(40, 360), Vector2(80, 160), Vector2(300, 50),
		Vector2(640, 40), Vector2(980, 60), Vector2(1220, 180),
		Vector2(1260, 400), Vector2(1180, 600), Vector2(900, 700),
		Vector2(560, 720), Vector2(220, 640), Vector2(50, 480),
		Vector2(70, 260), Vector2(260, 90), Vector2(560, 50),
		Vector2(900, 80), Vector2(1180, 220), Vector2(1200, 460),
		Vector2(980, 640), Vector2(640, 680),
	])


static func path_s3_l11_chaos_switch() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(80, 680), Vector2(280, 560), Vector2(100, 360),
		Vector2(200, 140), Vector2(460, 50), Vector2(760, 70),
		Vector2(1080, 140), Vector2(1240, 320), Vector2(1160, 540),
		Vector2(900, 680), Vector2(560, 720), Vector2(240, 620),
		Vector2(60, 440), Vector2(100, 200), Vector2(360, 60),
		Vector2(700, 50), Vector2(1040, 120), Vector2(1240, 280),
	])


static func path_s3_l12_apocalypse_spiral() -> PackedVector2Array:
	## Long outer spiral that slowly tightens — still clears the nest.
	return PackedVector2Array([
		Vector2(640, 35), Vector2(1020, 55), Vector2(1260, 220),
		Vector2(1260, 480), Vector2(1040, 680), Vector2(700, 730),
		Vector2(340, 700), Vector2(60, 540), Vector2(40, 280),
		Vector2(180, 80), Vector2(520, 35), Vector2(900, 55),
		Vector2(1200, 180), Vector2(1220, 420), Vector2(1020, 620),
		Vector2(680, 700), Vector2(320, 640), Vector2(80, 460),
		Vector2(90, 220), Vector2(320, 70), Vector2(640, 45),
		Vector2(960, 100), Vector2(1160, 280), Vector2(1100, 520),
		Vector2(820, 650), Vector2(500, 640),
	])


# ---------------------------------------------------------------------------
# Stage 4 — Moonlit Garden (expert outer routes)
# ---------------------------------------------------------------------------

static func path_s4_l13_moon_ring() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(640, 40), Vector2(1000, 80), Vector2(1240, 260),
		Vector2(1220, 520), Vector2(940, 700), Vector2(560, 720),
		Vector2(200, 620), Vector2(50, 400), Vector2(120, 160),
		Vector2(400, 50), Vector2(760, 60), Vector2(1100, 180),
		Vector2(1180, 420), Vector2(960, 620),
	])


static func path_s4_l14_lantern_zag() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(50, 100), Vector2(280, 60), Vector2(560, 120),
		Vector2(820, 50), Vector2(1120, 120), Vector2(1240, 320),
		Vector2(1100, 520), Vector2(820, 660), Vector2(480, 700),
		Vector2(160, 580), Vector2(60, 340), Vector2(180, 120),
		Vector2(460, 60), Vector2(780, 140), Vector2(1080, 280),
	])


static func path_s4_l15_dew_spiral() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(60, 360), Vector2(120, 140), Vector2(380, 50),
		Vector2(720, 70), Vector2(1080, 140), Vector2(1240, 360),
		Vector2(1140, 580), Vector2(800, 700), Vector2(420, 680),
		Vector2(120, 520), Vector2(80, 280), Vector2(260, 100),
		Vector2(600, 60), Vector2(960, 120), Vector2(1180, 300),
		Vector2(1080, 540), Vector2(740, 660),
	])


static func path_s4_l16_night_switch() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(100, 680), Vector2(320, 520), Vector2(120, 320),
		Vector2(300, 100), Vector2(600, 60), Vector2(920, 120),
		Vector2(1200, 280), Vector2(1120, 520), Vector2(820, 680),
		Vector2(480, 720), Vector2(160, 580), Vector2(80, 340),
		Vector2(220, 120), Vector2(560, 50), Vector2(940, 90),
		Vector2(1220, 240), Vector2(1180, 480),
	])


static func path_s4_l17_comet_coil() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(1240, 80), Vector2(900, 40), Vector2(520, 60),
		Vector2(160, 120), Vector2(50, 320), Vector2(100, 560),
		Vector2(360, 700), Vector2(740, 720), Vector2(1100, 600),
		Vector2(1240, 380), Vector2(1080, 160), Vector2(720, 70),
		Vector2(360, 100), Vector2(100, 260), Vector2(140, 500),
		Vector2(420, 660), Vector2(800, 640),
	])


static func path_s4_l18_midnight_finale() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(640, 35), Vector2(1040, 60), Vector2(1260, 240),
		Vector2(1240, 500), Vector2(980, 700), Vector2(580, 730),
		Vector2(200, 620), Vector2(40, 400), Vector2(80, 160),
		Vector2(360, 45), Vector2(740, 50), Vector2(1120, 140),
		Vector2(1220, 360), Vector2(1080, 580), Vector2(740, 690),
		Vector2(380, 660), Vector2(100, 500), Vector2(80, 260),
		Vector2(300, 80), Vector2(640, 50), Vector2(980, 120),
		Vector2(1160, 320), Vector2(1040, 560), Vector2(700, 660),
	])
