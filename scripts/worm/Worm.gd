class_name Worm
extends Node2D
## A single colored worm segment on the playfield.
## [member path_distance] is the displayed position; [member target_path_distance]
## is the logical slot. The chain lerps display → target for glitch-free motion.

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
const FALL_LIFETIME: float = 0.85
const SPAWN_DURATION: float = 0.14
const MATCH_POP_DURATION: float = 0.12

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


func _ready() -> void:
	z_as_relative = true
	z_index = 0
	queue_redraw()


func _process(delta: float) -> void:
	match state:
		State.SPAWNING:
			_process_spawning(delta)
		State.MATCHED:
			_process_matched(delta)
		State.FALLING:
			_process_falling(delta)
		_:
			pass


func _draw() -> void:
	if state == State.POOLED or state == State.DEAD:
		return
	_draw_worm_body()


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
		GameManager.get_rng().randf_range(-FALL_DRIFT_RANGE, FALL_DRIFT_RANGE),
		GameManager.get_rng().randf_range(-120.0, -20.0)
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
			modulate = Color(1.6, 1.6, 1.6, 1.0)
		State.FALLING:
			pass
		State.POOLED, State.DEAD:
			pass


func _process_spawning(delta: float) -> void:
	_spawn_timer += delta
	var t: float = clampf(_spawn_timer / SPAWN_DURATION, 0.0, 1.0)
	# Ease-out back pop.
	var overshoot: float = 1.18
	if t < 0.65:
		_visual_scale = lerpf(0.0, overshoot, t / 0.65)
	else:
		_visual_scale = lerpf(overshoot, 1.0, (t - 0.65) / 0.35)
	scale = Vector2(_visual_scale, _visual_scale)
	if t >= 1.0:
		scale = Vector2.ONE
		state = State.MOVING


func _process_matched(delta: float) -> void:
	_match_timer += delta
	_match_flash = maxf(_match_flash - delta * 4.0, 0.0)
	var t: float = clampf(_match_timer / MATCH_POP_DURATION, 0.0, 1.0)
	# Punch out, then shrink.
	if t < 0.35:
		_visual_scale = lerpf(1.0, 1.35, t / 0.35)
	else:
		_visual_scale = lerpf(1.35, 0.2, (t - 0.35) / 0.65)
	scale = Vector2(_visual_scale, _visual_scale)
	modulate = Color(1.0 + _match_flash, 1.0 + _match_flash * 0.8, 1.0 + _match_flash * 0.5, 1.0)


func _process_falling(delta: float) -> void:
	_fall_velocity.y += FALL_GRAVITY * delta
	global_position += _fall_velocity * delta
	rotation += delta * 5.5
	_fall_timer += delta
	var fade: float = 1.0 - clampf(_fall_timer / FALL_LIFETIME, 0.0, 1.0)
	modulate.a = fade
	scale = Vector2.ONE * lerpf(0.85, 0.35, 1.0 - fade)
	if _fall_timer >= FALL_LIFETIME:
		kill()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw_worm_body() -> void:
	var fill: Color = WormColor.get_fill(worm_color)
	var outline: Color = WormColor.get_outline(worm_color)
	var highlight: Color = WormColor.get_highlight(worm_color)
	var half_len: float = BODY_LENGTH * 0.5

	_draw_capsule(half_len, BODY_HALF_WIDTH + OUTLINE_WIDTH * 0.5, outline)
	_draw_circle_local(Vector2(half_len, 0.0), HEAD_RADIUS + OUTLINE_WIDTH * 0.5, outline)
	_draw_circle_local(Vector2(-half_len, 0.0), TAIL_RADIUS + OUTLINE_WIDTH * 0.5, outline)

	_draw_capsule(half_len, BODY_HALF_WIDTH, fill)
	_draw_circle_local(Vector2(half_len, 0.0), HEAD_RADIUS, fill)
	_draw_circle_local(Vector2(-half_len, 0.0), TAIL_RADIUS, fill)

	var belly := Color(fill.lightened(0.25), 0.55)
	draw_line(
		Vector2(-half_len + 2.0, BODY_HALF_WIDTH * 0.35),
		Vector2(half_len - 2.0, BODY_HALF_WIDTH * 0.35),
		belly,
		BODY_HALF_WIDTH * 0.55,
		true
	)

	_draw_circle_local(Vector2(half_len + 1.0, -3.0), HEAD_RADIUS * 0.35, highlight)

	# Accessibility pattern stripe unique per color.
	_draw_color_pattern(half_len, outline)

	var eye_y: float = -3.5
	var eye_x: float = half_len + 2.0
	_draw_circle_local(Vector2(eye_x, eye_y - 3.0), EYE_RADIUS, Color.WHITE)
	_draw_circle_local(Vector2(eye_x, eye_y + 3.0), EYE_RADIUS, Color.WHITE)
	_draw_circle_local(Vector2(eye_x + 1.2, eye_y - 3.0), PUPIL_RADIUS, Color(0.1, 0.1, 0.1))
	_draw_circle_local(Vector2(eye_x + 1.2, eye_y + 3.0), PUPIL_RADIUS, Color(0.1, 0.1, 0.1))

	draw_arc(
		Vector2(half_len + 6.0, 2.0),
		4.0,
		deg_to_rad(20.0),
		deg_to_rad(160.0),
		8,
		outline,
		1.5,
		true
	)

	_draw_special_badge(half_len)


func _draw_color_pattern(half_len: float, outline: Color) -> void:
	var mark := Color(outline, 0.55)
	match worm_color:
		WormColor.Kind.RED:
			draw_line(Vector2(-half_len * 0.4, -4), Vector2(half_len * 0.4, -4), mark, 1.5, true)
		WormColor.Kind.BLUE:
			draw_circle(Vector2(0, 0), 2.2, mark)
		WormColor.Kind.GREEN:
			draw_line(Vector2(-6, 5), Vector2(6, 5), mark, 1.6, true)
		WormColor.Kind.YELLOW:
			for i: int in range(3):
				draw_circle(Vector2(-8.0 + float(i) * 8.0, -5.0), 1.4, mark)
		WormColor.Kind.PURPLE:
			draw_line(Vector2(-8, -5), Vector2(8, 5), mark, 1.4, true)
		WormColor.Kind.ORANGE:
			draw_arc(Vector2(0, 0), 5.0, 0.2, PI - 0.2, 6, mark, 1.4, true)


func _draw_special_badge(half_len: float) -> void:
	match worm_type:
		WormType.Kind.RAINBOW:
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 2.0), 4.5, Color(1, 1, 1, 0.95))
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 2.0), 3.0, Color(0.95, 0.4, 0.9))
			draw_circle(Vector2(half_len - 4.0, -HEAD_RADIUS + 2.0), 2.0, Color(0.3, 0.85, 1.0))
		WormType.Kind.BOMB:
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 1.0), 5.0, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 1.0), 2.5, Color(1.0, 0.35, 0.15))
		WormType.Kind.SLOW:
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 1.0), 4.5, Color(0.55, 0.85, 1.0))
			draw_line(Vector2(half_len - 5, -HEAD_RADIUS + 1), Vector2(half_len + 1, -HEAD_RADIUS + 1), Color(0.1, 0.25, 0.4), 1.5, true)
		WormType.Kind.BONUS:
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 1.0), 4.5, Color(1.0, 0.85, 0.2))
			draw_circle(Vector2(half_len - 2.0, -HEAD_RADIUS + 1.0), 2.0, Color(1.0, 1.0, 0.7))
		_:
			pass


func _draw_capsule(half_len: float, half_width: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 12
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var x: float = lerpf(-half_len, half_len, t)
		var width_factor: float = lerpf(0.55, 1.0, t)
		points.append(Vector2(x, -half_width * width_factor))
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var x: float = lerpf(half_len, -half_len, t)
		var width_t: float = 1.0 - t
		var width_factor: float = lerpf(0.55, 1.0, width_t)
		points.append(Vector2(x, half_width * width_factor))
	draw_colored_polygon(points, color)


func _draw_circle_local(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color)
