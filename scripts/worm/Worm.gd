class_name Worm
extends Node2D
## A single colored worm segment on the playfield.
## [member path_distance] is the displayed position; [member target_path_distance]
## is the logical slot. The chain lerps display â†’ target for glitch-free motion.

# ---------------------------------------------------------------------------
# States
# ---------------------------------------------------------------------------

enum State {
	SPAWNING,
	MOVING,
	SETTLING,
	MATCHED,
	FALLING,
	RETRACTING,
	DEAD,
	POOLED,
}

# ---------------------------------------------------------------------------
# Visual / size constants
# ---------------------------------------------------------------------------

const BODY_LENGTH: float = 36.0
const BODY_HALF_WIDTH: float = 11.0
const HEAD_RADIUS: float = 13.0
const TAIL_RADIUS: float = 6.0
const OUTLINE_WIDTH: float = 2.5
const EYE_RADIUS: float = 3.2
const PUPIL_RADIUS: float = 1.6
const MATCH_SHRINK_SPEED: float = 6.0
const FALL_GRAVITY: float = 1100.0
const FALL_DRIFT_RANGE: float = 110.0
const FALL_LIFETIME: float = 0.9
const SPAWN_DURATION: float = 0.16
const MATCH_POP_DURATION: float = 0.14

# ---------------------------------------------------------------------------
# Exported
# ---------------------------------------------------------------------------

@export var worm_color: WormColor.Kind = WormColor.Kind.RED:
	set(value):
		worm_color = value
		queue_redraw()

@export var worm_type: WormType.Kind = WormType.Kind.NORMAL:
	set(value):
		worm_type = value
		queue_redraw()

@export var state: State = State.SPAWNING:
	set(value):
		if state == value:
			return
		var old: State = state
		state = value
		_on_state_entered(old, value)
		if state != State.POOLED:
			EventBus.worm_state_changed.emit(self, old, value)

# ---------------------------------------------------------------------------
# Chain data
# ---------------------------------------------------------------------------

## Displayed distance along the path (smooth).
var path_distance: float = 0.0

## Logical slot distance the worm is easing toward.
var target_path_distance: float = 0.0

var chain_index: int = -1
var owning_chain: WormChain = null

## Optional pool that reclaim this instance instead of freeing.
var pool: WormPool = null

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

var _visual_scale: float = 0.0
var _fall_velocity: Vector2 = Vector2.ZERO
var _fall_timer: float = 0.0
var _spawn_timer: float = 0.0
var _match_timer: float = 0.0
var _match_flash: float = 0.0
## Continuous time counter used for subtle wobble on normal worms.
var _anim_time: float = 0.0
## Badge pulse for specials.
var _badge_pulse: float = 0.0
## One shared, supersampled body sheet keeps a long chain cheap to render.
## Special badges stay live; movement, collisions and matching remain on Worm.
const ATLAS_CELL := Vector2i(144, 96)
const BODY_RECT := Rect2(-36, -24, 72, 48)
static var _body_atlas: SubViewport
var _atlas_source: bool = false


func _ensure_body_atlas() -> void:
	if _atlas_source or DisplayServer.get_name() == "headless" or is_instance_valid(_body_atlas):
		return
	_body_atlas = SubViewport.new()
	_body_atlas.name = "SharedWormArtwork"
	_body_atlas.size = Vector2i(ATLAS_CELL.x * WormColor.KIND_COUNT, ATLAS_CELL.y)
	_body_atlas.disable_3d = true
	_body_atlas.transparent_bg = true
	_body_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	# The cache lives with the scene root, independent of pooled worms/levels.
	get_tree().root.add_child.call_deferred(_body_atlas)
	for i: int in range(WormColor.KIND_COUNT):
		var painter := Worm.new()
		painter._atlas_source = true
		painter.worm_color = i as WormColor.Kind
		painter.state = State.MOVING
		painter.position = Vector2(float(i * ATLAS_CELL.x) + 72.0, 48.0)
		painter.scale = Vector2(2, 2)
		_body_atlas.add_child(painter)


func _ready() -> void:
	if _atlas_source:
		set_process(false)
	else:
		_ensure_body_atlas()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_as_relative = true
	z_index = 0
	queue_redraw()


func _process(delta: float) -> void:
	if not SaveService.reduced_fx:
		_anim_time += delta
	match state:
		State.SPAWNING:
			_process_spawning(delta)
		State.MATCHED:
			_process_matched(delta)
		State.FALLING:
			_process_falling(delta)
		State.MOVING, State.SETTLING, State.RETRACTING:
			# Gentle badge pulse for specials while on the chain.
			if worm_type != WormType.Kind.NORMAL:
				_badge_pulse = sin(_anim_time * 4.5) * 0.5 + 0.5
				queue_redraw()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func setup(color: WormColor.Kind, distance: float, type: WormType.Kind = WormType.Kind.NORMAL) -> void:
	worm_color = color
	worm_type = type
	path_distance = distance
	target_path_distance = distance
	chain_index = -1
	_spawn_timer = 0.0
	_match_timer = 0.0
	_match_flash = 0.0
	_fall_timer = 0.0
	_anim_time = 0.0
	_badge_pulse = 0.0
	_visual_scale = 0.0
	scale = Vector2.ZERO
	rotation = 0.0
	modulate = Color.WHITE
	z_index = 0
	visible = true
	set_process(true)
	state = State.SPAWNING
	queue_redraw()


func set_slot_distance(distance: float, snap_display: bool = false) -> void:
	target_path_distance = distance
	if snap_display:
		path_distance = distance


func set_path_transform(world_pos: Vector2, tangent: Vector2) -> void:
	global_position = world_pos
	if tangent.length_squared() > 0.0001:
		rotation = tangent.angle()


func begin_match() -> void:
	_match_timer = 0.0
	_match_flash = 1.0
	state = State.MATCHED
	z_index = 8


func begin_fall() -> void:
	# Detach from the marching chain so pops don't slide with the train.
	var world_pos: Vector2 = global_position
	var world_rot: float = global_rotation
	var fx_host: Node = _find_fx_host()
	if fx_host != null and get_parent() != fx_host:
		reparent(fx_host, true)
	elif get_parent() != null:
		# Keep world pose if we can't find FX.
		global_position = world_pos
		global_rotation = world_rot
	state = State.FALLING
	_fall_velocity = Vector2(
		GameManager.get_fx_rng().randf_range(-FALL_DRIFT_RANGE, FALL_DRIFT_RANGE),
		GameManager.get_fx_rng().randf_range(-160.0, -30.0)
	)
	_fall_timer = 0.0
	owning_chain = null
	chain_index = -1
	z_index = 12


func _find_fx_host() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var level_host: Node = tree.current_scene.find_child("LevelHost", true, false) if tree.current_scene else null
	if level_host and level_host.get_child_count() > 0:
		var level: Node = level_host.get_child(0)
		var fx: Node = level.get_node_or_null("FX")
		if fx:
			return fx
	return tree.current_scene


func kill() -> void:
	if pool != null:
		pool.release(self)
		return
	state = State.DEAD
	queue_free()


func enter_pool() -> void:
	state = State.POOLED
	owning_chain = null
	chain_index = -1
	path_distance = 0.0
	target_path_distance = 0.0
	worm_type = WormType.Kind.NORMAL
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	z_index = 0
	set_process(false)


func exit_pool() -> void:
	# setup() will set a real state next.
	state = State.DEAD


func is_active_in_chain() -> bool:
	return (
		state == State.MOVING
		or state == State.SETTLING
		or state == State.RETRACTING
		or state == State.SPAWNING
	)


func is_pooled() -> bool:
	return state == State.POOLED


# ---------------------------------------------------------------------------
# State processors
# ---------------------------------------------------------------------------

func _on_state_entered(_old: State, new_state: State) -> void:
	match new_state:
		State.SPAWNING:
			_spawn_timer = 0.0
			_visual_scale = 0.0
			scale = Vector2.ZERO
		State.MOVING, State.SETTLING, State.RETRACTING:
			_visual_scale = 1.0
			scale = Vector2.ONE
			modulate = Color.WHITE
		State.MATCHED:
			modulate = Color(1.7, 1.7, 1.7, 1.0)
		State.FALLING:
			pass
		State.POOLED, State.DEAD:
			pass


func _process_spawning(delta: float) -> void:
	_spawn_timer += delta
	var t: float = clampf(_spawn_timer / SPAWN_DURATION, 0.0, 1.0)
	# Snappier ease-out back pop with secondary bounce.
	var overshoot: float = 1.22
	if t < 0.6:
		_visual_scale = lerpf(0.0, overshoot, t / 0.6)
	elif t < 0.8:
		_visual_scale = lerpf(overshoot, 0.92, (t - 0.6) / 0.2)
	else:
		_visual_scale = lerpf(0.92, 1.0, (t - 0.8) / 0.2)
	scale = Vector2(_visual_scale, _visual_scale)
	queue_redraw()
	if t >= 1.0:
		scale = Vector2.ONE
		state = State.MOVING


func _process_matched(delta: float) -> void:
	_match_timer += delta
	_match_flash = maxf(_match_flash - delta * 5.0, 0.0)
	var t: float = clampf(_match_timer / MATCH_POP_DURATION, 0.0, 1.0)
	# Punch out larger, then shrink away cleanly.
	if t < 0.3:
		_visual_scale = lerpf(1.0, 1.45, t / 0.3)
	else:
		_visual_scale = lerpf(1.45, 0.05, (t - 0.3) / 0.7)
	scale = Vector2(_visual_scale, _visual_scale)
	modulate = Color(1.0 + _match_flash * 0.6, 1.0 + _match_flash * 0.5, 1.0 + _match_flash * 0.2, 1.0)
	queue_redraw()


func _process_falling(delta: float) -> void:
	_fall_velocity.y += FALL_GRAVITY * delta
	global_position += _fall_velocity * delta
	rotation += delta * 6.5
	_fall_timer += delta
	var fade: float = 1.0 - clampf(_fall_timer / FALL_LIFETIME, 0.0, 1.0)
	modulate.a = fade * fade
	scale = Vector2.ONE * lerpf(0.9, 0.2, 1.0 - fade)
	if _fall_timer >= FALL_LIFETIME:
		kill()


# ---------------------------------------------------------------------------
# Drawing â€” upgraded premium worm visuals
# ---------------------------------------------------------------------------

func _draw() -> void:
	if state == State.POOLED or state == State.DEAD:
		return
	if not _atlas_source and is_instance_valid(_body_atlas):
		var region := Rect2(Vector2(float(int(worm_color) * ATLAS_CELL.x), 0), Vector2(ATLAS_CELL))
		draw_texture_rect_region(_body_atlas.get_texture(), BODY_RECT, region)
		_draw_special_badge(BODY_LENGTH * 0.39)
	else:
		_draw_worm_body()


func _draw_worm_body() -> void:
	var fill: Color = WormColor.get_fill(worm_color)
	var outline: Color = WormColor.get_outline(worm_color).darkened(0.20)
	var highlight: Color = WormColor.get_highlight(worm_color)
	# Slightly shorter silhouettes preserve the space between curved neighbors.
	# Collision and logical spacing are intentionally independent of artwork.
	var half_len: float = BODY_LENGTH * 0.39
	var shadow := Color(0.02, 0.05, 0.03, 0.35)
	draw_line(Vector2(-half_len, 4), Vector2(half_len, 4), shadow, BODY_HALF_WIDTH * 2.0 + 4.0, true)
	draw_circle(Vector2(half_len + 1, 4), HEAD_RADIUS + 2.0, shadow)
	_draw_capsule(half_len, BODY_HALF_WIDTH + 2.1, outline)
	draw_circle(Vector2(-half_len, 0), TAIL_RADIUS + 1.8, outline)
	draw_circle(Vector2(half_len, 0), HEAD_RADIUS + 2.0, outline)
	_draw_capsule(half_len, BODY_HALF_WIDTH, fill.darkened(0.13))
	draw_circle(Vector2(-half_len, 0), TAIL_RADIUS, fill)
	draw_circle(Vector2(half_len, 0), HEAD_RADIUS, fill)
	_draw_capsule(half_len - 1.0, BODY_HALF_WIDTH - 2.5, fill)

	# A broad soft dorsal highlight and thin curved segment seams give a
	# pearlescent organic body, with no hard rectangular chrome strips.
	draw_line(Vector2(-half_len + 3, -3.8), Vector2(half_len - 7, -3.8), Color(highlight.r, highlight.g, highlight.b, 0.48), 4.0, true)
	draw_circle(Vector2(-half_len + 2, -2.5), 2.5, Color(highlight.r, highlight.g, highlight.b, 0.40))
	for x: float in [-9.0, 0.0, 8.0]:
		draw_arc(Vector2(x + 8.0, 0), 9.5, 2.36, 3.92, 10, Color(outline.r, outline.g, outline.b, 0.25), 1.1, true)
	draw_arc(Vector2(half_len, -0.5), HEAD_RADIUS - 2.6, 3.6, 4.8, 12, Color(highlight.r, highlight.g, highlight.b, 0.75), 2.0, true)
	draw_circle(Vector2(half_len - 4, -7), 1.7, Color(1, 1, 0.94, 0.67))

	_draw_color_pattern(half_len, outline)
	# Diagonal eye placement keeps both pupils distinct even at small sizes.
	for eye: Vector2 in [Vector2(half_len + 2, -5.5), Vector2(half_len + 7, 0.8)]:
		draw_circle(eye, 3.8, outline)
		draw_circle(eye, 2.9, Color("fffef0"))
		draw_circle(eye + Vector2(1.1, -0.1), 1.45, Color("25382c"))
		draw_circle(eye + Vector2(0.6, -0.8), 0.65, Color.WHITE)
	draw_arc(Vector2(half_len + 4, 5), 3.0, 0.2, 2.6, 10, outline, 1.1, true)
	draw_circle(Vector2(half_len - 1, 3.5), 2.1, Color(highlight.r, highlight.g, highlight.b, 0.65))
	_draw_special_badge(half_len)


func _draw_color_pattern(_half_len: float, outline: Color) -> void:
	var mark := Color(outline.r, outline.g, outline.b, 0.88)
	WormColor.draw_symbol(self, Vector2(-4.5, 1.3), worm_color, 0.78, mark)

func _draw_special_badge(half_len: float) -> void:
	var bp: float = _badge_pulse
	var badge_pos: Vector2 = Vector2(half_len - 2.0, -HEAD_RADIUS + 1.5)
	match worm_type:
		WormType.Kind.RAINBOW:
			# Bright rainbow circle â€” rotates through hues.
			var ring_radius: float = 5.5 + bp * 0.8
			draw_circle(badge_pos, ring_radius + 1.5, Color(0.08, 0.05, 0.12))
			draw_arc(badge_pos, ring_radius, 0.0, TAU, 12, Color(1.0, 0.3, 0.9), 2.5, true)
			draw_arc(badge_pos, ring_radius - 1.5, 0.0, TAU, 12, Color(0.3, 0.9, 1.0), 1.5, true)
			draw_circle(badge_pos, 2.5, Color(1, 1, 1, 0.92))
		WormType.Kind.BOMB:
			# Black explosive circle with orange glow pulse.
			var glower: float = 5.5 + bp * 2.0
			draw_circle(badge_pos + Vector2(1, 1), glower + 1.5, Color(1.0, 0.45, 0.0, 0.35 + bp * 0.25))
			draw_circle(badge_pos, 5.5, Color(0.08, 0.08, 0.08))
			draw_circle(badge_pos, 3.0, Color(1.0, 0.40, 0.12))
			draw_circle(badge_pos + Vector2(-1.5, -1.5), 1.2, Color(1.0, 0.85, 0.45))
			# Fuse.
			draw_line(badge_pos + Vector2(-1, -5.5), badge_pos + Vector2(1, -7.5), Color(0.85, 0.55, 0.2), 1.5, true)
			draw_circle(badge_pos + Vector2(1, -7.5), 1.0, Color(1.0, 0.9, 0.3, 0.85 + bp * 0.15))
		WormType.Kind.SLOW:
			# Icy blue clock / snowflake badge.
			draw_circle(badge_pos, 5.5, Color(0.12, 0.25, 0.55))
			draw_circle(badge_pos, 4.0, Color(0.55, 0.80, 1.0))
			draw_circle(badge_pos, 2.2, Color(0.82, 0.94, 1.0))
			# Snowflake arms.
			for angle: float in [0.0, 60.0, 120.0]:
				var arm: Vector2 = Vector2.from_angle(deg_to_rad(angle)) * 3.5
				draw_line(badge_pos - arm, badge_pos + arm, Color(0.12, 0.25, 0.55), 1.0, true)
		WormType.Kind.BONUS:
			# Gold star badge with glow pulse.
			var glow: float = 0.3 + bp * 0.25
			draw_circle(badge_pos, 6.5 + bp * 0.5, Color(1.0, 0.82, 0.2, glow))
			draw_circle(badge_pos, 5.0, Color(0.72, 0.48, 0.08))
			draw_circle(badge_pos, 3.8, Color(1.0, 0.88, 0.25))
			draw_circle(badge_pos, 2.0, Color(1.0, 0.98, 0.70))
		_:
			pass


func _draw_capsule(half_len: float, half_width: float, color: Color) -> void:
	## Smooth capsule shape â€” tapers at the tail end for a worm silhouette.
	var points := PackedVector2Array()
	var segments: int = 14
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var x: float = lerpf(-half_len, half_len, t)
		# Taper tail more aggressively, keep head full-width.
		var width_factor: float = lerpf(0.45, 1.0, smoothstep(0.0, 0.55, t))
		points.append(Vector2(x, -half_width * width_factor))
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var x: float = lerpf(half_len, -half_len, t)
		var width_t: float = 1.0 - t
		var width_factor: float = lerpf(0.45, 1.0, smoothstep(0.0, 0.55, width_t))
		points.append(Vector2(x, half_width * width_factor))
	draw_colored_polygon(points, color)


func _draw_circle_local(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color)
