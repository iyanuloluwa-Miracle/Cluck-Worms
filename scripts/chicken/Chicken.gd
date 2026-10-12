class_name Chicken
extends Node2D
## Premium Zuma-style chicken shooter.
## Feels alive: eased aiming, punchy recoil, idle personality, instant swap.

# ---------------------------------------------------------------------------
# Aiming
# ---------------------------------------------------------------------------

## Higher = snappier turn toward the pointer (critically-damped-ish lerp rate).
@export var aim_turn_rate: float = 14.0

## Below this angular error (radians) we snap — kills micro-wobble.
@export var aim_snap_angle: float = 0.02

## Max aim-line length in pixels.
@export var aim_line_length: float = 220.0

## Aim-line opacity.
@export var aim_line_alpha: float = 0.35

# ---------------------------------------------------------------------------
# Shooting
# ---------------------------------------------------------------------------

@export var shooting_worm_scene: PackedScene

## Muzzle offset along local +X (beak tip).
@export var muzzle_distance: float = 52.0

## Minimum seconds between shots.
@export var fire_cooldown: float = 0.16

## Parent node that receives projectiles (defaults to level root).
@export var projectile_container_path: NodePath

## Chain used for projectile hit insertion.
@export var chain_path: NodePath

# ---------------------------------------------------------------------------
# Recoil / squash
# ---------------------------------------------------------------------------

@export var recoil_distance: float = 10.0
@export var recoil_recover_rate: float = 18.0
@export var shoot_stretch: Vector2 = Vector2(1.22, 0.78)
@export var shoot_squash_recover: float = 16.0

# ---------------------------------------------------------------------------
# Idle personality
# ---------------------------------------------------------------------------

@export var idle_bob_amplitude: float = 3.5
@export var idle_bob_speed: float = 2.4
@export var idle_breathe_amount: float = 0.03
@export var blink_interval_min: float = 2.2
@export var blink_interval_max: float = 5.5
@export var blink_duration: float = 0.09

# ---------------------------------------------------------------------------
# Touch / swap
# ---------------------------------------------------------------------------

## Radius around the chicken that counts as a "swap tap" on touch.
@export var swap_tap_radius: float = 70.0

## Double-tap window for touch swap (seconds).
@export var double_tap_window: float = 0.28

# ---------------------------------------------------------------------------
# Loadout
# ---------------------------------------------------------------------------

var current_color: WormColor.Kind = WormColor.Kind.RED
var next_color: WormColor.Kind = WormColor.Kind.BLUE

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

var _aim_angle: float = 0.0
var _target_angle: float = 0.0
var _pointer_pos: Vector2 = Vector2.ZERO
var _has_pointer: bool = false
var _cooldown_left: float = 0.0
var _can_shoot: bool = true

var _recoil_offset: float = 0.0
var _body_scale: Vector2 = Vector2.ONE
var _idle_time: float = 0.0
var _blink_timer: float = 0.0
var _blink_left: float = 0.0
var _is_blinking: bool = false

var _touch_ids: Dictionary = {}  # finger_id -> position
var _last_tap_time: float = -10.0
var _active_aim_finger: int = -1

## Personality / reaction state for body drawing.
var reaction: StringName = &""
var reaction_time_left: float = 0.0
var _peck_pulse: float = 0.0
var _celebrate_hop: float = 0.0
var _idle_peck_timer: float = 3.0

var _chain: WormChain
var _projectile_container: Node

@onready var _aim_pivot: Node2D = $AimPivot
@onready var _body: Node2D = $AimPivot/Body
@onready var _aim_line: Line2D = $AimPivot/AimLine
@onready var _current_preview: Node2D = $AimPivot/Body/CurrentPreview
@onready var _next_preview: Node2D = $NextPreview


func _ready() -> void:
	resolve_level_bindings()
	_roll_initial_loadout()
	_blink_timer = GameManager.get_rng().randf_range(blink_interval_min, blink_interval_max)
	_pointer_pos = get_global_mouse_position()
	_has_pointer = true
	_target_angle = (_pointer_pos - global_position).angle()
	_aim_angle = _target_angle
	_aim_pivot.rotation = _aim_angle
	_setup_aim_line()
	_refresh_previews()
	EventBus.chicken_loadout_changed.emit(current_color, next_color)
	EventBus.chicken_react.connect(_on_react)
	_idle_peck_timer = GameManager.get_rng().randf_range(2.5, 5.0)


func _process(delta: float) -> void:
	_update_reaction(delta)
	if not GameManager.can_player_act():
		# Still idle-animate while overlays show, but freeze aim/cooldown.
		_update_idle(delta)
		_apply_body_transform()
		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_update_pointer_from_devices()
	_update_aim(delta)
	_update_recoil(delta)
	_update_idle(delta)
	_update_aim_line()
	_apply_body_transform()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.can_player_act() or not _can_shoot:
		return

	# Keep pointer fresh (mouse). Touch positions update in _handle_touch / drag.
	if event is InputEventMouseMotion:
		_pointer_pos = get_global_mouse_position()
		_has_pointer = true

	# Actions cover LMB/RMB + Space (see project.godot). Avoid double-handling buttons.
	if event.is_action_pressed("swap_worm"):
		_pointer_pos = get_global_mouse_position()
		_has_pointer = true
		swap_worms()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("shoot"):
		_pointer_pos = get_global_mouse_position()
		_has_pointer = true
		_try_shoot()
		get_viewport().set_input_as_handled()
		return

	# --- Touch (mobile) ---
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_ids[drag.index] = drag.position
		if drag.index == _active_aim_finger or _active_aim_finger == -1:
			_pointer_pos = _screen_to_world(drag.position)
			_has_pointer = true
			_active_aim_finger = drag.index


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func swap_worms() -> void:
	var temp: WormColor.Kind = current_color
	current_color = next_color
	next_color = temp
	_play_swap_juice()
	_refresh_previews()
	EventBus.chicken_swapped.emit(current_color, next_color)
	EventBus.chicken_loadout_changed.emit(current_color, next_color)


func set_shooting_enabled(enabled: bool) -> void:
	_can_shoot = enabled


func get_muzzle_global_position() -> Vector2:
	return global_position + Vector2.from_angle(_aim_angle) * muzzle_distance


# ---------------------------------------------------------------------------
# Aiming
# ---------------------------------------------------------------------------

func _update_pointer_from_devices() -> void:
	# Mouse always available on desktop; touch overrides while fingers are down.
	if not _touch_ids.is_empty():
		if _active_aim_finger >= 0 and _touch_ids.has(_active_aim_finger):
			_pointer_pos = _screen_to_world(_touch_ids[_active_aim_finger])
			_has_pointer = true
		return
	_pointer_pos = get_global_mouse_position()
	_has_pointer = true


func _update_aim(delta: float) -> void:
	if not _has_pointer:
		return
	var to_pointer: Vector2 = _pointer_pos - global_position
	if to_pointer.length_squared() < 4.0:
		return

	_target_angle = to_pointer.angle()
	var diff: float = angle_difference(_aim_angle, _target_angle)
	if absf(diff) <= aim_snap_angle:
		_aim_angle = _target_angle
	else:
		# Exponential ease — responsive near the target, smooth on large turns.
		var t: float = 1.0 - exp(-aim_turn_rate * delta)
		_aim_angle = lerp_angle(_aim_angle, _target_angle, t)

	_aim_pivot.rotation = _aim_angle


func _setup_aim_line() -> void:
	_aim_line.clear_points()
	_aim_line.width = 3.0
	_aim_line.default_color = Color(1.0, 1.0, 1.0, aim_line_alpha)
	_aim_line.z_index = -1
	_aim_line.show_behind_parent = true


func _update_aim_line() -> void:
	var fill: Color = WormColor.get_fill(current_color)
	_aim_line.clear_points()
	_aim_line.default_color = Color(fill.r, fill.g, fill.b, aim_line_alpha)
	_aim_line.add_point(Vector2(muzzle_distance * 0.45, 0.0))
	_aim_line.add_point(Vector2(aim_line_length, 0.0))
	_aim_line.width = 3.5
	# Soft tip fade via gradient.
	if _aim_line.gradient == null:
		var gradient := Gradient.new()
		_aim_line.gradient = gradient
	_aim_line.gradient.colors = PackedColorArray([
		Color(fill.r, fill.g, fill.b, aim_line_alpha + 0.15),
		Color(fill.r, fill.g, fill.b, 0.0),
	])
	_aim_line.gradient.offsets = PackedFloat32Array([0.0, 1.0])


# ---------------------------------------------------------------------------
# Shooting
# ---------------------------------------------------------------------------

func _try_shoot() -> void:
	if not _can_shoot or _cooldown_left > 0.0:
		return
	if shooting_worm_scene == null:
		return

	_cooldown_left = fire_cooldown

	var dir: Vector2 = Vector2.from_angle(_aim_angle)
	var origin: Vector2 = get_muzzle_global_position()
	var color: WormColor.Kind = current_color

	var projectile: ShootingWorm = shooting_worm_scene.instantiate() as ShootingWorm
	_projectile_container.add_child(projectile)
	projectile.launch(color, origin, dir, _chain, self)

	_play_shoot_juice()
	_advance_loadout()
	EventBus.chicken_shot.emit(color, origin, dir)


func _advance_loadout() -> void:
	current_color = next_color
	next_color = GameManager.roll_worm_color()
	# Mild anti-frustration: avoid identical current/next too often.
	var colors: int = GameManager.get_active_color_count()
	if next_color == current_color and GameManager.get_rng().randf() < 0.65:
		var step: int = 1 + GameManager.get_rng().randi_range(0, maxi(colors - 2, 0))
		next_color = ((int(next_color) + step) % colors) as WormColor.Kind
	_refresh_previews()
	EventBus.chicken_loadout_changed.emit(current_color, next_color)


func _roll_initial_loadout() -> void:
	var colors: int = GameManager.get_active_color_count()
	current_color = GameManager.roll_worm_color()
	next_color = GameManager.roll_worm_color()
	if next_color == current_color:
		next_color = ((int(current_color) + 1 + (colors / 2)) % colors) as WormColor.Kind


# ---------------------------------------------------------------------------
# Juice
# ---------------------------------------------------------------------------

func _play_shoot_juice() -> void:
	_recoil_offset = recoil_distance
	_body_scale = shoot_stretch
	_play_reaction(&"peck", 0.16)
	# Tiny screen-independent punch: flash aim line.
	_aim_line.default_color.a = minf(aim_line_alpha + 0.35, 0.9)


func _play_swap_juice() -> void:
	# Quick spin-nudge on the next preview so the swap reads instantly.
	var tween := create_tween()
	tween.tween_property(_next_preview, "scale", Vector2(1.25, 1.25), 0.06)
	tween.tween_property(_next_preview, "scale", Vector2.ONE, 0.10)
	var tween_cur := create_tween()
	tween_cur.tween_property(_current_preview, "scale", Vector2(0.7, 0.7), 0.05)
	tween_cur.tween_property(_current_preview, "scale", Vector2.ONE, 0.10)


func _update_recoil(delta: float) -> void:
	_recoil_offset = lerpf(_recoil_offset, 0.0, 1.0 - exp(-recoil_recover_rate * delta))
	_body_scale = _body_scale.lerp(Vector2.ONE, 1.0 - exp(-shoot_squash_recover * delta))


func _update_idle(delta: float) -> void:
	_idle_time += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0 and not _is_blinking:
		_is_blinking = true
		_blink_left = blink_duration
	if _is_blinking:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_is_blinking = false
			_blink_timer = GameManager.get_rng().randf_range(blink_interval_min, blink_interval_max)

	# Occasional idle peck for personality.
	_idle_peck_timer -= delta
	if _idle_peck_timer <= 0.0 and reaction == &"":
		_play_reaction(&"idle_peck", 0.22)
		_idle_peck_timer = GameManager.get_rng().randf_range(3.0, 6.5)


func _update_reaction(delta: float) -> void:
	if reaction_time_left > 0.0:
		reaction_time_left -= delta
		if reaction_time_left <= 0.0:
			reaction = &""
			_peck_pulse = 0.0
			_celebrate_hop = 0.0
	match reaction:
		&"peck", &"idle_peck":
			_peck_pulse = sin((0.22 - reaction_time_left) / 0.22 * PI)
		&"celebrate":
			_celebrate_hop = sin((0.4 - reaction_time_left) / 0.4 * PI) * 10.0
		&"sigh":
			_peck_pulse = -0.3


func _play_reaction(kind: StringName, duration: float) -> void:
	reaction = kind
	reaction_time_left = duration


func _on_react(kind: StringName, _pos: Vector2) -> void:
	match kind:
		&"celebrate":
			_play_reaction(&"celebrate", 0.4)
			_body_scale = Vector2(1.15, 0.88)
		&"peck":
			_play_reaction(&"peck", 0.2)
		&"sigh":
			_play_reaction(&"sigh", 0.35)


func _apply_body_transform() -> void:
	var bob: float = sin(_idle_time * idle_bob_speed) * idle_bob_amplitude
	bob -= _celebrate_hop
	var breathe: float = 1.0 + sin(_idle_time * 2.1) * idle_breathe_amount
	# Peck stretches the body slightly toward the beak.
	var peck_stretch := Vector2(1.0 + _peck_pulse * 0.12, 1.0 - _peck_pulse * 0.08)
	_body.position = Vector2(-_recoil_offset + _peck_pulse * 4.0, bob)
	_body.scale = _body_scale * peck_stretch * Vector2(breathe, 1.0 / maxf(breathe, 0.001))


func get_peck_amount() -> float:
	return _peck_pulse


func is_celebrating() -> bool:
	return reaction == &"celebrate"


# ---------------------------------------------------------------------------
# Touch handling
# ---------------------------------------------------------------------------

func _handle_touch(event: InputEventScreenTouch) -> void:
	var screen_pos: Vector2 = event.position
	var world_pos: Vector2 = _screen_to_world(screen_pos)

	if event.pressed:
		_touch_ids[event.index] = screen_pos

		# Two-finger tap → swap.
		if _touch_ids.size() >= 2:
			swap_worms()
			get_viewport().set_input_as_handled()
			return

		# Tap on chicken / next-preview hotspot → swap (or double-tap swap).
		var on_chicken: bool = global_position.distance_to(world_pos) <= swap_tap_radius
		var on_next: bool = _next_preview.global_position.distance_to(world_pos) <= 48.0
		var now: float = Time.get_ticks_msec() / 1000.0
		if on_chicken or on_next:
			if now - _last_tap_time <= double_tap_window:
				swap_worms()
				_last_tap_time = -10.0
			else:
				# Single tap on chicken aims; second quick tap swaps.
				_last_tap_time = now
				_pointer_pos = world_pos
				_has_pointer = true
				_active_aim_finger = event.index
			get_viewport().set_input_as_handled()
			return

		# Aim + shoot toward tap (classic mobile marble-shooter).
		_pointer_pos = world_pos
		_has_pointer = true
		_active_aim_finger = event.index
		_target_angle = (world_pos - global_position).angle()
		# Partial snap so the shot isn't stale-aimed, without hard-cutting feel.
		_aim_angle = lerp_angle(_aim_angle, _target_angle, 0.85)
		_aim_pivot.rotation = _aim_angle
		_try_shoot()
		get_viewport().set_input_as_handled()
	else:
		_touch_ids.erase(event.index)
		if event.index == _active_aim_finger:
			_active_aim_finger = -1


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_xform: Transform2D = get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos


# ---------------------------------------------------------------------------
# Visual previews
# ---------------------------------------------------------------------------

func _refresh_previews() -> void:
	if _current_preview.has_method("set_preview_color"):
		_current_preview.set_preview_color(current_color)
	if _next_preview.has_method("set_preview_color"):
		_next_preview.set_preview_color(next_color)
	_current_preview.queue_redraw()
	_next_preview.queue_redraw()


## Called by Level after paths are assigned (and safe to call from _ready).
func resolve_level_bindings() -> void:
	if chain_path != NodePath(""):
		_chain = get_node_or_null(chain_path) as WormChain
	if _chain == null:
		_chain = get_parent().get_node_or_null("WormChain") as WormChain

	if projectile_container_path != NodePath(""):
		_projectile_container = get_node_or_null(projectile_container_path)
	if _projectile_container == null:
		_projectile_container = get_parent().get_node_or_null("Projectiles")
	if _projectile_container == null:
		_projectile_container = get_parent()


# ---------------------------------------------------------------------------
# Body draw — funny cartoon chicken (drawn on child so recoil stays local)
# ---------------------------------------------------------------------------

func is_blinking() -> bool:
	return _is_blinking
