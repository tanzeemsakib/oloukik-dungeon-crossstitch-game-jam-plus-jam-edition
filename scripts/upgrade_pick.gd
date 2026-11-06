extends Control
## Shown between fights: pick one of three upgrades with A, S or D.
## Call start(options) with an Array of {"label": String, "desc": String}.
## Emits chosen(index) a moment after the pick.

const Pal = preload("res://scripts/palette.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal chosen(index: int)

const COLORS := [Pal.RED, Pal.GREEN, Pal.BLUE]
const BOX_W := 280.0
const BOX_H := 140.0
const GAP := 40.0

var options: Array = []
var sets: Array = [[KEY_A], [KEY_S], [KEY_D]]   # keys that pick option 0, 1, 2
var open := false
var picked := -1
var hold := 0.0
var grace := 0.0   # ignore presses right after opening (ring mashing)


func start(opts: Array, key_sets: Array = []) -> void:
	options = opts
	if not key_sets.is_empty():
		sets = key_sets
	open = true
	picked = -1
	hold = 0.0
	grace = 0.45
	visible = true
	queue_redraw()


func _keys_text(i: int) -> String:
	var parts: Array = []
	for k in sets[i]:
		parts.append(OS.get_keycode_string(k))
	return "/".join(parts)


func _process(delta: float) -> void:
	if not visible:
		return
	grace = maxf(0.0, grace - delta)
	if not open and hold > 0.0:
		hold -= delta
		if hold <= 0.0:
			visible = false
			chosen.emit(picked)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not open or grace > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for i in mini(sets.size(), options.size()):
			if event.keycode in sets[i]:
				get_viewport().set_input_as_handled()
				picked = i
				open = false
				hold = 0.3
				return


func _draw() -> void:
	var cx := size.x * 0.5
	var panel_rect := Rect2(cx - 500.0, 160.0, 1000.0, 270.0)
	UiPanel.tilt(self, panel_rect.get_center())
	UiPanel.panel(self, panel_rect, Pal.RED)
	UiPanel.tag(self, Vector2(panel_rect.position.x + 24.0, panel_rect.position.y - 34.0), "BOSS DOWN: CHOOSE AN UPGRADE", 30)

	var n := options.size()
	var total := n * BOX_W + (n - 1) * GAP
	var x0 := cx - total * 0.5
	for i in n:
		var col: Color = COLORS[i]
		var rect := Rect2(x0 + i * (BOX_W + GAP), 205.0, BOX_W, BOX_H)
		var is_pick := i == picked
		if is_pick:
			draw_rect(rect, col, true)
		draw_rect(rect, col, false, 5.0)
		var ink := Pal.INK if is_pick else Pal.PAPER
		var key_text := _keys_text(i)
		var key_fs := 56
		if key_text.length() > 1:
			key_fs = 34
		if key_text.length() > 5:
			key_fs = 24
		_text(Vector2(rect.get_center().x, rect.position.y + 42.0), key_text, key_fs, ink, BOX_W)
		_text(Vector2(rect.get_center().x, rect.position.y + 100.0), options[i]["desc"], 26, ink, BOX_W - 16.0)


func _text(center: Vector2, text: String, fs: int, col: Color, width: float) -> void:
	var font := get_theme_default_font()
	var baseline := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(center.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)
