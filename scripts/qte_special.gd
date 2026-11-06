extends Control
## "Something's off" boss special: a short string of key prompts under a timer.
## Press the keys in order. A wrong key or running out of time fails it.
## Emits finished(success) shortly after the result is shown.

const Pal = preload("res://scripts/palette.gd")
const Sfx = preload("res://scripts/sfx.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal finished(success: bool)

# Keys used for prompts. Kept clear of every player's ring keys (A S D, J K L and
# the arrow keys) so a special never clashes with the rings in co-op.
const KEY_POOL := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_U, KEY_I, KEY_O, KEY_P]
const BOX := 96.0
const GAP := 24.0

var keys: Array = []
var index := 0
var time_left := 0.0
var time_total := 1.0
var running := false
var result_ok := false
var result_hold := 0.0


func start(length: int, time_limit: float) -> void:
	var pool: Array = KEY_POOL.duplicate()
	pool.shuffle()
	keys = pool.slice(0, length)
	index = 0
	time_total = time_limit
	time_left = time_limit
	running = true
	result_hold = 0.0
	visible = true
	queue_redraw()


func _finish(ok: bool) -> void:
	running = false
	result_ok = ok
	result_hold = 0.7  # let the player see CLEAR / FAILED


func _process(delta: float) -> void:
	if not visible:
		return
	if running:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_finish(false)
	elif result_hold > 0.0:
		result_hold -= delta
		if result_hold <= 0.0:
			visible = false
			finished.emit(result_ok)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == keys[index]:
			index += 1
			Sfx.play("key_ok")
			if index >= keys.size():
				_finish(true)
		else:
			Sfx.play("key_fail")
			_finish(false)


func _draw() -> void:
	var cx := size.x * 0.5
	var panel_rect := Rect2(cx - 470.0, 160.0, 940.0, 230.0)
	UiPanel.tilt(self, panel_rect.get_center())
	UiPanel.panel(self, panel_rect, Pal.RED)

	# The tag on the panel's edge shows the state: white while running, green on
	# a clear, red on a fail.
	var title := "SOMETHING'S OFF"
	var tag_fill := Pal.PAPER
	var tag_ink := Pal.INK
	if not running:
		title = "CLEAR!" if result_ok else "FAILED"
		tag_fill = Pal.GREEN if result_ok else Pal.RED
		tag_ink = Pal.INK if result_ok else Pal.PAPER
	UiPanel.tag(self, Vector2(panel_rect.position.x + 24.0, panel_rect.position.y - 34.0), title, 32, tag_fill, tag_ink)

	var n := keys.size()
	var total := n * BOX + (n - 1) * GAP
	var x0 := cx - total * 0.5
	for i in n:
		var rect := Rect2(x0 + i * (BOX + GAP), 220.0, BOX, BOX)
		var done := i < index
		var current := running and i == index
		if done:
			draw_rect(rect, Color(Pal.GREEN, 0.8), true)
		var outline := Pal.PAPER if current else Color(Pal.PAPER, 0.35)
		draw_rect(rect, outline, false, 5.0 if current else 3.0)
		var letter_col := Pal.INK if done else Pal.PAPER
		_text(rect.get_center(), OS.get_keycode_string(keys[i]), 56, letter_col)

	var bar_w := 600.0
	var frac := time_left / maxf(time_total, 0.01)
	draw_rect(Rect2(cx - bar_w * 0.5, 340.0, bar_w, 14.0), Color(Pal.PAPER, 0.2), true)
	draw_rect(Rect2(cx - bar_w * 0.5, 340.0, bar_w * frac, 14.0), Pal.RED, true)


func _text(center: Vector2, text: String, fs: int, col: Color) -> void:
	var font := get_theme_default_font()
	var baseline := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(center.x - 300.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, 600.0, fs, col)
