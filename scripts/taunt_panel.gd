extends Control
## The tutorial boss's line after a death: a dialogue box along the bottom of the
## screen, text typed out one letter at a time. ENTER finishes the line, then
## closes it. Swallows every key while it is open. Emits finished().
## SFX (optional file): talk

const Pal = preload("res://scripts/palette.gd")
const Sfx = preload("res://scripts/sfx.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal finished

const CHARS_PER_SEC := 30.0
const FONT_SIZE := 34

var text := ""
var shown := 0.0
var grace := 0.0
var _last_ticked := 0


func show_line(line: String) -> void:
	text = line
	shown = 0.0
	_last_ticked = 0
	grace = 0.5   # keeps a key mashed during the death from skipping the line
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	grace = maxf(0.0, grace - delta)
	shown = minf(shown + CHARS_PER_SEC * delta, float(text.length()))
	var n := int(shown)
	if n >= _last_ticked + 2:
		_last_ticked = n
		Sfx.play("talk")
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		pressed = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE
	if pressed and grace <= 0.0:
		if shown < text.length():
			shown = float(text.length())   # first press: show the whole line
		else:
			visible = false
			finished.emit()


func _draw() -> void:
	var cx := size.x * 0.5
	var rect := Rect2(cx - 520.0, 500.0, 1040.0, 170.0)
	UiPanel.tilt(self, rect.get_center())
	UiPanel.panel(self, rect, Pal.RED)
	UiPanel.tag(self, Vector2(rect.position.x + 24.0, rect.position.y - 34.0), "???", 32, Pal.RED, Pal.INK)
	var font := get_theme_default_font()
	draw_multiline_string(font, Vector2(rect.position.x + 60.0, rect.position.y + 72.0),
			text.substr(0, int(shown)), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 120.0, FONT_SIZE, -1, Pal.PAPER)
	if shown >= text.length() and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.5:
		draw_string(font, Vector2(rect.end.x - 260.0, rect.end.y - 22.0),
				"ENTER", HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 26, Pal.PAPER)
