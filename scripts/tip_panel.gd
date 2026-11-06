extends Control
## Tutorial hint box. show_tip(title, body) pops it up; ENTER or SPACE closes it
## (ESC skips the whole tutorial). While it is open it swallows every key press,
## so nothing behind it reacts. Emits closed(skipped).

const Pal = preload("res://scripts/palette.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal closed(skipped: bool)

var title := ""
var lines: PackedStringArray = PackedStringArray()
var low := false      # true = sit at the bottom of the screen, false = at the top
var grace := 0.0


func show_tip(t: String, body: String, at_bottom: bool = false) -> void:
	title = t
	lines = body.split("\n")
	low = at_bottom
	grace = 0.3
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	grace = maxf(0.0, grace - delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if grace > 0.0:
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			visible = false
			closed.emit(false)
		elif event.keycode == KEY_ESCAPE:
			visible = false
			closed.emit(true)


func _draw() -> void:
	var cx := size.x * 0.5
	var h := 70.0 + lines.size() * 42.0 + 56.0
	var y := size.y - h - 50.0 if low else 100.0
	var rect := Rect2(cx - 460.0, y, 920.0, h)
	UiPanel.tilt(self, rect.get_center())
	UiPanel.panel(self, rect, Pal.BLUE)
	UiPanel.tag(self, Vector2(rect.position.x + 24.0, rect.position.y - 34.0), title, 32)

	var font := get_theme_default_font()
	for i in lines.size():
		draw_string(font, Vector2(rect.position.x + 60.0, rect.position.y + 78.0 + i * 42.0),
				lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.PAPER)

	draw_string(font, Vector2(rect.position.x + 60.0, rect.end.y - 22.0),
			"ESC  SKIP TUTORIAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.PAPER, 0.45))
	if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.5:
		draw_string(font, Vector2(rect.end.x - 360.0, rect.end.y - 22.0),
				"ENTER", HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 28, Pal.PAPER)
