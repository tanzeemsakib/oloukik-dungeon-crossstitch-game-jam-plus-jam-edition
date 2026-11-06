extends Control
## Pops up the instant the FOCUS bar is full. Press A, S or D to spend it (in
## co-op, any player's matching key works). Input is ignored for a split second
## after opening so the player mashing a ring does not pick by accident.
## Emits chosen("BIG DAMAGE" | "SHIELD" | "HEAL") a moment after the pick.

const Pal = preload("res://scripts/palette.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal chosen(choice: String)

const OPTIONS := [
	{"key": KEY_A, "label": "BIG DAMAGE", "choice": "BIG DAMAGE", "color": Pal.RED},
	{"key": KEY_S, "label": "SHIELD", "choice": "SHIELD", "color": Pal.SKY},
	{"key": KEY_D, "label": "HEAL", "choice": "HEAL", "color": Pal.GREEN},
]
const BOX_W := 150.0
const BOX_H := 110.0
const GAP := 50.0

var sets: Array = [[KEY_A], [KEY_S], [KEY_D]]   # keys that pick option 0, 1, 2
var open := false
var picked := -1
var hold := 0.0
var grace := 0.0   # ignore presses right after opening, so ring mashing can't pick by accident


func start(key_sets: Array = []) -> void:
	if not key_sets.is_empty():
		sets = key_sets
	open = true
	picked = -1
	hold = 0.0
	grace = 0.35
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
			chosen.emit(OPTIONS[picked]["choice"])
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not open or grace > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for i in OPTIONS.size():
			if event.keycode in sets[i]:
				get_viewport().set_input_as_handled()
				picked = i
				open = false
				hold = 0.25  # brief highlight of the pick
				return


func _draw() -> void:
	var cx := size.x * 0.5
	var panel_rect := Rect2(cx - 380.0, 160.0, 760.0, 235.0)
	UiPanel.tilt(self, panel_rect.get_center())
	UiPanel.panel(self, panel_rect, Pal.BLUE)
	UiPanel.tag(self, Vector2(panel_rect.position.x + 24.0, panel_rect.position.y - 34.0), "FOCUS FULL", 32)

	var n := OPTIONS.size()
	var total := n * BOX_W + (n - 1) * GAP
	var x0 := cx - total * 0.5
	for i in n:
		var o: Dictionary = OPTIONS[i]
		var col: Color = o["color"]
		var rect := Rect2(x0 + i * (BOX_W + GAP), 205.0, BOX_W, BOX_H)
		var is_pick := i == picked
		if is_pick:
			draw_rect(rect, col, true)
		draw_rect(rect, col, false, 5.0)
		var letter_col := Pal.INK if is_pick else Pal.PAPER
		var key_text := _keys_text(i)
		var key_fs := 64
		if key_text.length() > 1:
			key_fs = 34
		if key_text.length() > 5:
			key_fs = 24
		_text(rect.get_center(), key_text, key_fs, letter_col, BOX_W)
		_text(Vector2(rect.get_center().x, rect.end.y + 28.0), o["label"], 26, col, BOX_W + GAP)


func _text(center: Vector2, text: String, fs: int, col: Color, width: float) -> void:
	var font := get_theme_default_font()
	var baseline := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(center.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)
