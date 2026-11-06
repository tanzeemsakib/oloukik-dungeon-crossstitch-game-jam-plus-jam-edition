extends Control
## Ransom-note text, Persona 5 style: every letter sits on its own cut-out
## block (white, black or an accent color), slightly rotated and offset, and a
## few letters re-jitter every fraction of a second so it feels hand-cut.
##
## Drop-in replacement for a Label: set .text, .position, .size, .modulate.
## Text is centered inside `size` unless `centered` is false.
## Uses the project's default font (your custom font).

const Pal = preload("res://scripts/palette.gd")
@export var text := "":
	set = _set_text
@export var font_size := 36
@export var accent := Pal.RED
@export_range(0.0, 1.0) var accent_share := 0.35   # chance a block uses the accent color
@export var centered := true
@export var jitter := true
# false: plain text in your font (use this when the font is already ransom-note
# style). true: draws each letter on its own cut-out block on top of the font.
@export var use_blocks := false
# Plain mode only: draw the text inside a black speech bubble with a white edge
# and a little tail (used for pop-ups). The text color is `accent`.
@export var bubble := false

var _styles: Array = []
var _rng := RandomNumberGenerator.new()
var _tick := 0.0


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_styles()


func _set_text(value: String) -> void:
	if value == text:
		return
	text = value
	_ensure_styles()
	queue_redraw()


func _ensure_styles() -> void:
	# Existing letters keep their look, so changing "60 hp" to "55 hp" does not
	# reshuffle every block. Only new positions get a fresh random style.
	while _styles.size() < text.length():
		_styles.append(_new_style())


func _new_style() -> Dictionary:
	var roll := _rng.randf()
	var kind := 0  # 0 white block, 1 black block, 2 accent block
	if roll < accent_share:
		kind = 2
	elif _rng.randf() < 0.5:
		kind = 1
	return {
		"kind": kind,
		"rot": deg_to_rad(_rng.randf_range(-7.0, 7.0)),
		"dy": _rng.randf_range(-0.07, 0.07),    # fraction of font_size
		"k": _rng.randf_range(0.88, 1.12),      # size variation
	}


func _process(delta: float) -> void:
	if not use_blocks or not jitter or not is_visible_in_tree() or text.is_empty():
		return
	_tick += delta
	if _tick < 0.18:
		return
	_tick = 0.0
	for st in _styles:
		if _rng.randf() < 0.2:
			st["rot"] = clampf(st["rot"] + deg_to_rad(_rng.randf_range(-2.5, 2.5)), deg_to_rad(-9.0), deg_to_rad(9.0))
			st["dy"] = clampf(st["dy"] + _rng.randf_range(-0.03, 0.03), -0.09, 0.09)
	queue_redraw()


func _draw_bubble(center: Vector2, text_width: float) -> void:
	# Plain black rectangle with a white edge.
	var hw := text_width * 0.5 + font_size * 0.7
	var hh := font_size * 0.72
	var rect := Rect2(center - Vector2(hw, hh), Vector2(hw * 2.0, hh * 2.0))
	draw_rect(rect.grow(4.0), Pal.PAPER, true)
	draw_rect(rect, Pal.INK, true)


func _draw() -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()

	if not use_blocks:
		# Plain mode: your font as-is, accent-colored, with a dark outline.
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var tx := (size.x - tw) * 0.5 if centered else 0.0
		var ty := size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		var origin := Vector2(tx, ty)
		if bubble:
			_draw_bubble(Vector2(tx + tw * 0.5, size.y * 0.5 - font_size * 0.05), tw)
		else:
			draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Pal.INK)
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)
		return

	_ensure_styles()
	var pad := font_size * 0.12
	var gap := font_size * 0.05
	var n := text.length()

	var widths: Array[float] = []
	var total := 0.0
	for i in n:
		var ch := text[i]
		var fs := int(font_size * _styles[i]["k"])
		var w := font_size * 0.35
		if ch != " ":
			w = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad * 2.0
		widths.append(w)
		total += w + gap
	total -= gap

	var x := (size.x - total) * 0.5 if centered else 0.0
	var cy := size.y * 0.5
	for i in n:
		var w := widths[i]
		var ch := text[i]
		if ch != " ":
			var st: Dictionary = _styles[i]
			var fs := int(font_size * st["k"])
			var h := fs * 1.15
			draw_set_transform(Vector2(x + w * 0.5, cy + st["dy"] * font_size), st["rot"], Vector2.ONE)
			var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
			var ink := Pal.INK
			match st["kind"]:
				0:
					draw_rect(rect, Pal.PAPER, true)
				1:
					draw_rect(rect, Pal.INK, true)
					draw_rect(rect, Pal.PAPER, false, 2.0)
					ink = Pal.PAPER
				_:
					draw_rect(rect, accent, true)
			var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
			draw_string(font, Vector2(-w * 0.5 + pad, baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += w + gap
