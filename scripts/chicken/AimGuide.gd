extends Node2D
## 10x Zuma-style animated aiming trajectory.
## Features:
## - Color-matched core laser with radiant bloom halo
## - Animated marching energy beads flowing toward the target
## - Target collision detection with dynamic beam clamping
## - Match lock-on reticle that pulses gold when aimed at a matching color

@export var max_aim_length: float = 620.0
@export var min_aim_length: float = 60.0
@export var beam_speed: float = 460.0

var current_color: WormColor.Kind = WormColor.Kind.RED
var is_active: bool = true
var shoot_flash: float = 0.0

var _anim_time: float = 0.0
var _current_target_dist: float = 380.0
var _has_chain_target: bool = false
var _is_match_target: bool = false
var _target_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = -1
	show_behind_parent = true


func _process(delta: float) -> void:
	if not SaveService.reduced_fx:
		_anim_time += delta
	if shoot_flash > 0.0:
		shoot_flash = maxf(shoot_flash - delta * 4.5, 0.0)
	queue_redraw()


func trigger_shoot_flash() -> void:
	shoot_flash = 1.0


func update_trajectory(
	color: WormColor.Kind,
	start_offset: float,
	chain: WormChain,
	aim_angle: float,
	chicken_global_pos: Vector2
) -> void:
	current_color = color
	var aim_dir: Vector2 = Vector2.from_angle(aim_angle)
	var muzzle_global: Vector2 = chicken_global_pos + aim_dir * start_offset

	# Default beam length.
	var best_dist: float = max_aim_length
	_has_chain_target = false
	_is_match_target = false

	# Use precisely the same swept collision geometry as the real projectile.
	if chain != null and is_instance_valid(chain):
		var ray_end: Vector2 = muzzle_global + aim_dir * max_aim_length
		for worm: Worm in chain.get_worms():
			if not chain.is_worm_targetable(worm):
				continue
			var contact: Dictionary = ShootingWorm._segment_circle_hit(
				muzzle_global, ray_end, worm.global_position, ShootingWorm.CHAIN_HIT_RADIUS
			)
			if contact.is_empty():
				continue
			var distance: float = float(contact["t"]) * max_aim_length
			if distance >= best_dist:
				continue
			best_dist = distance
			_has_chain_target = true
			_is_match_target = (
				worm.worm_color == current_color
				or worm.worm_type == WormType.Kind.RAINBOW
			)

	# This node is at the launcher pivot; ray distances start at the muzzle.
	_current_target_dist = start_offset + best_dist
	_target_point = Vector2(_current_target_dist, 0.0)


func _draw() -> void:
	if not is_active:
		return

	var fill: Color = WormColor.get_fill(current_color)
	var highlight: Color = WormColor.get_highlight(current_color)

	var start_x: float = 24.0
	var end_x: float = _current_target_dist
	if end_x <= start_x:
		return

	var beam_len: float = end_x - start_x

	# =========================================================================
	# 1. Radiant Outer Glow Beam
	# =========================================================================
	var glow_alpha: float = 0.22 + shoot_flash * 0.45
	var glow_col := Color(fill.r, fill.g, fill.b, glow_alpha)
	var glow_width: float = 7.0 + shoot_flash * 5.0
	draw_line(Vector2(start_x, 0.0), Vector2(end_x, 0.0), glow_col, glow_width, true)

	# =========================================================================
	# 2. Crisp Inner Energy Core
	# =========================================================================
	var core_alpha: float = 0.65 + shoot_flash * 0.35
	var core_col := Color(highlight.r, highlight.g, highlight.b, core_alpha)
	draw_line(Vector2(start_x, 0.0), Vector2(end_x, 0.0), core_col, 2.2, true)

	# High-bright center line.
	var white_core := Color(1.0, 1.0, 1.0, 0.70 + shoot_flash * 0.30)
	draw_line(Vector2(start_x, 0.0), Vector2(end_x, 0.0), white_core, 1.0, true)

	# =========================================================================
	# 3. Animated Marching Energy Beads (Plasma pulses traveling forward)
	# =========================================================================
	var bead_spacing: float = 38.0
	var bead_offset: float = fmod(_anim_time * beam_speed, bead_spacing)
	var bx: float = start_x + bead_offset

	while bx < end_x - 10.0:
		var travel_t: float = (bx - start_x) / beam_len
		var bead_alpha: float = sin(travel_t * PI) * 0.85

		# Bead glow halo.
		draw_circle(Vector2(bx, 0.0), 4.5, Color(fill.r, fill.g, fill.b, bead_alpha * 0.5))
		# Bead inner core.
		draw_circle(Vector2(bx, 0.0), 2.2, Color(1.0, 1.0, 1.0, bead_alpha * 0.95))

		bx += bead_spacing

	# =========================================================================
	# 4. Target Impact Reticle / Lock-on Beacon
	# =========================================================================
	var tip_pos := Vector2(end_x, 0.0)
	var pulse: float = sin(_anim_time * 8.0) * 0.5 + 0.5

	if _has_chain_target:
		if _is_match_target:
			# === MATCH LOCK-ON: Golden match beacon with pulsing rings ===
			var match_glow: float = 0.65 + pulse * 0.35
			var lock_col := UITheme.YOLK_HOT

			# Outer pulsing radar ring.
			draw_arc(tip_pos, 16.0 + pulse * 4.0, 0.0, TAU, 24, Color(lock_col.r, lock_col.g, lock_col.b, match_glow * 0.45), 2.0, true)
			# Inner sharp crosshair ring.
			draw_arc(tip_pos, 10.0, 0.0, TAU, 20, lock_col, 2.2, true)
			# High-contrast center pip.
			draw_circle(tip_pos, 4.0, lock_col)
			draw_circle(tip_pos, 2.0, Color.WHITE)

			# 4 Cardinal Crosshair Tics.
			var tic_len: float = 6.0
			var tic_gap: float = 12.0
			draw_line(tip_pos + Vector2(tic_gap, 0), tip_pos + Vector2(tic_gap + tic_len, 0), lock_col, 2.0, true)
			draw_line(tip_pos - Vector2(tic_gap, 0), tip_pos - Vector2(tic_gap + tic_len, 0), lock_col, 2.0, true)
			draw_line(tip_pos + Vector2(0, tic_gap), tip_pos + Vector2(0, tic_gap + tic_len), lock_col, 2.0, true)
			draw_line(tip_pos - Vector2(0, tic_gap), tip_pos - Vector2(0, tic_gap + tic_len), lock_col, 2.0, true)
		else:
			# === STANDARD IMPACT RETICLE: Clean targeting ring ===
			var ret_col := Color(fill.r, fill.g, fill.b, 0.85)
			draw_arc(tip_pos, 9.0 + pulse * 2.0, 0.0, TAU, 18, Color(ret_col.r, ret_col.g, ret_col.b, 0.45), 1.6, true)
			draw_circle(tip_pos, 3.5, ret_col)
			draw_circle(tip_pos, 1.8, Color.WHITE)
	else:
		# === OPEN RETICLE: Soft tip beacon ===
		var beacon_alpha: float = 0.45 + pulse * 0.3
		draw_circle(tip_pos, 5.0, Color(fill.r, fill.g, fill.b, beacon_alpha * 0.5))
		draw_circle(tip_pos, 2.4, Color(1.0, 1.0, 1.0, beacon_alpha))

	# =========================================================================
	# 5. Muzzle Flash Shockwave on Discharge
	# =========================================================================
	if shoot_flash > 0.05:
		var flash_pos := Vector2(start_x, 0.0)
		var flash_r: float = 14.0 * shoot_flash
		draw_circle(flash_pos, flash_r, Color(1.0, 0.95, 0.8, shoot_flash * 0.6))
		draw_circle(flash_pos, flash_r * 0.5, Color(1.0, 1.0, 1.0, shoot_flash * 0.9))
