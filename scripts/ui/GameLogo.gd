class_name GameLogo
extends Control
## Animated "CLUCK & WORMS" wordmark: letters drop in one by one, then bob
## gently; a little worm wriggles through the ampersand.

const WORD_TOP := "CLUCK"
const WORD_BOTTOM := "WORMS"
const FONT_SIZE := 76
const AMP_SIZE := 54
const DROP_TIME := 0.42
const STAGGER := 0.06

const CLUCK_FILL := Color(1.0, 0.84, 0.26)
const CLUCK_SHADE := Color(0.86, 0.45, 0.08)
const WORMS_FILL := Color(0.55, 0.92, 0.42)
const WORMS_SHADE := Color(0.14, 0.45, 0.2)
const OUTLINE := Color(0.18, 0.08, 0.03)

var _time: float = 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.font_bold()
	custom_minimum_size = Vector2(0, FONT_SIZE + 22)


## Replays the letter drop (call when the menu reappears).
func replay() -> void:
	_time = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var reduced: bool = SaveService.reduced_fx
	var letters: Array[Dictionary] = []
	var gap: float = 18.0
	var amp_w: float = _font.get_string_size("&", HORIZONTAL_ALIGNMENT_LEFT, -1, AMP_SIZE).x
	var top_w: float = _word_width(WORD_TOP)
	var bot_w: float = _word_width(WORD_BOTTOM)
	var total: float = top_w + gap + amp_w + gap + bot_w
	var x: float = (size.x - total) * 0.5
	var baseline: float = FONT_SIZE * 0.86 + 6.0
	var idx: int = 0
	for ch: String in WORD_TOP:
		letters.append({"ch": ch, "x": x, "fill": CLUCK_FILL, "shade": CLUCK_SHADE, "i": idx})
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		idx += 1
	x += gap
	var amp_x: float = x
	x += amp_w + gap
	for ch: String in WORD_BOTTOM:
		letters.append({"ch": ch, "x": x, "fill": WORMS_FILL, "shade": WORMS_SHADE, "i": idx + 1})
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		idx += 1

	for l: Dictionary in letters:
		var i: int = int(l["i"])
		var t: float = clampf((_time - float(i) * STAGGER) / DROP_TIME, 0.0, 1.0)
		if t <= 0.0:
			continue
		var drop: float = (1.0 - _ease_out_back(t)) * -60.0
		var bob: float = 0.0 if reduced else sin(_time * 2.2 + float(i) * 0.55) * 3.5
		var pos := Vector2(float(l["x"]), baseline + drop + bob)
		var alpha: float = clampf(t * 2.0, 0.0, 1.0)
		var shade: Color = l["shade"]
		var fill: Color = l["fill"]
		shade.a = alpha
		fill.a = alpha
		var outline := OUTLINE
		outline.a = alpha
		draw_string_outline(_font, pos + Vector2(0, 5), l["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 14, outline)
		draw_string(_font, pos + Vector2(0, 5), l["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, shade)
		draw_string_outline(_font, pos, l["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 10, outline)
		draw_string(_font, pos, l["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, fill)

	# Ampersand + wriggling worm.
	var amp_t: float = clampf((_time - 5.0 * STAGGER) / DROP_TIME, 0.0, 1.0)
	if amp_t > 0.0:
		var amp_pos := Vector2(amp_x, baseline - 6.0)
		var scale_k: float = _ease_out_back(amp_t)
		draw_set_transform(amp_pos + Vector2(amp_w * 0.5, -AMP_SIZE * 0.35), sin(_time * 1.6) * 0.08 if not reduced else 0.0, Vector2(scale_k, scale_k))
		var local := Vector2(-amp_w * 0.5, AMP_SIZE * 0.35)
		draw_string_outline(_font, local, "&", HORIZONTAL_ALIGNMENT_LEFT, -1, AMP_SIZE, 10, OUTLINE)
		draw_string(_font, local, "&", HORIZONTAL_ALIGNMENT_LEFT, -1, AMP_SIZE, Color(1.0, 0.97, 0.88))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_worm(amp_pos + Vector2(amp_w * 0.5, 14.0), amp_t)


func _draw_worm(center: Vector2, appear: float) -> void:
	var segs: int = 6
	var phase: float = _time * 4.0
	var cols: Array[Color] = [Color(0.95, 0.35, 0.3), Color(0.98, 0.78, 0.22), Color(0.35, 0.75, 0.95)]
	for k: int in range(segs):
		var fx: float = (float(k) - float(segs) * 0.5) * 9.0
		var fy: float = sin(phase - float(k) * 0.8) * 4.0
		var rad: float = (6.5 if k < segs - 1 else 8.0) * appear
		var p := center + Vector2(fx, fy)
		draw_circle(p, rad + 2.0, OUTLINE)
		draw_circle(p, rad, cols[k % cols.size()])
	var head := center + Vector2((float(segs - 1) - float(segs) * 0.5) * 9.0, sin(phase - float(segs - 1) * 0.8) * 4.0)
	draw_circle(head + Vector2(2.5, -2.5), 2.4 * appear, Color.WHITE)
	draw_circle(head + Vector2(3.0, -2.5), 1.2 * appear, OUTLINE)


func _word_width(word: String) -> float:
	var w: float = 0.0
	for ch: String in word:
		w += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	return w


func _ease_out_back(t: float) -> float:
	var c: float = 1.70158
	var x: float = t - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x
