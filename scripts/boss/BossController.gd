class_name BossController
extends Node2D
## Stage boss: intro → fight loop (idle → telegraph → attack → weak window) →
## defeat sequence. Damage comes only from real play — matches and direct
## projectile hits while the boss is vulnerable. All timing is pausable game time.

const DEFEAT_SEQUENCE_TIME: float = 1.8
const EGG_HATCH_TIME: float = 5.5
const EGG_RADIUS: float = 20.0
const EGG_HIT_DAMAGE: float = 3.0
const EGG_WORMS_ON_HATCH: int = 2
const SCORE_PER_DAMAGE: float = 10.0
const EGG_SLOTS: Array[Vector2] = [Vector2(-170, 80), Vector2(170, 80), Vector2(-250, -10), Vector2(250, -10)]

enum Mode { INTRO, IDLE, TELEGRAPH, ATTACK, DEFEATED }

var boss_def: BossDef
var health: float = 0.0
var phase: int = 1
var is_active: bool = false
var is_vulnerable: bool = false
var is_defeated: bool = false
var mode: Mode = Mode.INTRO

var _chain: WormChain
var _timer: float = 0.0
var _attack_timer: float = 0.0
var _armor_timer: float = 0.0
var _weak_timer: float = 0.0
var _pending_attack: StringName = &""
var _attack_count: int = 0
var _base_march_speed: float = 55.0
var _crest_color: WormColor.Kind = WormColor.Kind.RED
## Golden eggs: [{"pos": Vector2 (local), "time": float}]
var _eggs: Array[Dictionary] = []
var _status: StringName = &""

var _anim: float = 0.0
var _hurt_flash: float = 0.0
var _appear: float = 0.0
var _blocked_flash: float = 0.0

var _banner_layer: CanvasLayer
var _banner_box: VBoxContainer
var _banner_kicker: Label
var _banner_name: Label
var _banner_title: Label


func setup(def: BossDef, chain: WormChain) -> void:
	boss_def = def
	_chain = chain
	health = def.max_health
	phase = 1
	is_active = true
	is_defeated = false
	is_vulnerable = false
	mode = Mode.INTRO
	_timer = def.intro_duration
	_attack_timer = def.attack_interval * 0.6
	position = def.arena_position
	add_to_group(&"boss_target")
	if _chain:
		_base_march_speed = _chain.march_speed
		_chain.set_hold_march(true)
	_pick_crest_color()
	_build_banner()
	_show_banner("STAGE %d BOSS" % (GameManager.stage_index + 1), def.display_name.to_upper(), def.title, def.intro_duration)
	EventBus.boss_introduced.emit(def.id, def.display_name)
	EventBus.boss_health_changed.emit(def.id, health, def.max_health)
	EventBus.boss_phase_changed.emit(def.id, phase)
	_refresh_status()


func _ready() -> void:
	EventBus.cascade_step.connect(_on_cascade_step)
	EventBus.chain_worms_removed.connect(_on_chain_changed)


func _process(delta: float) -> void:
	if boss_def == null:
		return
	_anim += delta
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_blocked_flash = maxf(_blocked_flash - delta * 3.0, 0.0)
	_appear = minf(_appear + delta * 1.6, 1.0)
	queue_redraw()
	if mode == Mode.DEFEATED:
		_process_defeat(delta)
		return
	if not is_active:
		return

	if mode == Mode.INTRO:
		_timer -= delta
		if _timer <= 0.0:
			_finish_intro()
		return

	if _armor_timer > 0.0:
		_armor_timer = maxf(_armor_timer - delta, 0.0)
	if _weak_timer > 0.0:
		_weak_timer = maxf(_weak_timer - delta, 0.0)
	_process_eggs(delta)

	match mode:
		Mode.IDLE:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_begin_telegraph(_choose_attack())
		Mode.TELEGRAPH:
			_timer -= delta
			if _timer <= 0.0:
				_execute_attack()
		Mode.ATTACK:
			_timer -= delta
			if _timer <= 0.0:
				_end_attack()
	_refresh_status()


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

func _on_cascade_step(chain: WormChain, depth: int, count: int, color: WormColor.Kind) -> void:
	if chain != _chain or not is_active or mode == Mode.INTRO or is_defeated:
		return
	var pos: Vector2 = chain.last_match_position
	if boss_def.kind == BossDef.Kind.WORM_QUEEN and _armor_timer > 0.0:
		if color != _crest_color:
			_block(pos)
			return
		# Matching her crest color shatters the shell.
		_armor_timer = 0.0
		JuiceDirector.spawn_float_text(global_position + Vector2(0, -90), "SHELL BROKEN!", Color(0.95, 0.7, 1.0))
		_refresh_status()
	elif not is_vulnerable:
		_block(pos)
		return
	var amount: float = float(count) * boss_def.damage_per_worm + boss_def.cascade_damage_bonus * float(depth)
	_apply_damage(amount, pos)


## Swept test for a projectile segment. Returns hit parameter t in [0,1] or -1.
## A hit consumes the projectile whether or not it deals damage.
func try_absorb_projectile(from: Vector2, to: Vector2, _color: WormColor.Kind) -> float:
	if not is_active or mode == Mode.INTRO or is_defeated:
		return -1.0
	for i: int in range(_eggs.size()):
		var egg_world: Vector2 = to_global(_eggs[i]["pos"] as Vector2)
		var t_egg: float = _segment_circle_t(from, to, egg_world, EGG_RADIUS + 12.0)
		if t_egg >= 0.0:
			_eggs.remove_at(i)
			JuiceDirector.spawn_pop(egg_world, Color(1.0, 0.86, 0.3), 1.0)
			JuiceDirector.spawn_float_text(egg_world + Vector2(0, -24), "EGG SMASHED!", Color(1.0, 0.9, 0.4))
			_apply_damage(EGG_HIT_DAMAGE, egg_world, false)
			GameManager.notify_shot_resolved(true)
			return t_egg
	var t: float = _segment_circle_t(from, to, global_position, boss_def.body_radius * _appear)
	if t < 0.0:
		return -1.0
	var hit_pos: Vector2 = from.lerp(to, t)
	if is_vulnerable:
		_apply_damage(boss_def.direct_hit_damage, hit_pos)
		GameManager.notify_shot_resolved(true)
	else:
		_block(hit_pos)
		GameManager.notify_shot_resolved(false)
	return t


func _apply_damage(amount: float, world_pos: Vector2, allow_weak_bonus: bool = true) -> void:
	if amount <= 0.0 or is_defeated:
		return
	if allow_weak_bonus and _weak_timer > 0.0:
		amount *= boss_def.weak_multiplier
	# A single blow cannot skip a phase: excess damage stops at the threshold.
	var floor_hp: float = 0.0
	if phase < boss_def.phases:
		floor_hp = boss_def.max_health * (1.0 - float(phase) / float(boss_def.phases))
	amount = minf(amount, health - floor_hp)
	if amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_hurt_flash = 1.0
	GameManager.add_score(int(round(amount * SCORE_PER_DAMAGE)))
	EventBus.boss_damaged.emit(boss_def.id, amount, world_pos)
	EventBus.boss_health_changed.emit(boss_def.id, health, boss_def.max_health)
	JuiceDirector.spawn_float_text(global_position + Vector2(randf_range(-30, 30), -boss_def.body_radius - 18), "-%d" % int(round(amount)), Color(1.0, 0.55, 0.35))
	if health <= 0.0:
		_defeat()
		return
	_update_phase()


func _block(world_pos: Vector2) -> void:
	_blocked_flash = 1.0
	EventBus.boss_blocked.emit(boss_def.id, world_pos)
	var label: String = "SHELL! Match %s" % WormColor.kind_name(_crest_color) if boss_def.kind == BossDef.Kind.WORM_QUEEN and _armor_timer > 0.0 else "BLOCKED"
	JuiceDirector.spawn_float_text(global_position + Vector2(0, -boss_def.body_radius - 24), label, Color(0.75, 0.88, 1.0))


# ---------------------------------------------------------------------------
# Phases
# ---------------------------------------------------------------------------

func _update_phase() -> void:
	if boss_def.phases <= 1:
		return
	var desired: int = 1
	for p: int in range(2, boss_def.phases + 1):
		if health <= boss_def.max_health * (1.0 - float(p - 1) / float(boss_def.phases)) + 0.001:
			desired = p
	if desired <= phase:
		return
	phase = desired
	EventBus.boss_phase_changed.emit(boss_def.id, phase)
	_show_banner("PHASE %d" % phase, _phase_shout(), "", 1.4)
	JuiceDirector.add_trauma(0.35)
	_attack_timer = minf(_attack_timer, 2.5)
	if _chain:
		_chain.march_speed = _phase_speed()
	match boss_def.kind:
		BossDef.Kind.WORM_QUEEN:
			_pick_crest_color()
			_armor_timer = boss_def.armor_duration
		BossDef.Kind.GOLDEN_ROOSTER:
			_armor_timer = boss_def.armor_duration
	_refresh_status()


func _phase_shout() -> String:
	match boss_def.kind:
		BossDef.Kind.GARDEN_GUARDIAN:
			return "THE GROVE AWAKENS"
		BossDef.Kind.WORM_QUEEN:
			return "THE QUEEN IS FURIOUS" if phase >= 3 else "ROYAL GUARD RAISED"
		_:
			return "BLAZING FURY" if phase >= 3 else "THE ROOSTER CROWS"


func _phase_speed() -> float:
	var per_phase: float = 0.12
	match boss_def.kind:
		BossDef.Kind.WORM_QUEEN:
			per_phase = 0.15
		BossDef.Kind.GOLDEN_ROOSTER:
			per_phase = 0.2
	return _base_march_speed * (1.0 + float(phase - 1) * per_phase)


# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

func _finish_intro() -> void:
	mode = Mode.IDLE
	if _chain:
		_chain.set_hold_march(false)
	if boss_def.kind == BossDef.Kind.WORM_QUEEN:
		_armor_timer = boss_def.armor_duration
	_hide_banner()
	_refresh_status()


func _choose_attack() -> StringName:
	_attack_count += 1
	var alt: bool = _attack_count % 2 == 0
	match boss_def.kind:
		BossDef.Kind.GARDEN_GUARDIAN:
			return &"root_surge"
		BossDef.Kind.WORM_QUEEN:
			if phase >= 2 and alt:
				return &"royal_decree"
			return &"royal_brood"
		_:
			if phase >= 3:
				return &"golden_stare" if alt else &"egg_barrage"
			if phase >= 2 and alt:
				return &"egg_barrage"
			return &"fury_dash"


func _attack_label(attack: StringName) -> String:
	match attack:
		&"root_surge":
			return "ROOT SURGE!"
		&"royal_brood":
			return "ROYAL BROOD!"
		&"royal_decree":
			return "ROYAL DECREE!"
		&"fury_dash":
			return "FURY DASH!"
		&"egg_barrage":
			return "GOLDEN EGGS! Shoot them!"
		&"golden_stare":
			return "GOLDEN STARE!"
	return String(attack).to_upper()


func _begin_telegraph(attack: StringName) -> void:
	_pending_attack = attack
	mode = Mode.TELEGRAPH
	_timer = boss_def.telegraph_duration
	EventBus.boss_telegraph.emit(boss_def.id, attack, _timer)
	JuiceDirector.spawn_float_text(global_position + Vector2(0, boss_def.body_radius + 30), _attack_label(attack), Color(1.0, 0.82, 0.3))
	if attack == &"golden_stare" and _chain:
		_chain.set_hold_march(true)


func _execute_attack() -> void:
	mode = Mode.ATTACK
	EventBus.boss_attack.emit(boss_def.id, _pending_attack)
	_timer = 0.6
	if _chain == null:
		return
	match _pending_attack:
		&"root_surge":
			_chain.march_speed = _phase_speed() * 1.8
			_timer = 2.0
			if phase >= 2:
				_chain.inject_rear_burst(3, false)
		&"royal_brood":
			_chain.inject_rear_burst(2 + phase, true)
		&"royal_decree":
			_pick_crest_color()
			var changed: Array[Worm] = _chain.recolor_random(3 + phase, _crest_color)
			for w: Worm in changed:
				JuiceDirector.spawn_pop(w.global_position, WormColor.get_fill(_crest_color), 0.6)
		&"fury_dash":
			_chain.march_speed = _phase_speed() * 1.9
			_timer = 2.0
		&"egg_barrage":
			_lay_eggs(2 + mini(phase, 2))
		&"golden_stare":
			_chain.set_hold_march(false)
			_chain.march_speed = _phase_speed() * 2.0
			_chain.inject_rear_burst(3, true)
			_timer = 1.8
	JuiceDirector.add_trauma(0.25)


func _end_attack() -> void:
	mode = Mode.IDLE
	if _chain:
		_chain.march_speed = _phase_speed()
		_chain.set_hold_march(false)
	_attack_timer = maxf(boss_def.attack_interval - float(phase - 1) * 1.2, 4.0)
	match boss_def.kind:
		BossDef.Kind.WORM_QUEEN:
			if _armor_timer <= 0.0:
				_armor_timer = boss_def.armor_duration
			_pick_crest_color()
		_:
			# Exhausted after the attack — the clear damage window.
			_weak_timer = boss_def.weak_duration
			JuiceDirector.spawn_float_text(global_position + Vector2(0, -boss_def.body_radius - 30), "WEAK SPOT!", Color(1.0, 0.95, 0.4))
	_refresh_status()


func _lay_eggs(count: int) -> void:
	var slots: Array[Vector2] = EGG_SLOTS.duplicate()
	for _i: int in range(mini(count, slots.size())):
		var slot: Vector2 = slots.pop_at(GameManager.get_rng().randi_range(0, slots.size() - 1))
		_eggs.append({"pos": slot, "time": EGG_HATCH_TIME})


func _process_eggs(delta: float) -> void:
	for i: int in range(_eggs.size() - 1, -1, -1):
		_eggs[i]["time"] = float(_eggs[i]["time"]) - delta
		if float(_eggs[i]["time"]) <= 0.0:
			var world: Vector2 = to_global(_eggs[i]["pos"] as Vector2)
			_eggs.remove_at(i)
			JuiceDirector.spawn_float_text(world, "HATCHED!", Color(1.0, 0.6, 0.3))
			if _chain:
				_chain.inject_rear_burst(EGG_WORMS_ON_HATCH, false)


func _pick_crest_color() -> void:
	if _chain == null:
		return
	var present: Array[int] = _chain.get_present_colors()
	if present.is_empty():
		_crest_color = GameManager.roll_worm_color()
	else:
		_crest_color = present[GameManager.get_rng().randi_range(0, present.size() - 1)] as WormColor.Kind


func _on_chain_changed(chain: WormChain, _i: int, _n: int) -> void:
	# Keep the Queen's crest achievable: it must exist on the chain.
	if chain != _chain or boss_def == null or boss_def.kind != BossDef.Kind.WORM_QUEEN:
		return
	if not _chain.get_present_colors().has(int(_crest_color)):
		_pick_crest_color()
		_refresh_status(true)


# ---------------------------------------------------------------------------
# Status / defeat
# ---------------------------------------------------------------------------

func _refresh_status(force: bool = false) -> void:
	var shielded: bool = mode == Mode.INTRO or _armor_timer > 0.0
	if boss_def.kind != BossDef.Kind.WORM_QUEEN and (mode == Mode.TELEGRAPH or mode == Mode.ATTACK):
		shielded = true
	is_vulnerable = not shielded and not is_defeated
	var status: StringName = &"vulnerable"
	var detail: String = "Hit it with matches or direct shots!"
	if is_defeated:
		status = &"defeated"
		detail = ""
	elif mode == Mode.INTRO:
		status = &"intro"
		detail = boss_def.title
	elif boss_def.kind == BossDef.Kind.WORM_QUEEN and _armor_timer > 0.0:
		status = &"shielded"
		detail = "Shell up — match %s to break it" % WormColor.kind_name(_crest_color).to_upper()
	elif shielded:
		status = &"shielded" if mode != Mode.TELEGRAPH else &"attacking"
		detail = "Shielded — wait for the weak spot" if mode != Mode.TELEGRAPH else _attack_label(_pending_attack)
	elif _weak_timer > 0.0:
		status = &"weak"
		detail = "WEAK! Damage x%.1f" % boss_def.weak_multiplier
	if status != _status or force:
		_status = status
		EventBus.boss_status_changed.emit(boss_def.id, status, detail)


func _defeat() -> void:
	is_defeated = true
	is_vulnerable = false
	mode = Mode.DEFEATED
	_timer = DEFEAT_SEQUENCE_TIME
	_eggs.clear()
	remove_from_group(&"boss_target")
	if _chain:
		_chain.set_hold_march(false)
		_chain.pop_all(&"boss_defeat")
	_show_banner("VICTORY", "%s DEFEATED!" % boss_def.display_name.to_upper(), "", DEFEAT_SEQUENCE_TIME + 1.0)
	EventBus.boss_defeated.emit(boss_def.id)
	_refresh_status()


func _process_defeat(delta: float) -> void:
	if _timer <= 0.0:
		return
	var before: float = _timer
	_timer -= delta
	# Burst of pops around the body during the collapse.
	if int(before * 8.0) != int(_timer * 8.0):
		var rng := GameManager.get_rng()
		var offset := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * boss_def.body_radius
		JuiceDirector.spawn_pop(global_position + offset, _body_color().lightened(0.3), 1.1)
		JuiceDirector.add_trauma(0.12)
	if _timer <= 0.0:
		is_active = false
		visible = false
		if _chain:
			EventBus.chain_cleared.emit(_chain)


# ---------------------------------------------------------------------------
# Banner (screen-space)
# ---------------------------------------------------------------------------

func _build_banner() -> void:
	_banner_layer = CanvasLayer.new()
	_banner_layer.layer = 25
	add_child(_banner_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(root)
	_banner_box = VBoxContainer.new()
	_banner_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.add_theme_constant_override("separation", 2)
	root.add_child(_banner_box)
	_banner_kicker = _make_banner_label(22, Color(1.0, 0.78, 0.35))
	_banner_name = _make_banner_label(64, Color(1.0, 0.93, 0.5))
	_banner_title = _make_banner_label(20, Color(0.95, 0.95, 0.85))
	_banner_box.modulate.a = 0.0


func _make_banner_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_font(label, UITheme.WEIGHT_BOLD)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", maxi(6, size / 6))
	_banner_box.add_child(label)
	return label


func _show_banner(kicker: String, title: String, subtitle: String, hold: float) -> void:
	if _banner_box == null:
		return
	_banner_kicker.text = kicker
	_banner_name.text = title
	_banner_title.text = subtitle
	_banner_title.visible = not subtitle.is_empty()
	_banner_box.pivot_offset = _banner_box.size * 0.5
	var tw := _banner_box.create_tween()
	tw.tween_property(_banner_box, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_banner_box, "scale", Vector2.ONE, 0.35).from(Vector2(1.25, 1.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(hold - 0.6, 0.2))
	tw.tween_property(_banner_box, "modulate:a", 0.0, 0.35)


func _hide_banner() -> void:
	if _banner_box and _banner_box.modulate.a > 0.0:
		var tw := _banner_box.create_tween()
		tw.tween_property(_banner_box, "modulate:a", 0.0, 0.3)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _body_color() -> Color:
	match boss_def.kind:
		BossDef.Kind.GARDEN_GUARDIAN:
			return Color(0.34, 0.66, 0.26)
		BossDef.Kind.WORM_QUEEN:
			return Color(0.66, 0.28, 0.62)
		_:
			return Color(0.98, 0.76, 0.18)


func _draw() -> void:
	if boss_def == null:
		return
	var s: float = _ease_back(_appear)
	if mode == Mode.DEFEATED:
		s *= clampf(_timer / DEFEAT_SEQUENCE_TIME, 0.0, 1.0)
		draw_set_transform(Vector2(sin(_anim * 60.0) * 4.0, 0.0), sin(_anim * 30.0) * 0.08, Vector2(s, s))
	else:
		var bob: float = sin(_anim * 2.2) * 4.0
		var squash: float = 1.0 + sin(_anim * 4.4) * 0.025
		if mode == Mode.TELEGRAPH:
			bob += sin(_anim * 40.0) * 2.5
		draw_set_transform(Vector2(0, bob), 0.0, Vector2(s * squash, s / squash))

	# Ground shadow.
	draw_circle(Vector2(0, boss_def.body_radius * 0.9), boss_def.body_radius * 0.8, Color(0, 0, 0, 0.18))

	match boss_def.kind:
		BossDef.Kind.GARDEN_GUARDIAN:
			_draw_guardian()
		BossDef.Kind.WORM_QUEEN:
			_draw_queen()
		_:
			_draw_rooster()

	var r: float = boss_def.body_radius
	if _hurt_flash > 0.0:
		draw_circle(Vector2.ZERO, r * 1.02, Color(1, 1, 1, _hurt_flash * 0.45))
	# Shield ring when damage is impossible.
	if not is_vulnerable and mode != Mode.INTRO and not is_defeated:
		var shield_col := Color(0.6, 0.85, 1.0, 0.55 + _blocked_flash * 0.4)
		if boss_def.kind == BossDef.Kind.WORM_QUEEN and _armor_timer > 0.0:
			shield_col = WormColor.get_fill(_crest_color)
			shield_col.a = 0.7 + _blocked_flash * 0.3
		for k: int in range(6):
			var a0: float = _anim * 0.8 + float(k) * TAU / 6.0
			draw_arc(Vector2.ZERO, r + 12.0, a0, a0 + TAU / 6.0 - 0.18, 10, shield_col, 4.0 + _blocked_flash * 3.0, true)
	# Telegraph: tightening warning ring.
	if mode == Mode.TELEGRAPH:
		var t: float = 1.0 - clampf(_timer / maxf(boss_def.telegraph_duration, 0.01), 0.0, 1.0)
		draw_arc(Vector2.ZERO, lerpf(r * 2.4, r + 14.0, t), 0.0, TAU, 40, Color(1.0, 0.35, 0.2, 0.35 + t * 0.5), 5.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-8, -r - 26), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color(1.0, 0.4, 0.2))
	# Weak window: orbiting stars.
	if _weak_timer > 0.0 and is_vulnerable:
		for k: int in range(3):
			var a: float = _anim * 3.0 + float(k) * TAU / 3.0
			_draw_star(Vector2(cos(a), sin(a) * 0.4) * (r * 0.7) + Vector2(0, -r - 6), 7.0, Color(1.0, 0.95, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for egg: Dictionary in _eggs:
		_draw_egg(egg["pos"] as Vector2, float(egg["time"]))


func _draw_guardian() -> void:
	var r: float = boss_def.body_radius
	var body := _body_color()
	var dark := body.darkened(0.45)
	# Root feet.
	for k: int in [-1, 1]:
		draw_line(Vector2(k * r * 0.4, r * 0.6), Vector2(k * r * 0.75, r * 1.0), dark, 10.0, true)
	# Leafy crown.
	for k: int in range(7):
		var a: float = PI + float(k) / 6.0 * PI
		var tip := Vector2(cos(a), sin(a)) * (r * 1.25)
		var leaf_col: Color = body.lightened(0.15) if k % 2 == 0 else body.darkened(0.1)
		draw_colored_polygon(PackedVector2Array([tip, Vector2(cos(a - 0.3), sin(a - 0.3)) * r * 0.8, Vector2(cos(a + 0.3), sin(a + 0.3)) * r * 0.8]), leaf_col)
	draw_circle(Vector2.ZERO, r + 4.0, dark)
	draw_circle(Vector2.ZERO, r, body)
	draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.45, body.lightened(0.12))
	# Bark mask and glowing eyes.
	draw_rect(Rect2(-r * 0.65, -r * 0.28, r * 1.3, r * 0.42), Color(0.42, 0.28, 0.14), true)
	var eye := Color(1.0, 0.95, 0.4) if is_vulnerable else Color(0.95, 0.4, 0.2)
	draw_circle(Vector2(-r * 0.3, -r * 0.08), r * 0.13, eye)
	draw_circle(Vector2(r * 0.3, -r * 0.08), r * 0.13, eye)
	# Mossy mouth.
	draw_arc(Vector2(0, r * 0.35), r * 0.3, 0.2, PI - 0.2, 12, dark, 4.0, true)
	# Vine arms.
	var sway: float = sin(_anim * 3.0) * 0.3
	for k: int in [-1, 1]:
		var base := Vector2(k * r * 0.95, r * 0.1)
		var tip := base + Vector2(k * r * 0.55, -r * 0.4 + sway * k * r * 0.4)
		draw_line(base, tip, dark, 8.0, true)
		draw_circle(tip, 8.0, body.lightened(0.2))


func _draw_queen() -> void:
	var r: float = boss_def.body_radius
	var body := _body_color()
	var dark := body.darkened(0.5)
	# Coiled royal body segments behind the head.
	for k: int in range(5):
		var a: float = PI * 0.15 + float(k) * 0.32 + sin(_anim * 2.0 + k) * 0.05
		var p := Vector2(cos(a), sin(a)) * r * 0.85 + Vector2(0, r * 0.25)
		draw_circle(p, r * 0.42, dark)
		draw_circle(p, r * 0.36, body.lightened(0.05 * k))
	draw_circle(Vector2.ZERO, r + 4.0, dark)
	draw_circle(Vector2.ZERO, r, body)
	draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.4, body.lightened(0.18))
	# Crown with crest gem.
	var gold := Color(1.0, 0.82, 0.25)
	var crown := PackedVector2Array([
		Vector2(-r * 0.6, -r * 0.75), Vector2(-r * 0.45, -r * 1.25), Vector2(-r * 0.2, -r * 0.9),
		Vector2(0, -r * 1.4), Vector2(r * 0.2, -r * 0.9), Vector2(r * 0.45, -r * 1.25), Vector2(r * 0.6, -r * 0.75),
	])
	draw_colored_polygon(crown, gold)
	draw_polyline(crown, gold.darkened(0.4), 2.5, true)
	draw_circle(Vector2(0, -r * 0.98), r * 0.15, gold.darkened(0.35))
	draw_circle(Vector2(0, -r * 0.98), r * 0.12, WormColor.get_fill(_crest_color))
	# Regal eyes and lashes.
	for k: int in [-1, 1]:
		var e := Vector2(k * r * 0.32, -r * 0.1)
		draw_circle(e, r * 0.17, Color.WHITE)
		draw_circle(e + Vector2(k * 2.0, 2.0), r * 0.09, Color(0.15, 0.05, 0.15))
		draw_line(e + Vector2(-k * r * 0.12, -r * 0.16), e + Vector2(k * r * 0.18, -r * 0.24), dark, 3.0, true)
	draw_arc(Vector2(0, r * 0.3), r * 0.22, 0.3, PI - 0.3, 12, dark, 3.5, true)


func _draw_rooster() -> void:
	var r: float = boss_def.body_radius
	var body := _body_color()
	var dark := body.darkened(0.5)
	# Tail fan.
	var tail_cols: Array[Color] = [Color(0.85, 0.25, 0.15), Color(0.2, 0.55, 0.3), Color(0.15, 0.35, 0.75), Color(0.9, 0.55, 0.1)]
	for k: int in range(7):
		var a: float = -PI * 0.15 - float(k) * 0.22 + sin(_anim * 3.0 + k) * 0.04
		var base := Vector2(-r * 0.6, 0)
		var tip := base + Vector2(cos(PI + a), sin(PI + a)) * r * 1.3
		draw_line(base, tip, tail_cols[k % tail_cols.size()], 14.0, true)
	# Sun aura in later phases.
	if phase >= 2 and not is_defeated:
		var glow: float = 0.15 + 0.1 * sin(_anim * 5.0)
		draw_circle(Vector2.ZERO, r * 1.45, Color(1.0, 0.8, 0.2, glow))
	draw_circle(Vector2.ZERO, r + 4.0, dark)
	draw_circle(Vector2.ZERO, r, body)
	draw_circle(Vector2(-r * 0.2, -r * 0.3), r * 0.45, body.lightened(0.25))
	# Wing.
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.3, 0), Vector2(r * 0.35, r * 0.15), Vector2(-r * 0.1, r * 0.6)]), body.darkened(0.15))
	# Comb.
	for k: int in range(4):
		draw_circle(Vector2(-r * 0.3 + float(k) * r * 0.22, -r * 1.0 - (6.0 if k % 2 == 0 else 0.0)), r * 0.2, Color(0.95, 0.2, 0.15))
	# Beak + wattle.
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.75, -r * 0.2), Vector2(r * 1.25, -r * 0.05), Vector2(r * 0.75, r * 0.12)]), Color(1.0, 0.55, 0.1))
	draw_circle(Vector2(r * 0.8, r * 0.25), r * 0.14, Color(0.9, 0.15, 0.12))
	# Fierce eye.
	draw_circle(Vector2(r * 0.4, -r * 0.3), r * 0.17, Color.WHITE)
	draw_circle(Vector2(r * 0.46, -r * 0.28), r * 0.09, Color(0.1, 0.05, 0.02))
	draw_line(Vector2(r * 0.18, -r * 0.55), Vector2(r * 0.62, -r * 0.42), dark, 4.0, true)


func _draw_egg(local: Vector2, time_left: float) -> void:
	var wobble: float = sin(_anim * (6.0 + (EGG_HATCH_TIME - time_left) * 2.0)) * 0.12
	draw_set_transform(local, wobble, Vector2.ONE)
	draw_circle(Vector2(0, 4), EGG_RADIUS + 2.0, Color(0.45, 0.3, 0.05))
	draw_circle(Vector2.ZERO, EGG_RADIUS, Color(1.0, 0.86, 0.35))
	draw_circle(Vector2(-6, -7), EGG_RADIUS * 0.35, Color(1.0, 0.97, 0.75))
	var t: float = clampf(time_left / EGG_HATCH_TIME, 0.0, 1.0)
	draw_arc(Vector2.ZERO, EGG_RADIUS + 7.0, -PI * 0.5, -PI * 0.5 + TAU * t, 24, Color(1.0, 0.4 + t * 0.5, 0.2, 0.9), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k: int in range(10):
		var a: float = -PI * 0.5 + float(k) * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * (radius if k % 2 == 0 else radius * 0.45))
	draw_colored_polygon(pts, color)


func _ease_back(t: float) -> float:
	var c: float = 1.70158
	var x: float = t - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x


func _segment_circle_t(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var ab: Vector2 = to - from
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return 0.0 if from.distance_squared_to(center) <= radius * radius else -1.0
	var t: float = clampf((center - from).dot(ab) / len_sq, 0.0, 1.0)
	return t if (from + ab * t).distance_squared_to(center) <= radius * radius else -1.0
